#import "NiftiImage.h"
#import "nifti1_io.h"
#import <Cocoa/Cocoa.h>

@interface NiftiImage ()
@property (nonatomic) nifti_image *nim;
@property (nonatomic, readwrite) NSArray<NSNumber *> *dimensions;
@property (nonatomic, readwrite) NSArray<NSNumber *> *pixelDimensions;
@property (nonatomic, readwrite) NSNumber *datatype;
@property (nonatomic, readwrite) NSNumber *nx;
@property (nonatomic, readwrite) NSNumber *ny;
@property (nonatomic, readwrite) NSNumber *nz;
@property (nonatomic, readwrite) NSNumber *nt;
@end

@implementation NiftiImage

- (instancetype)initWithFileAtPath:(NSString *)path {
    self = [super init];
    if (self) {
        _nim = nifti_image_read([path fileSystemRepresentation], 1);
        if (!_nim) {
            NSLog(@"Failed to read NIfTI file at path: %@", path);
            return nil;
        }
        // Populate arrays for dimensions and pixel dimensions
        NSMutableArray *dims = [NSMutableArray arrayWithCapacity:8];
        NSMutableArray *pixdims = [NSMutableArray arrayWithCapacity:8];
        for (int i = 0; i < 8; ++i) {
            [dims addObject:@(_nim->dim[i])];
            [pixdims addObject:@(_nim->pixdim[i])];
        }
        self.dimensions = [dims copy];
        self.pixelDimensions = [pixdims copy];
        self.datatype = @(_nim->datatype);
        self.nx = @(_nim->nx);
        self.ny = @(_nim->ny);
        self.nz = @(_nim->nz);
        self.nt = @(_nim->nt);
    }
    return self;
}

- (void)dealloc {
    if (_nim) {
        nifti_image_free(_nim);
        _nim = NULL;
    }
}

- (NSString *)dataTypeDescription {
    int dt = self.datatype.intValue;
    switch (dt) {
        case DT_UINT8:    return @"UINT8";
        case DT_INT16:    return @"INT16";
        case DT_INT32:    return @"INT32";
        case DT_FLOAT32:  return @"FLOAT32";
        case DT_COMPLEX64:return @"COMPLEX64";
        case DT_FLOAT64:  return @"FLOAT64";
        case DT_RGB24:    return @"RGB24";
        case DT_INT8:     return @"INT8";
        case DT_UINT16:   return @"UINT16";
        case DT_UINT32:   return @"UINT32";
        case DT_INT64:    return @"INT64";
        case DT_UINT64:   return @"UINT64";
        default:
            return [NSString stringWithFormat:@"Unknown (%d)", dt];
    }
}

