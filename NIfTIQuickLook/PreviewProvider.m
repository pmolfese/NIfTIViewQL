#import "PreviewProvider.h"

@implementation PreviewProvider

+ (void)load {
    NSLog(@"PreviewProvider loaded!");
}

- (void)providePreviewForFileRequest:(QLFilePreviewRequest *)request
                   completionHandler:(void (^)(QLPreviewReply *reply, NSError *error))handler
{
    NSLog(@"providePreviewForFileRequest called for URL: %@", request.fileURL);
    
    NSString *fileName = [[request.fileURL path] lastPathComponent];
    NSString *pathExtension = [[request.fileURL path] pathExtension];
    NSLog(@"File: %@, Extension: %@", fileName, pathExtension);
    
    // Check if this is a NIfTI file
    if (![pathExtension.lowercaseString isEqualToString:@"nii"] &&
        ![[request.fileURL path] hasSuffix:@".nii.gz"]) {
        NSError *error = [NSError errorWithDomain:@"NIfTIPreviewError"
                                             code:1
                                         userInfo:@{NSLocalizedDescriptionKey: @"Not a NIfTI file"}];
        handler(nil, error);
        return;
    }
    
    // Get file size
    NSError *attributesError = nil;
    NSDictionary *fileAttributes = [[NSFileManager defaultManager]
                                   attributesOfItemAtPath:[request.fileURL path]
                                   error:&attributesError];
    NSNumber *fileSize = [fileAttributes objectForKey:NSFileSize];
    
    // Create HTML content
    NSString *htmlContent = [NSString stringWithFormat:@
        "<!DOCTYPE html>"
        "<html>"
        "<head>"
        "    <meta charset='UTF-8'>"
        "    <meta name='viewport' content='width=device-width, initial-scale=1.0'>"
        "    <title>NIfTI Preview</title>"
        "    <style>"
        "        body {"
        "            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;"
        "            padding: 20px;"
        "            margin: 0;"
        "            background-color: #f5f5f5;"
        "        }"
        "        .container {"
        "            background-color: white;"
        "            border-radius: 8px;"
        "            padding: 20px;"
        "            box-shadow: 0 2px 10px rgba(0,0,0,0.1);"
        "        }"
        "        h1 { color: #333; margin-top: 0; }"
        "        .file-info {"
        "            background-color: #f8f9fa;"
        "            padding: 15px;"
        "            border-radius: 5px;"
        "            margin: 15px 0;"
        "        }"
        "        .info-row {"
        "            display: flex;"
        "            justify-content: space-between;"
        "            margin: 5px 0;"
        "        }"
        "        .label { font-weight: bold; }"
        "    </style>"
        "</head>"
        "<body>"
        "    <div class='container'>"
        "        <h1>🧠 NIfTI File Preview</h1>"
        "        <div class='file-info'>"
        "            <div class='info-row'>"
        "                <span class='label'>Filename:</span>"
        "                <span>%@</span>"
        "            </div>"
        "            <div class='info-row'>"
        "                <span class='label'>File Size:</span>"
        "                <span>%@ bytes</span>"
        "            </div>"
        "            <div class='info-row'>"
        "                <span class='label'>Type:</span>"
        "                <span>NIfTI Neuroimaging Data</span>"
        "            </div>"
        "        </div>"
        "        <p><strong>Note:</strong> This is a basic preview. The full NIfTI visualization would require parsing the image data and rendering brain slices.</p>"
        "    </div>"
        "</body>"
        "</html>",
        fileName,
        fileSize ? [fileSize stringValue] : @"Unknown"
    ];
    
    NSData *htmlData = [htmlContent dataUsingEncoding:NSUTF8StringEncoding];
    
    // Create temporary HTML file
    NSString *tempPath = [NSTemporaryDirectory() stringByAppendingPathComponent:[NSString stringWithFormat:@"nifti_preview_%@.html", [[NSUUID UUID] UUIDString]]];
    NSURL *tempURL = [NSURL fileURLWithPath:tempPath];
    
    NSError *writeError = nil;
    BOOL success = [htmlData writeToURL:tempURL options:NSDataWritingAtomic error:&writeError];
    
    if (!success || writeError) {
        NSLog(@"Error writing HTML file: %@", writeError);
        handler(nil, writeError);
        return;
    }
    
    NSLog(@"Created preview file at: %@", tempPath);
    
    QLPreviewReply *reply = [[QLPreviewReply alloc] initWithFileURL:tempURL];
    reply.title = fileName;
    
    handler(reply, nil);
}

@end
