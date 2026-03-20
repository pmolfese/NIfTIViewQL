//
//  NIfTIViewQLTests.m
//  NIfTIViewQLTests
//
//  Created by Molfese, Peter  [E] on 8/11/25.
//

#import <XCTest/XCTest.h>
#import <CoreFoundation/CoreFoundation.h>
#import "NiftiImage.h"
#import "nifti1.h"

static void NIAppendBigEndianInt32(NSMutableData *data, int32_t value) {
    uint32_t swapped = CFSwapInt32HostToBig((uint32_t)value);
    [data appendBytes:&swapped length:sizeof(swapped)];
}

static void NIAppendBigEndianInt16(NSMutableData *data, int16_t value) {
    uint16_t swapped = CFSwapInt16HostToBig((uint16_t)value);
    [data appendBytes:&swapped length:sizeof(swapped)];
}

static void NIAppendBigEndianFloat32(NSMutableData *data, float value) {
    CFSwappedFloat32 swapped = CFConvertFloat32HostToSwapped(value);
    [data appendBytes:&swapped length:sizeof(swapped)];
}

@interface NIfTIViewQLTests : XCTestCase

@end

@implementation NIfTIViewQLTests

- (void)setUp {
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
}

- (void)testExample {
    NSMutableData *mghData = [NSMutableData data];

    NIAppendBigEndianInt32(mghData, 1);
    NIAppendBigEndianInt32(mghData, 2);
    NIAppendBigEndianInt32(mghData, 2);
    NIAppendBigEndianInt32(mghData, 2);
    NIAppendBigEndianInt32(mghData, 1);
    NIAppendBigEndianInt32(mghData, 3);
    NIAppendBigEndianInt32(mghData, 0);
    NIAppendBigEndianInt16(mghData, 1);
    NIAppendBigEndianInt16(mghData, 0);

    NIAppendBigEndianFloat32(mghData, 1.0f);
    NIAppendBigEndianFloat32(mghData, 2.0f);
    NIAppendBigEndianFloat32(mghData, 3.0f);
    NIAppendBigEndianFloat32(mghData, 1.0f);
    NIAppendBigEndianFloat32(mghData, 0.0f);
    NIAppendBigEndianFloat32(mghData, 0.0f);
    NIAppendBigEndianFloat32(mghData, 0.0f);
    NIAppendBigEndianFloat32(mghData, 1.0f);
    NIAppendBigEndianFloat32(mghData, 0.0f);
    NIAppendBigEndianFloat32(mghData, 0.0f);
    NIAppendBigEndianFloat32(mghData, 0.0f);
    NIAppendBigEndianFloat32(mghData, 1.0f);
    NIAppendBigEndianFloat32(mghData, 10.0f);
    NIAppendBigEndianFloat32(mghData, 20.0f);
    NIAppendBigEndianFloat32(mghData, 30.0f);

    if (mghData.length < 284) {
        [mghData increaseLengthBy:(284 - mghData.length)];
    }

    for (int value = 0; value < 8; ++value) {
        NIAppendBigEndianFloat32(mghData, (float)value);
    }

    NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:@"unit-test.mgh"];
    XCTAssertTrue([mghData writeToFile:path atomically:YES]);

    NiftiImage *image = [[NiftiImage alloc] initWithFileAtPath:path];
    XCTAssertNotNil(image);
    XCTAssertEqualObjects(image.nx, @2);
    XCTAssertEqualObjects(image.ny, @2);
    XCTAssertEqualObjects(image.nz, @2);
    XCTAssertEqualObjects(image.datatype, @(DT_FLOAT32));
    XCTAssertEqualWithAccuracy(image.pixelDimensions[1].doubleValue, 1.0, 0.0001);
    XCTAssertEqualWithAccuracy(image.pixelDimensions[2].doubleValue, 2.0, 0.0001);
    XCTAssertEqualWithAccuracy(image.pixelDimensions[3].doubleValue, 3.0, 0.0001);
    XCTAssertEqualObjects(image.qformCode, @(NIFTI_XFORM_SCANNER_ANAT));

    NSArray<NSArray<NSNumber *> *> *slice = [image sliceAtIndex:0 orientation:NiftiSliceOrientationAxial];
    XCTAssertEqual(slice.count, 2U);
    XCTAssertEqualWithAccuracy(slice[0][0].doubleValue, 0.0, 0.0001);
    XCTAssertEqualWithAccuracy(slice[1][1].doubleValue, 3.0, 0.0001);
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
