#import <Cocoa/Cocoa.h>
@class NiftiImage;
@class NiftiSliceView;

@interface NiftiTripleSliceView : NSView

- (void)setNiftiImage:(NiftiImage *)image;

@property (nonatomic, strong, readonly) NiftiSliceView *axialView;
@property (nonatomic, strong, readonly) NiftiSliceView *coronalView;
@property (nonatomic, strong, readonly) NiftiSliceView *sagittalView;

@end
