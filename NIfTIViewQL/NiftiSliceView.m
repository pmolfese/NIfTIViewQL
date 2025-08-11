#import "NiftiSliceView.h"

@implementation NiftiSliceView

- (void)drawRect:(NSRect)dirtyRect {
    [super drawRect:dirtyRect];
    if (!self.sliceData) return;

    NSUInteger height = self.sliceData.count;
    NSUInteger width = height ? [self.sliceData[0] count] : 0;
    if (width == 0 || height == 0) return;

    NSRect bounds = self.bounds;
    float scaleX = bounds.size.width / width;
    float scaleY = bounds.size.height / height;

    for (NSUInteger y = 0; y < height; ++y) {
        NSArray<NSNumber *> *row = self.sliceData[y];
        for (NSUInteger x = 0; x < width; ++x) {
            float value = [row[x] floatValue];
            // Normalize to grayscale
            float normalized = (value - self.minValue) / (self.maxValue - self.minValue);
            normalized = fmaxf(0.0, fminf(1.0, normalized));
            NSColor *color = [NSColor colorWithCalibratedWhite:normalized alpha:1.0];
            NSRect pixelRect = NSMakeRect(x * scaleX, bounds.size.height - (y + 1) * scaleY, scaleX, scaleY);
            [color setFill];
            NSRectFill(pixelRect);
        }
    }
}

- (void)reloadData {
    [self setNeedsDisplay:YES];
}

@end