- (NSArray<NSArray<NSNumber *> *> *)sliceAtIndex:(NSInteger)index
                                     orientation:(NiftiSliceOrientation)orientation
{
    if (!_nim || !_nim->data) return nil;
    
    int nx = _nim->nx;
    int ny = _nim->ny;
    int nz = _nim->nz;
    int datatype = _nim->datatype;
    
    NSMutableArray *slice = [NSMutableArray array];
    
    // Helper macro for getting value as NSNumber for each type
#define GET_VAL(idx, TYPE) @(((TYPE *)_nim->data)[idx])
    
    switch (datatype) {
        case DT_FLOAT32: {
            switch (orientation) {
                case NiftiSliceOrientationAxial: // XY plane at Z = index
                    if (index < 0 || index >= nz) return nil;
                    for (int y = 0; y < ny; ++y) {
                        NSMutableArray *row = [NSMutableArray array];
                        for (int x = 0; x < nx; ++x) {
                            int idx = x + y * nx + index * nx * ny;
                            [row addObject:GET_VAL(idx, float)];
                        }
                        [slice addObject:row];
                    }
                    break;
                case NiftiSliceOrientationCoronal: // XZ plane at Y = index
                    if (index < 0 || index >= ny) return nil;
                    for (int z = 0; z < nz; ++z) {
                        NSMutableArray *row = [NSMutableArray array];
                        for (int x = 0; x < nx; ++x) {
                            int idx = x + index * nx + z * nx * ny;
                            [row addObject:GET_VAL(idx, float)];
                        }
                        [slice addObject:row];
                    }
                    break;
                case NiftiSliceOrientationSagittal: // YZ plane at X = index
                    if (index < 0 || index >= nx) return nil;
                    for (int z = 0; z < nz; ++z) {
                        NSMutableArray *row = [NSMutableArray array];
                        for (int y = 0; y < ny; ++y) {
                            int idx = index + y * nx + z * nx * ny;
                            [row addObject:GET_VAL(idx, float)];
                        }
                        [slice addObject:row];
                    }
                    break;
            }
            break;
        }
        case DT_UINT8: {
            switch (orientation) {
                case NiftiSliceOrientationAxial:
                    if (index < 0 || index >= nz) return nil;
                    for (int y = 0; y < ny; ++y) {
                        NSMutableArray *row = [NSMutableArray array];
                        for (int x = 0; x < nx; ++x) {
                            int idx = x + y * nx + index * nx * ny;
                            [row addObject:GET_VAL(idx, uint8_t)];
                        }
                        [slice addObject:row];
                    }
                    break;
                case NiftiSliceOrientationCoronal:
                    if (index < 0 || index >= ny) return nil;
                    for (int z = 0; z < nz; ++z) {
                        NSMutableArray *row = [NSMutableArray array];
                        for (int x = 0; x < nx; ++x) {
                            int idx = x + index * nx + z * nx * ny;
                            [row addObject:GET_VAL(idx, uint8_t)];
                        }
                        [slice addObject:row];
                    }
                    break;
                case NiftiSliceOrientationSagittal:
                    if (index < 0 || index >= nx) return nil;
                    for (int z = 0; z < nz; ++z) {
                        NSMutableArray *row = [NSMutableArray array];
                        for (int y = 0; y < ny; ++y) {
                            int idx = index + y * nx + z * nx * ny;
                            [row addObject:GET_VAL(idx, uint8_t)];
                        }
                        [slice addObject:row];
                    }
                    break;
            }
            break;
        }
        case DT_INT16: {
            switch (orientation) {
                case NiftiSliceOrientationAxial:
                    if (index < 0 || index >= nz) return nil;
                    for (int y = 0; y < ny; ++y) {
                        NSMutableArray *row = [NSMutableArray array];
                        for (int x = 0; x < nx; ++x) {
                            int idx = x + y * nx + index * nx * ny;
                            [row addObject:GET_VAL(idx, int16_t)];
                        }
                        [slice addObject:row];
                    }
                    break;
                case NiftiSliceOrientationCoronal:
                    if (index < 0 || index >= ny) return nil;
                    for (int z = 0; z < nz; ++z) {
                        NSMutableArray *row = [NSMutableArray array];
                        for (int x = 0; x < nx; ++x) {
                            int idx = x + index * nx + z * nx * ny;
                            [row addObject:GET_VAL(idx, int16_t)];
                        }
                        [slice addObject:row];
                    }
                    break;
                case NiftiSliceOrientationSagittal:
                    if (index < 0 || index >= nx) return nil;
                    for (int z = 0; z < nz; ++z) {
                        NSMutableArray *row = [NSMutableArray array];
                        for (int y = 0; y < ny; ++y) {
                            int idx = index + y * nx + z * nx * ny;
                            [row addObject:GET_VAL(idx, int16_t)];
                        }
                        [slice addObject:row];
                    }
                    break;
            }
            break;
        }
        default:
            NSLog(@"sliceAtIndex:orientation: unsupported datatype %d", datatype);
            return nil;
    }
    return slice;
#undef GET_VAL
}

#pragma mark - Rendering helpers

static void NI_computeMinMaxForSlice(NSArray<NSArray<NSNumber *> *> *slice,
                                     double *outMin, double *outMax) {
    double vmin = INFINITY, vmax = -INFINITY;
    for (NSArray<NSNumber *> *row in slice) {
        for (NSNumber *num in row) {
            double v = num.doubleValue;
            if (!isfinite(v)) continue;
            if (v < vmin) vmin = v;
            if (v > vmax) vmax = v;
        }
    }
    if (!isfinite(vmin) || !isfinite(vmax) || vmin == vmax) {
        vmin = 0.0; vmax = 1.0;
    }
    if (outMin) *outMin = vmin;
    if (outMax) *outMax = vmax;
}

static inline uint8_t NI_clampByte(double t) {
    if (t <= 0.0) return 0;
    if (t >= 1.0) return 255;
    return (uint8_t)lrint(t * 255.0);
}

static NSImage *NI_grayscaleImageFromSlice(NSArray<NSArray<NSNumber *> *> *slice,
                                           BOOL flipVertical) {
    if (slice.count == 0) return nil;
    NSUInteger height = slice.count;
    NSUInteger width = ((NSArray *)slice.firstObject).count;
    if (width == 0) return nil;

    double vmin = 0.0, vmax = 1.0;
    NI_computeMinMaxForSlice(slice, &vmin, &vmax);
    double range = vmax - vmin;
    if (range <= 0.0 || !isfinite(range)) range = 1.0;

    NSBitmapImageRep *rep = [[NSBitmapImageRep alloc]
                             initWithBitmapDataPlanes:NULL
                             pixelsWide:(NSInteger)width
                             pixelsHigh:(NSInteger)height
                             bitsPerSample:8
                             samplesPerPixel:1
                             hasAlpha:NO
                             isPlanar:NO
                             colorSpaceName:NSCalibratedWhiteColorSpace
                             bitmapFormat:0
                             bytesPerRow:(NSInteger)width
                             bitsPerPixel:8];
    if (!rep) return nil;

    unsigned char *dst = [rep bitmapData];
    if (!dst) return nil;

    for (NSUInteger row = 0; row < height; ++row) {
        NSUInteger srcRow = flipVertical ? (height - 1 - row) : row;
        NSArray<NSNumber *> *vals = slice[srcRow];
        unsigned char *out = dst + row * width;
        for (NSUInteger col = 0; col < width; ++col) {
            double v = (col < vals.count) ? vals[col].doubleValue : vmin;
            double t = (v - vmin) / range;
            out[col] = NI_clampByte(t);
        }
    }

    NSImage *img = [[NSImage alloc] initWithSize:NSMakeSize(width, height)];
    [img addRepresentation:rep];
    return img;
}

