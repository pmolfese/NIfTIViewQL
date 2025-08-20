#import <Cocoa/Cocoa.h>

@interface NiftiSliceView : NSView

@property (nonatomic, strong) NSArray<NSArray<NSNumber *> *> *sliceData; // 2D slice
@property (nonatomic, assign) float minValue; // for scaling
@property (nonatomic, assign) float maxValue;

- (void)reloadData; // call this when sliceData changes

@end
