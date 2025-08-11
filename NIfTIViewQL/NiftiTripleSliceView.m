#import "NiftiTripleSliceView.h"
#import "NiftiSliceView.h"
#import "NiftiImage.h"

@interface NiftiTripleSliceView ()
@property (nonatomic, strong, readwrite) NiftiSliceView *axialView;
@property (nonatomic, strong, readwrite) NiftiSliceView *coronalView;
@property (nonatomic, strong, readwrite) NiftiSliceView *sagittalView;
@end

@implementation NiftiTripleSliceView

- (instancetype)initWithFrame:(NSRect)frame {
    self = [super initWithFrame:frame];
    if (self) [self setupSubviews];
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self setupSubviews];
}

- (void)setupSubviews {
    if (_axialView) return; // Avoid duplicate setup
    CGFloat w = self.bounds.size.width / 3.0;
    CGFloat h = self.bounds.size.height;
    _axialView = [[NiftiSliceView alloc] initWithFrame:NSMakeRect(0, 0, w, h)];
    _coronalView = [[NiftiSliceView alloc] initWithFrame:NSMakeRect(w, 0, w, h)];
    _sagittalView = [[NiftiSliceView alloc] initWithFrame:NSMakeRect(2*w, 0, w, h)];

    [self addSubview:_axialView];
    [self addSubview:_coronalView];
    [self addSubview:_sagittalView];
}

- (void)layout {
    [super layout];
    CGFloat w = self.bounds.size.width / 3.0;
    CGFloat h = self.bounds.size.height;
    self.axialView.frame = NSMakeRect(0, 0, w, h);
    self.coronalView.frame = NSMakeRect(w, 0, w, h);
    self.sagittalView.frame = NSMakeRect(2*w, 0, w, h);
}

- (void)setNiftiImage:(NiftiImage *)image {
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