static void NI_drawImageCentered(NSImage *img, NSRect rect) {
    if (!img) return;
    if (rect.size.width <= 0 || rect.size.height <= 0) return;

    NSSize isz = img.size;
    if (isz.width <= 0 || isz.height <= 0) return;

    CGFloat sx = rect.size.width / isz.width;
    CGFloat sy = rect.size.height / isz.height;
    CGFloat s = MIN(sx, sy);

    NSSize target = NSMakeSize(isz.width * s, isz.height * s);
    NSRect dst = NSMakeRect(NSMidX(rect) - target.width * 0.5,
                            NSMidY(rect) - target.height * 0.5,
                            target.width, target.height);
    [img drawInRect:dst
           fromRect:NSZeroRect
          operation:NSCompositingOperationSourceOver
           fraction:1.0
     respectFlipped:YES
              hints:nil];
}

static void NI_drawLabel(NSString *text, NSPoint p) {
    if (text.length == 0) return;
    NSDictionary *attrs = @{
        NSFontAttributeName: [NSFont systemFontOfSize:11 weight:NSFontWeightSemibold],
        NSForegroundColorAttributeName: NSColor.whiteColor
    };
    NSShadow *shadow = [NSShadow new];
    shadow.shadowOffset = NSMakeSize(0, -1);
    shadow.shadowBlurRadius = 2;
    shadow.shadowColor = [[NSColor blackColor] colorWithAlphaComponent:0.6];

    [NSGraphicsContext saveGraphicsState];
    [shadow set];
    [text drawAtPoint:p withAttributes:attrs];
    [NSGraphicsContext restoreGraphicsState];
}

- (NSImage *)renderTripleSliceImageWithSize:(NSSize)size {
    if (!_nim || !_nim->data) {
        return nil;
    }

    // Determine mid-slices
    NSInteger midX = MAX(0, MIN(_nim->nx - 1, _nim->nx / 2));
    NSInteger midY = MAX(0, MIN(_nim->ny - 1, _nim->ny / 2));
    NSInteger midZ = MAX(0, MIN(_nim->nz - 1, _nim->nz / 2));

    // Fetch slices as array-of-rows
    NSArray<NSArray<NSNumber *> *> *axial    = [self sliceAtIndex:midZ orientation:NiftiSliceOrientationAxial];    // size: ny x nx
    NSArray<NSArray<NSNumber *> *> *coronal  = [self sliceAtIndex:midY orientation:NiftiSliceOrientationCoronal];  // size: nz x nx
    NSArray<NSArray<NSNumber *> *> *sagittal = [self sliceAtIndex:midX orientation:NiftiSliceOrientationSagittal]; // size: nz x ny

    if (!axial || !coronal || !sagittal) {
        return nil;
    }

    // Convert to grayscale images; flip vertically for a more typical orientation
    NSImage *axialImg    = NI_grayscaleImageFromSlice(axial, YES);
    NSImage *coronalImg  = NI_grayscaleImageFromSlice(coronal, YES);
    NSImage *sagittalImg = NI_grayscaleImageFromSlice(sagittal, YES);

    if (!axialImg || !coronalImg || !sagittalImg) {
        return nil;
    }

    // Compose into a single canvas
    const CGFloat W = MAX(size.width, 10);
    const CGFloat H = MAX(size.height, 10);
    const CGFloat pad = 8.0;
    const CGFloat columns = 3.0;
    const CGFloat cellW = (W - pad * (columns + 1)) / columns;
    const CGFloat cellH = H - pad * 2.0;

    NSImage *canvas = [[NSImage alloc] initWithSize:NSMakeSize(W, H)];
    [canvas lockFocus];

    // Background
    [[NSColor blackColor] setFill];
    NSRectFill(NSMakeRect(0, 0, W, H));

    // Cells
    NSRect axR = NSMakeRect(pad + 0 * (cellW + pad), pad, cellW, cellH);
    NSRect coR = NSMakeRect(pad + 1 * (cellW + pad), pad, cellW, cellH);
    NSRect sgR = NSMakeRect(pad + 2 * (cellW + pad), pad, cellW, cellH);

    // Draw images
    NI_drawImageCentered(axialImg, axR);
    NI_drawImageCentered(coronalImg, coR);
    NI_drawImageCentered(sagittalImg, sgR);

    // Labels
    //NI_drawLabel(@"Axial",    NSMakePoint(NSMinX(axR) + 6, NSMaxY(axR) - 18));
    //NI_drawLabel(@"Coronal",  NSMakePoint(NSMinX(coR) + 6, NSMaxY(coR) - 18));
    //NI_drawLabel(@"Sagittal", NSMakePoint(NSMinX(sgR) + 6, NSMaxY(sgR) - 18));

    [canvas unlockFocus];
    return canvas;
}

@end
