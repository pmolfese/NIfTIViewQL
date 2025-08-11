#import <Foundation/Foundation.h>
#import <Cocoa/Cocoa.h>
#import "NiftiImage.h"
#import "ViewController.h"

@interface ViewController ()
// Example: IBOutlet for a label to display info (connect in Interface Builder)
@property (weak) IBOutlet NSTextField *infoLabel;
@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
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
                
            }
            else {
                self.infoLabel.stringValue = @"Failed to load NIfTI image.";
            }
        }
    }
}


@end
