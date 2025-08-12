#import "PreviewProvider.h"
#import <Cocoa/Cocoa.h>
#import <QuickLook/QuickLook.h>
#import "NiftiImage.h"

@implementation PreviewProvider

- (void)providePreviewForFileRequest:(QLFilePreviewRequest *)request
                   completionHandler:(void (^)(QLPreviewReply * _Nullable reply, NSError * _Nullable error))handler
{
    // Do heavy work off the main thread to avoid any UI-thread stalls.
    dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        @autoreleasepool {
            // QLFilePreviewRequest does NOT expose any size (no maximumSize/previewSize).
            // Use a fixed target size; Quick Look will scale the returned image as needed.
            NSSize targetSize = NSMakeSize(600, 200);

            // Load and render
            NiftiImage *nifti = [[NiftiImage alloc] initWithFileAtPath:request.fileURL.path];
            if (!nifti) {
                handler(nil, [NSError errorWithDomain:@"NiftiPreview"
                                                 code:1001
                                             userInfo:@{NSLocalizedDescriptionKey: @"Failed to open NIfTI file"}]);
                return;
            }

            NSImage *image = [nifti renderTripleSliceImageWithSize:targetSize];
            if (!image) {
                handler(nil, [NSError errorWithDomain:@"NiftiPreview"
                                                 code:1002
                                             userInfo:@{NSLocalizedDescriptionKey: @"Failed to render NIfTI preview image"}]);
                return;
            }

            // Convert NSImage -> PNG data
            NSData *tiffData = [image TIFFRepresentation];
            if (!tiffData) {
                handler(nil, [NSError errorWithDomain:@"NiftiPreview"
                                                 code:1003
                                             userInfo:@{NSLocalizedDescriptionKey: @"Failed to create TIFF"}]);
                return;
            }
            NSBitmapImageRep *bitmap = [NSBitmapImageRep imageRepWithData:tiffData];
            if (!bitmap) {
                handler(nil, [NSError errorWithDomain:@"NiftiPreview"
                                                 code:1004
                                             userInfo:@{NSLocalizedDescriptionKey: @"Failed to create bitmap"}]);
                return;
            }
            NSData *pngData = [bitmap representationUsingType:NSBitmapImageFileTypePNG properties:@{}];
            if (!pngData) {
                handler(nil, [NSError errorWithDomain:@"NiftiPreview"
                                                 code:1005
                                             userInfo:@{NSLocalizedDescriptionKey: @"Failed to encode PNG"}]);
                return;
            }
            
            // Write the PNG data to a temporary file
            NSURL *tempDirectoryURL = [NSURL fileURLWithPath:NSTemporaryDirectory() isDirectory:YES];
            NSString *uniqueFileName = [NSUUID UUID].UUIDString;
            NSURL *tempFileURL = [tempDirectoryURL URLByAppendingPathComponent:[uniqueFileName stringByAppendingPathExtension:@"png"]];
            NSError *writeError = nil;

            if (![pngData writeToURL:tempFileURL options:NSDataWritingAtomic error:&writeError]) {
                handler(nil, [NSError errorWithDomain:@"NiftiPreview"
                                                 code:1006
                                             userInfo:@{NSLocalizedDescriptionKey: [NSString stringWithFormat:@"Failed to write PNG data: %@", writeError.localizedDescription]}]);
                return;
            }

            // Create the QLPreviewReply from the temporary file URL
            QLPreviewReply *reply = [[QLPreviewReply alloc] initWithFileURL:tempFileURL];
            
            if (reply) {
                handler(reply, nil);
            } else {
                handler(nil, [NSError errorWithDomain:@"NiftiPreview"
                                                 code:1007
                                             userInfo:@{NSLocalizedDescriptionKey: @"Failed to create QLPreviewReply from file URL"}]);
            }
        }
    });
}

@end
