#import "NiftiImage.h"
#import "nifti1_io.h"
#import <Cocoa/Cocoa.h>
#import <CoreFoundation/CoreFoundation.h>
#include <zlib.h>

static const NSUInteger NI_MGHHeaderSize = 284;

typedef NS_ENUM(int32_t, NIMGHDataType) {
    NIMGHDataTypeUChar = 0,
    NIMGHDataTypeInt32 = 1,
    NIMGHDataTypeFloat32 = 3,
    NIMGHDataTypeInt16 = 4
};

static BOOL NI_pathIsMGH(NSString *path) {
    NSString *lowercasePath = path.lowercaseString;
    if ([lowercasePath hasSuffix:@".mgh"] || [lowercasePath hasSuffix:@".mgz"]) {
        return YES;
    }
    if ([lowercasePath hasSuffix:@".gz"]) {
        NSString *innerPath = [lowercasePath stringByDeletingPathExtension];
        return [innerPath hasSuffix:@".mgh"];
    }
    return NO;
}

static BOOL NI_mghPathIsCompressed(NSString *path) {
    NSString *lowercasePath = path.lowercaseString;
    return [lowercasePath hasSuffix:@".mgz"] || [lowercasePath hasSuffix:@".mgh.gz"];
}

static int32_t NI_readBigEndianInt32(const uint8_t *bytes) {
    uint32_t raw = 0;
    memcpy(&raw, bytes, sizeof(raw));
    return (int32_t)CFSwapInt32BigToHost(raw);
}

static int16_t NI_readBigEndianInt16(const uint8_t *bytes) {
    uint16_t raw = 0;
    memcpy(&raw, bytes, sizeof(raw));
    return (int16_t)CFSwapInt16BigToHost(raw);
}

static float NI_readBigEndianFloat32(const uint8_t *bytes) {
    CFSwappedFloat32 raw = { 0 };
    memcpy(&raw, bytes, sizeof(raw));
    return CFConvertFloat32SwappedToHost(raw);
}

static NSData *NI_readGzipFile(NSString *path) {
    gzFile file = gzopen(path.fileSystemRepresentation, "rb");
    if (!file) {
        return nil;
    }

    NSMutableData *data = [NSMutableData data];
    uint8_t buffer[32768];
    int bytesRead = 0;
    while ((bytesRead = gzread(file, buffer, sizeof(buffer))) > 0) {
        [data appendBytes:buffer length:(NSUInteger)bytesRead];
    }

    int gzError = Z_OK;
    (void)gzerror(file, &gzError);
    gzclose(file);

    if (bytesRead < 0 || gzError != Z_OK) {
        return nil;
    }

    return [data copy];
}

static int NI_niftiDatatypeForMGHType(int32_t mghType) {
    switch (mghType) {
        case NIMGHDataTypeUChar:
            return DT_UINT8;
        case NIMGHDataTypeInt16:
            return DT_INT16;
        case NIMGHDataTypeInt32:
            return DT_INT32;
        case NIMGHDataTypeFloat32:
            return DT_FLOAT32;
        default:
            return DT_UNKNOWN;
    }
}

static size_t NI_expectedVoxelBytes(size_t voxelCount, int datatype) {
    int bytesPerVoxel = 0;
    int swapSize = 0;
    nifti_datatype_sizes(datatype, &bytesPerVoxel, &swapSize);
    if (bytesPerVoxel <= 0) {
        return 0;
    }
    return voxelCount * (size_t)bytesPerVoxel;
}

static void NI_swapMGHVoxelDataToHost(void *data, size_t voxelCount, int datatype) {
    if (!data || voxelCount == 0) {
        return;
    }

    switch (datatype) {
        case DT_UINT8:
            return;
        case DT_INT16: {
            uint16_t *values = data;
            for (size_t idx = 0; idx < voxelCount; ++idx) {
                values[idx] = CFSwapInt16BigToHost(values[idx]);
            }
            break;
        }
        case DT_INT32: {
            uint32_t *values = data;
            for (size_t idx = 0; idx < voxelCount; ++idx) {
                values[idx] = CFSwapInt32BigToHost(values[idx]);
            }
            break;
        }
        case DT_FLOAT32: {
            uint32_t *values = data;
            for (size_t idx = 0; idx < voxelCount; ++idx) {
                CFSwappedFloat32 swapped = { values[idx] };
                float hostValue = CFConvertFloat32SwappedToHost(swapped);
                memcpy(&values[idx], &hostValue, sizeof(hostValue));
            }
            break;
        }
        default:
            break;
    }
}

