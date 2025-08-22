#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, NiftiSliceOrientation) {
    NiftiSliceOrientationAxial,
    NiftiSliceOrientationCoronal,
    NiftiSliceOrientationSagittal
};

@interface NiftiImage : NSObject

@property (nonatomic, readonly) NSArray<NSNumber *> *dimensions;        // nifti->dim (8 elements)
@property (nonatomic, readonly) NSArray<NSNumber *> *pixelDimensions;   // nifti->pixdim (8 elements)
@property (nonatomic, readonly) NSNumber *datatype;
@property (nonatomic, readonly) NSNumber *nx;
@property (nonatomic, readonly) NSNumber *ny;
@property (nonatomic, readonly) NSNumber *nz;
@property (nonatomic, readonly) NSNumber *nt;

// Add form_code properties
@property (nonatomic, readonly) NSNumber *qformCode;
@property (nonatomic, readonly) NSNumber *sformCode;

- (instancetype)initWithFileAtPath:(NSString *)path;
- (NSArray<NSArray<NSNumber *> *> *)sliceAtIndex:(NSInteger)index
                                     orientation:(NiftiSliceOrientation)orientation;
- (NSString *)dataTypeDescription;
- (NSImage * _Nullable)renderTripleSliceImageWithSize:(NSSize)size;

- (NSString *)qformCodeDescription;
- (NSString *)sformCodeDescription;

@end
