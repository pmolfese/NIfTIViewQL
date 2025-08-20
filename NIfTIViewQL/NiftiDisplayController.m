#import "NiftiDisplayController.h"

@interface NiftiDisplayController ()
@property (nonatomic, strong) NiftiImage *niftiImage;
@property (nonatomic, strong, readwrite) NiftiSliceView *axialView;
@property (nonatomic, strong, readwrite) NiftiSliceView *coronalView;
@property (nonatomic, strong, readwrite) NiftiSliceView *sagittalView;
@end

@implementation NiftiDisplayController

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super init];
    if (self) {
        // Split the frame for 3 views horizontally
        CGFloat w = frame.size.width / 3.0;
        NSRect axialRect = NSMakeRect(0, 0, w, frame.size.height);
        NSRect coronalRect = NSMakeRect(w, 0, w, frame.size.height);
        NSRect sagittalRect = NSMakeRect(2*w, 0, w, frame.size.height);

        _axialView = [[NiftiSliceView alloc] initWithFrame:axialRect];
        _coronalView = [[NiftiSliceView alloc] initWithFrame:coronalRect];
        _sagittalView = [[NiftiSliceView alloc] initWithFrame:sagittalRect];
    }
    return self;
}

- (void)setNiftiImage:(NiftiImage *)image {
    _niftiImage = image;
    if (!image) {
        self.axialView.sliceData = nil;
        self.coronalView.sliceData = nil;
        self.sagittalView.sliceData = nil;
        [self.axialView reloadData];
        [self.coronalView reloadData];
        [self.sagittalView reloadData];
        return;
    }

    int nx = image.nx.intValue, ny = image.ny.intValue, nz = image.nz.intValue;

    // Use the middle slice for each orientation
    NSArray *axialSlice = [image sliceAtIndex:nz/2 orientation:NiftiSliceOrientationAxial];
    NSArray *coronalSlice = [image sliceAtIndex:ny/2 orientation:NiftiSliceOrientationCoronal];
    NSArray *sagittalSlice = [image sliceAtIndex:nx/2 orientation:NiftiSliceOrientationSagittal];

    float minVal = FLT_MAX, maxVal = -FLT_MAX;
    for (NSArray *slice in @[axialSlice, coronalSlice, sagittalSlice]) {
        for (NSArray *row in slice) {
            for (NSNumber *n in row) {
                float v = n.floatValue;
                if (v < minVal) minVal = v;
                if (v > maxVal) maxVal = v;
            }
        }
    }

    self.axialView.sliceData = axialSlice;
    self.coronalView.sliceData = coronalSlice;
    self.sagittalView.sliceData = sagittalSlice;

    self.axialView.minValue = minVal;
    self.coronalView.minValue = minVal;
    self.sagittalView.minValue = minVal;
    self.axialView.maxValue = maxVal;
    self.coronalView.maxValue = maxVal;
    self.sagittalView.maxValue = maxVal;

    [self.axialView reloadData];
    [self.coronalView reloadData];
    [self.sagittalView reloadData];
}

@end
