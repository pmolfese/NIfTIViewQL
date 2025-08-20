#import <Foundation/Foundation.h>
#import "NiftiImage.h"
#import "NiftiSliceView.h"

@interface NiftiDisplayController : NSObject

@property (nonatomic, strong, readonly) NiftiSliceView *axialView;
@property (nonatomic, strong, readonly) NiftiSliceView *coronalView;
@property (nonatomic, strong, readonly) NiftiSliceView *sagittalView;

- (instancetype)initWithFrame:(NSRect)frame;
- (void)setNiftiImage:(NiftiImage *)image;

@end
