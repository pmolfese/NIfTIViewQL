//
//  ViewController.h
//  NIfTIViewQL
//
//  Created by Molfese, Peter  [E] on 8/11/25.
//

#import <Cocoa/Cocoa.h>

@interface ViewController : NSViewController

@property (weak) IBOutlet NSButton *openButton;
@property (weak) IBOutlet NiftiTripleSliceView *tripleSliceView;

@end

