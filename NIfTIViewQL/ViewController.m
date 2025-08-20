#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "NiftiImage.h"
#import "NiftiTripleSliceView.h"
#import "NiftiSliceView.h"
#import "ViewController.h"
#import "nifti1_io.h"

@interface ViewController ()
// Example: IBOutlet for a label to display info (connect in Interface Builder)
@property (weak) IBOutlet NSTextField *infoLabel;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    int znz = nifti_compiled_with_zlib();
    NSLog(@"compiled with ZNZ: %d", znz);
    // Additional setup if needed
}
- (IBAction)openNIfTI:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    [panel setCanChooseFiles:YES];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanChooseDirectories:NO];
    //[panel setAllowedFileTypes:@[@"nii", @"nii.gz"]];

    NiftiImage *myImage;
    
    if ([panel runModal] == NSModalResponseOK) {
        NSURL *fileURL = panel.URL;
        if (fileURL) {
            myImage = [[NiftiImage alloc] initWithFileAtPath:fileURL.path];
            if (myImage) {
                NSString *dType = [[myImage datatype] stringValue];
                NSLog(@"DataType %@", dType);
                NSLog(@"Dimensions: %@ %@ %@", [myImage nx], [myImage ny], [myImage nz]);
                
                [self.tripleSliceView setNiftiImage:myImage];
                
            }
            else {
                self.infoLabel.stringValue = @"Failed to load NIfTI image.";
            }
        }
    }
}


@end