static mat44 NI_mghScannerTransform(int width,
                                    int height,
                                    int depth,
                                    float dx,
                                    float dy,
                                    float dz,
                                    float x_r,
                                    float x_a,
                                    float x_s,
                                    float y_r,
                                    float y_a,
                                    float y_s,
                                    float z_r,
                                    float z_a,
                                    float z_s,
                                    float c_r,
                                    float c_a,
                                    float c_s) {
    mat44 transform = { 0 };

    transform.m[0][0] = x_r * dx;
    transform.m[0][1] = y_r * dy;
    transform.m[0][2] = z_r * dz;
    transform.m[1][0] = x_a * dx;
    transform.m[1][1] = y_a * dy;
    transform.m[1][2] = z_a * dz;
    transform.m[2][0] = x_s * dx;
    transform.m[2][1] = y_s * dy;
    transform.m[2][2] = z_s * dz;
    transform.m[3][3] = 1.0f;

    float centerI = width / 2.0f;
    float centerJ = height / 2.0f;
    float centerK = depth / 2.0f;

    transform.m[0][3] = c_r - (transform.m[0][0] * centerI + transform.m[0][1] * centerJ + transform.m[0][2] * centerK);
    transform.m[1][3] = c_a - (transform.m[1][0] * centerI + transform.m[1][1] * centerJ + transform.m[1][2] * centerK);
    transform.m[2][3] = c_s - (transform.m[2][0] * centerI + transform.m[2][1] * centerJ + transform.m[2][2] * centerK);

    return transform;
}

static nifti_image *NI_readMGHImage(NSString *path) {
    NSData *fileData = NI_mghPathIsCompressed(path) ? NI_readGzipFile(path) : [NSData dataWithContentsOfFile:path];
    if (fileData.length < NI_MGHHeaderSize) {
        return NULL;
    }

    const uint8_t *bytes = fileData.bytes;
    int32_t version = NI_readBigEndianInt32(bytes + 0);
    int32_t width = NI_readBigEndianInt32(bytes + 4);
    int32_t height = NI_readBigEndianInt32(bytes + 8);
    int32_t depth = NI_readBigEndianInt32(bytes + 12);
    int32_t nframes = NI_readBigEndianInt32(bytes + 16);
    int32_t mghType = NI_readBigEndianInt32(bytes + 20);
    int16_t goodRASFlag = NI_readBigEndianInt16(bytes + 28);

    if (version != 1 || width <= 0 || height <= 0 || depth <= 0 || nframes <= 0) {
        return NULL;
    }

    int datatype = NI_niftiDatatypeForMGHType(mghType);
    if (datatype == DT_UNKNOWN) {
        NSLog(@"Unsupported MGH datatype %d at path %@", mghType, path);
        return NULL;
    }

    size_t voxelCount = (size_t)width * (size_t)height * (size_t)depth * (size_t)nframes;
    size_t expectedBytes = NI_expectedVoxelBytes(voxelCount, datatype);
    if (expectedBytes == 0 || fileData.length < NI_MGHHeaderSize + expectedBytes) {
        return NULL;
    }

    int ndim = 1;
    if (height > 1) ndim = 2;
    if (depth > 1) ndim = 3;
    if (nframes > 1) ndim = 4;

    int dims[8] = { ndim, width, height, depth, nframes, 1, 1, 1 };
    nifti_image *nim = nifti_make_new_nim(dims, datatype, 0);
    if (!nim) {
        return NULL;
    }

    nim->data = malloc(expectedBytes);
    if (!nim->data) {
        nifti_image_free(nim);
        return NULL;
    }

    memcpy(nim->data, bytes + NI_MGHHeaderSize, expectedBytes);
    NI_swapMGHVoxelDataToHost(nim->data, voxelCount, datatype);

    nim->fname = strdup(path.fileSystemRepresentation);
    nim->iname = strdup(path.fileSystemRepresentation);
    nim->byteorder = nifti_short_order();
    nim->pixdim[0] = 1.0f;
    nim->dx = 1.0f;
    nim->dy = 1.0f;
    nim->dz = 1.0f;
    nim->dt = 1.0f;
    nim->pixdim[4] = 1.0f;
    nim->xyz_units = NIFTI_UNITS_MM;
    nim->time_units = NIFTI_UNITS_UNKNOWN;
    snprintf(nim->descrip, sizeof(nim->descrip), "%s", "Loaded from FreeSurfer MGH");

    if (goodRASFlag) {
        const NSUInteger rasOffset = 30 + 2;
        float dx = NI_readBigEndianFloat32(bytes + rasOffset + 0);
        float dy = NI_readBigEndianFloat32(bytes + rasOffset + 4);
        float dz = NI_readBigEndianFloat32(bytes + rasOffset + 8);
        float x_r = NI_readBigEndianFloat32(bytes + rasOffset + 12);
        float x_a = NI_readBigEndianFloat32(bytes + rasOffset + 16);
        float x_s = NI_readBigEndianFloat32(bytes + rasOffset + 20);
        float y_r = NI_readBigEndianFloat32(bytes + rasOffset + 24);
        float y_a = NI_readBigEndianFloat32(bytes + rasOffset + 28);
        float y_s = NI_readBigEndianFloat32(bytes + rasOffset + 32);
        float z_r = NI_readBigEndianFloat32(bytes + rasOffset + 36);
        float z_a = NI_readBigEndianFloat32(bytes + rasOffset + 40);
        float z_s = NI_readBigEndianFloat32(bytes + rasOffset + 44);
        float c_r = NI_readBigEndianFloat32(bytes + rasOffset + 48);
        float c_a = NI_readBigEndianFloat32(bytes + rasOffset + 52);
        float c_s = NI_readBigEndianFloat32(bytes + rasOffset + 56);

        nim->dx = dx;
        nim->dy = dy;
        nim->dz = dz;
        nim->pixdim[1] = dx;
        nim->pixdim[2] = dy;
        nim->pixdim[3] = dz;

        nim->sto_xyz = NI_mghScannerTransform(width, height, depth,
                                              dx, dy, dz,
                                              x_r, x_a, x_s,
                                              y_r, y_a, y_s,
                                              z_r, z_a, z_s,
                                              c_r, c_a, c_s);
        nim->sto_ijk = nifti_mat44_inverse(nim->sto_xyz);
        nim->sform_code = NIFTI_XFORM_SCANNER_ANAT;

        nim->qto_xyz = nim->sto_xyz;
        nim->qto_ijk = nim->sto_ijk;
        nim->qform_code = NIFTI_XFORM_SCANNER_ANAT;
        nifti_mat44_to_quatern(nim->qto_xyz,
                               &nim->quatern_b, &nim->quatern_c, &nim->quatern_d,
                               &nim->qoffset_x, &nim->qoffset_y, &nim->qoffset_z,
                               &nim->dx, &nim->dy, &nim->dz, &nim->qfac);
        nim->pixdim[0] = nim->qfac;
        nim->pixdim[1] = nim->dx;
        nim->pixdim[2] = nim->dy;
        nim->pixdim[3] = nim->dz;
    }

    return nim;
}

