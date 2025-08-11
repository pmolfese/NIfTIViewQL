#import "NiftiImage.h"
#import "nifti1_io.h"

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

@end