@interface NiftiImage ()
@property (nonatomic) nifti_image *nim;
@property (nonatomic, readwrite) NSArray<NSNumber *> *dimensions;
@property (nonatomic, readwrite) NSArray<NSNumber *> *pixelDimensions;
@property (nonatomic, readwrite) NSNumber *datatype;
@property (nonatomic, readwrite) NSNumber *nx;
@property (nonatomic, readwrite) NSNumber *ny;
@property (nonatomic, readwrite) NSNumber *nz;
@property (nonatomic, readwrite) NSNumber *nt;
@property (nonatomic, readwrite) NSNumber *qformCode;
@property (nonatomic, readwrite) NSNumber *sformCode;
@end

@implementation NiftiImage

- (instancetype)initWithFileAtPath:(NSString *)path {
    self = [super init];
    if (self) {
        if (NI_pathIsMGH(path)) {
            _nim = NI_readMGHImage(path);
        } else {
            _nim = nifti_image_read([path fileSystemRepresentation], 1);
        }
        if (!_nim) {
            NSLog(@"Failed to read volume file at path: %@", path);
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
        
        self.qformCode = @(_nim->qform_code);
        self.sformCode = @(_nim->sform_code);
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
        case DT_FLOAT64: {
            switch (orientation) {
                case NiftiSliceOrientationAxial: // XY plane at Z = index
                    if (index < 0 || index >= nz) return nil;
                    for (int y = 0; y < ny; ++y) {
                        NSMutableArray *row = [NSMutableArray array];
                        for (int x = 0; x < nx; ++x) {
                            int idx = x + y * nx + index * nx * ny;
                            [row addObject:GET_VAL(idx, double)];
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
                            [row addObject:GET_VAL(idx, double)];
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
                            [row addObject:GET_VAL(idx, double)];
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
        case DT_UINT16: {
            switch (orientation) {
                case NiftiSliceOrientationAxial:
                    if (index < 0 || index >= nz) return nil;
                    for (int y = 0; y < ny; ++y) {
                        NSMutableArray *row = [NSMutableArray array];
                        for (int x = 0; x < nx; ++x) {
                            int idx = x + y * nx + index * nx * ny;
                            [row addObject:GET_VAL(idx, uint16_t)];
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
                            [row addObject:GET_VAL(idx, uint16_t)];
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
                            [row addObject:GET_VAL(idx, uint16_t)];
                        }
                        [slice addObject:row];
                    }
                    break;
            }
            break;
        }
        case DT_INT32: {
            switch (orientation) {
                case NiftiSliceOrientationAxial:
                    if (index < 0 || index >= nz) return nil;
                    for (int y = 0; y < ny; ++y) {
                        NSMutableArray *row = [NSMutableArray array];
                        for (int x = 0; x < nx; ++x) {
                            int idx = x + y * nx + index * nx * ny;
                            [row addObject:GET_VAL(idx, int32_t)];
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
                            [row addObject:GET_VAL(idx, int32_t)];
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
                            [row addObject:GET_VAL(idx, int32_t)];
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

static void NI_drawImageTopAligned(NSImage *img, NSRect rect) {
    if (!img) return;
    NSSize isz = img.size;
    if (isz.width <= 0 || isz.height <= 0) return;

    CGFloat sx = rect.size.width / isz.width;
    CGFloat sy = rect.size.height / isz.height;
    CGFloat s = MIN(sx, sy);

    NSSize target = NSMakeSize(isz.width * s, isz.height * s);
    NSRect dst = NSMakeRect(NSMidX(rect) - target.width * 0.5,
                            NSMaxY(rect) - target.height,
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

    // Compose into a four-quadrant canvas
    const CGFloat W = MAX(size.width, 10);
    const CGFloat H = MAX(size.height, 10);
    const CGFloat pad = 1.0;
    
    // Calculate quadrant dimensions
    const CGFloat quadrantW = (W - pad * 3) / 2; // 2 columns, 3 gaps (left, middle, right)
    const CGFloat quadrantH = (H - pad * 3) / 2; // 2 rows, 3 gaps (top, middle, bottom)

    NSImage *canvas = [[NSImage alloc] initWithSize:NSMakeSize(W, H)];
    [canvas lockFocus];

    // Background
    [[NSColor blackColor] setFill];
    NSRectFill(NSMakeRect(0, 0, W, H));

    // Define quadrant rectangles (top-left, top-right, bottom-left, bottom-right)
    NSRect topLeftRect     = NSMakeRect(pad, H - pad - quadrantH, quadrantW, quadrantH);           // Axial
    NSRect topRightRect    = NSMakeRect(pad + quadrantW + pad, H - pad - quadrantH, quadrantW, quadrantH); // Coronal
    NSRect bottomLeftRect  = NSMakeRect(pad, pad, quadrantW, quadrantH);                             // Sagittal
    NSRect bottomRightRect = NSMakeRect(pad + quadrantW + pad, pad, quadrantW, quadrantH);           // Fourth quadrant (empty for now) quadrant (empty for now)

    // Draw images in the first three quadrants
    NI_drawImageTopAligned(axialImg, topLeftRect);
    NI_drawImageTopAligned(coronalImg, topRightRect);
    NI_drawImageTopAligned(sagittalImg, bottomLeftRect);

    // Optional: Add a subtle border or background to the empty fourth quadrant
    [[NSColor colorWithWhite:0.1 alpha:1.0] setFill];
    NSRectFill(bottomRightRect);

    // Add labels to each quadrant
    //NI_drawLabel(@"Axial",    NSMakePoint(NSMinX(topLeftRect) + 6, NSMaxY(topLeftRect) - 18));
    //NI_drawLabel(@"Coronal",  NSMakePoint(NSMinX(topRightRect) + 6, NSMaxY(topRightRect) - 18));
    //NI_drawLabel(@"Sagittal", NSMakePoint(NSMinX(bottomLeftRect) + 6, NSMaxY(bottomLeftRect) - 18));

    [canvas unlockFocus];
    return canvas;
}

- (NSString *)_formCodeDescription:(NSInteger)code {
    switch (code) {
        case 0: return @"Arbitrary";
        case 1: return @"Scanner-based";
        case 2: return @"Aligned";
        case 3: return @"Talairach";
        case 4: return @"MNI 152";
        case 5: return @"Template/Other";
        default: return @"Unknown";
    }
}

- (NSString *)qformCodeDescription {
    if (!self.qformCode) return @"(not set)";
    return [self _formCodeDescription:self.qformCode.integerValue];
}

- (NSString *)sformCodeDescription {
    if (!self.sformCode) return @"(not set)";
    return [self _formCodeDescription:self.sformCode.integerValue];
}

@end
