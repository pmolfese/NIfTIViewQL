#import "PreviewViewController.h"
#import "NiftiImage.h"

@interface PreviewViewController ()
@property (nonatomic, strong) NSImageView *imageView;
@property (nonatomic, strong) NSScrollView *scrollView;
@property (nonatomic, strong) NSTextView *infoTextView;
@property (nonatomic, strong) NSSplitView *splitView;
@property (nonatomic, strong) NSURL *fileURL;
@property (nonatomic, strong) NiftiImage *niftiImage;
@end

@implementation PreviewViewController

- (BOOL)isSupportedVolumeURL:(NSURL *)url {
    NSString *lowercasePath = url.path.lowercaseString;
    if ([lowercasePath hasSuffix:@".nii"] || [lowercasePath hasSuffix:@".mgh"] || [lowercasePath hasSuffix:@".mgz"]) {
        return YES;
    }
    if ([lowercasePath hasSuffix:@".gz"]) {
        NSString *innerPath = [lowercasePath stringByDeletingPathExtension];
        return [innerPath hasSuffix:@".nii"] || [innerPath hasSuffix:@".mgh"];
    }
    return NO;
}

- (void)loadView {
    self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 800, 600)];
    self.view.wantsLayer = YES;
    self.view.layer.backgroundColor = [[NSColor windowBackgroundColor] CGColor];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Create split view (image on left, info on right)
    self.splitView = [[NSSplitView alloc] initWithFrame:self.view.bounds];
    self.splitView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.splitView.vertical = YES;
    self.splitView.dividerStyle = NSSplitViewDividerStyleThin;
    
    // Create image view with scroll view
    [self setupImageView];
    
    // Create info text view
    [self setupInfoView];
    
    // Add to split view
    [self.splitView addSubview:self.scrollView];
    [self.splitView addSubview:self.infoTextView.enclosingScrollView];
    
    // Set initial split proportions (70% image, 30% info)
    [self.splitView adjustSubviews];
    
    [self.view addSubview:self.splitView];
}

- (void)setupImageView {
    // Create scroll view for image
    self.scrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 400, 400)];
    self.scrollView.hasVerticalScroller = YES;
    self.scrollView.hasHorizontalScroller = YES;
    self.scrollView.autohidesScrollers = YES;
    self.scrollView.borderType = NSNoBorder;
    self.scrollView.backgroundColor = [NSColor blackColor];
    
    // Create image view
    self.imageView = [[NSImageView alloc] initWithFrame:NSMakeRect(0, 0, 400, 400)];
    self.imageView.imageScaling = NSImageScaleProportionallyUpOrDown;
    self.imageView.imageAlignment = NSImageAlignCenter;
    
    self.scrollView.documentView = self.imageView;
}

- (void)setupInfoView {
    // Create scroll view for text
    NSScrollView *textScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 300, 400)];
    textScrollView.hasVerticalScroller = YES;
    textScrollView.autohidesScrollers = YES;
    textScrollView.borderType = NSNoBorder;
    
    // Create text view
    NSSize contentSize = [textScrollView contentSize];
    self.infoTextView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, contentSize.width, contentSize.height)];
    self.infoTextView.minSize = NSMakeSize(0, 0);
    self.infoTextView.maxSize = NSMakeSize(FLT_MAX, FLT_MAX);
    self.infoTextView.verticallyResizable = YES;
    self.infoTextView.horizontallyResizable = NO;
    self.infoTextView.autoresizingMask = NSViewWidthSizable;
    self.infoTextView.textContainer.containerSize = NSMakeSize(contentSize.width, FLT_MAX);
    self.infoTextView.textContainer.widthTracksTextView = YES;
    self.infoTextView.editable = NO;
    self.infoTextView.selectable = YES;
    self.infoTextView.font = [NSFont systemFontOfSize:12];
    self.infoTextView.backgroundColor = [NSColor controlBackgroundColor];
    
    textScrollView.documentView = self.infoTextView;
}

- (void)preparePreviewOfFileAtURL:(NSURL *)url completionHandler:(void (^)(NSError * _Nullable))handler {
    NSLog(@"preparePreviewOfFileAtURL: %@", url);

    if (![self isSupportedVolumeURL:url]) {
        NSError *error = [NSError errorWithDomain:@"PreviewError"
                                             code:1
                                         userInfo:@{NSLocalizedDescriptionKey: @"Not a supported volume file"}];
        handler(error);
        return;
    }
    
    self.fileURL = url;
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self loadNiftiImage];
    });
    
    handler(nil);
}

- (void)loadNiftiImage {
    if (!self.fileURL) {
        return;
    }
    
    NSString *filePath = [self.fileURL path];
    
    // Try to load the NIfTI image using your existing class
    self.niftiImage = [[NiftiImage alloc] initWithFileAtPath:filePath];
    
    if (self.niftiImage) {
        // Successfully loaded - generate preview image and info
        [self displayNiftiPreview];
        [self displayNiftiInfo];
    } else {
        // Failed to load - show error info
        [self displayLoadError];
    }
}

- (void)resetScrollPositions {
    // Reset image scroll view to top-left
    if (self.scrollView && self.scrollView.contentView) {
        NSClipView *clipView = self.scrollView.contentView;
        
        // Force scroll view to recalculate content size
        [self.scrollView tile];
        
        // Simply scroll to origin (0,0) which represents top-left in the document view
        [clipView scrollToPoint:NSMakePoint(0, 0)];
        [self.scrollView reflectScrolledClipView:clipView];
        
        // Force immediate display update
        [clipView setNeedsDisplay:YES];
    }
    
    // Reset info text view scroll to top
    if (self.infoTextView && self.infoTextView.enclosingScrollView) {
        NSScrollView *textScrollView = self.infoTextView.enclosingScrollView;
        if (textScrollView.contentView) {
            NSClipView *clipView = textScrollView.contentView;
            [textScrollView tile];
            [clipView scrollToPoint:NSMakePoint(0, 0)];
            [textScrollView reflectScrolledClipView:clipView];
            [clipView setNeedsDisplay:YES];
        }
    }
}

- (void)displayNiftiPreview {
    if (!self.niftiImage) return;
    
    // Use existing renderTripleSliceImageWithSize method
    NSSize imageSize = NSMakeSize(600, 400); // Adjust as needed
    NSImage *previewImage = [self.niftiImage renderTripleSliceImageWithSize:imageSize];
    
    if (previewImage) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.imageView.image = previewImage;
            
            // Resize image view to fit the image
            NSSize imgSize = previewImage.size;
            self.imageView.frame = NSMakeRect(0, 0, imgSize.width, imgSize.height);
            [self resetScrollPositions];
        });
    }
}

- (void)displayNiftiInfo {
    if (!self.niftiImage) return;
    
    NSString *fileName = [self.fileURL lastPathComponent];
    NSString *filePath = [self.fileURL path];
    
    // Get file attributes
    NSError *error;
    NSDictionary *attributes = [[NSFileManager defaultManager] attributesOfItemAtPath:filePath error:&error];
    NSNumber *fileSize = [attributes objectForKey:NSFileSize];
    NSDate *modificationDate = [attributes objectForKey:NSFileModificationDate];
    
    // Format file size
    NSString *formattedSize = [self formatFileSize:fileSize];
    
    // Build detailed info string using your NiftiImage properties
    NSMutableString *content = [[NSMutableString alloc] init];
    
    [content appendString:@"🧠 VOLUME FILE PREVIEW\n"];
    [content appendString:@"====================\n\n"];
    
    [content appendFormat:@"📁 File Information:\n"];
    [content appendFormat:@"   • Name: %@\n", fileName];
    [content appendFormat:@"   • Size: %@\n", formattedSize];
    [content appendFormat:@"   • Compression: %@\n", ([filePath.lowercaseString hasSuffix:@".gz"] || [filePath.lowercaseString hasSuffix:@".mgz"]) ? @"Gzip compressed" : @"Uncompressed"];
    if (modificationDate) {
        NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
        formatter.dateStyle = NSDateFormatterMediumStyle;
        formatter.timeStyle = NSDateFormatterShortStyle;
        [content appendFormat:@"   • Modified: %@\n", [formatter stringFromDate:modificationDate]];
    }
    [content appendString:@"\n"];
    
    [content appendString:@"📊 Image Properties:\n"];
    [content appendFormat:@"   • Dimensions: %@ × %@ × %@", self.niftiImage.nx, self.niftiImage.ny, self.niftiImage.nz];
    if ([self.niftiImage.nt intValue] > 1) {
        [content appendFormat:@" × %@ (4D)", self.niftiImage.nt];
    }
    [content appendString:@"\n"];
    
    [content appendFormat:@"   • Data Type: %@ (code: %@)\n", [self.niftiImage dataTypeDescription], self.niftiImage.datatype];
    
    // Display pixel dimensions if available
    NSArray *pixDims = self.niftiImage.pixelDimensions;
    if (pixDims && pixDims.count >= 4) {
        [content appendFormat:@"   • Voxel Size: %.3f × %.3f × %.3f mm\n",
         [pixDims[1] floatValue], [pixDims[2] floatValue], [pixDims[3] floatValue]];
        
        if ([pixDims[4] floatValue] > 0 && [self.niftiImage.nt intValue] > 1) {
            [content appendFormat:@"   • Time Resolution: %.3f %@\n",
             [pixDims[4] floatValue],
             [pixDims[4] floatValue] < 10 ? @"seconds" : @"ms"];
        }
    }
    
    [content appendFormat:@"   • qform_code: %@ (%@)\n", self.niftiImage.qformCode, self.niftiImage.qformCodeDescription];
    [content appendFormat:@"   • sform_code: %@ (%@)\n", self.niftiImage.sformCode, self.niftiImage.sformCodeDescription];
    
    // Calculate total voxels and estimated memory usage
    long long totalVoxels = (long long)[self.niftiImage.nx longLongValue] *
                           [self.niftiImage.ny longLongValue] *
                           [self.niftiImage.nz longLongValue] *
                           [self.niftiImage.nt longLongValue];
    
    // Estimate memory usage based on data type
    int bytesPerVoxel = 1; // default
    int dataType = [self.niftiImage.datatype intValue];
    switch (dataType) {
        case 2: case 256: bytesPerVoxel = 1; break; // uint8, int8
        case 4: case 512: bytesPerVoxel = 2; break; // int16, uint16
        case 8: case 768: bytesPerVoxel = 4; break; // int32, uint32
        case 16: bytesPerVoxel = 4; break; // float32
        case 64: bytesPerVoxel = 8; break; // float64
        case 1024: case 1280: bytesPerVoxel = 8; break; // int64, uint64
        default: bytesPerVoxel = 4; break;
    }
    long long memoryBytes = totalVoxels * bytesPerVoxel;
    NSString *memorySize = [self formatFileSize:@(memoryBytes)];
    [content appendFormat:@"   • Memory Usage: ~%@\n", memorySize];
    
    [content appendString:@"\n"];
    
    [content appendString:@"📚 Resources:\n"];
    [content appendString:@"   • NIfTI Format: https://nifti.nimh.nih.gov\n"];
    [content appendString:@"   • FreeSurfer MGH: https://surfer.nmr.mgh.harvard.edu/fswiki/FsTutorial/MghFormat\n"];
    
    // Apply styling and set content
    dispatch_async(dispatch_get_main_queue(), ^{
        [self setStyledTextContent:content];
    });
}

- (void)displayLoadError {
    NSString *fileName = [self.fileURL lastPathComponent];
    
    NSMutableString *content = [[NSMutableString alloc] init];
    [content appendString:@"⚠️ UNABLE TO LOAD VOLUME FILE\n"];
    [content appendString:@"=============================\n\n"];
    
    [content appendFormat:@"File: %@\n\n", fileName];
    [content appendString:@"Possible issues:\n"];
    [content appendString:@"   • File may be corrupted or incomplete\n"];
    [content appendString:@"   • Unsupported NIfTI or MGH variant\n"];
    [content appendString:@"   • File permissions or access issues\n"];
    [content appendString:@"   • Not a valid NIfTI or MGH file despite extension\n\n"];
    
    [content appendString:@"Try:\n"];
    [content appendString:@"   • Opening with specialized NIfTI software\n"];
    [content appendString:@"   • Checking file integrity\n"];
    [content appendString:@"   • Verifying file format with 'file' command\n"];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self.imageView.image = nil;
        [self setStyledTextContent:content];
    });
}

- (NSString *)formatFileSize:(NSNumber *)fileSize {
    if (!fileSize) return @"Unknown";
    
    double size = [fileSize doubleValue];
    if (size < 1024) {
        return [NSString stringWithFormat:@"%.0f bytes", size];
    } else if (size < 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f KB", size / 1024];
    } else if (size < 1024 * 1024 * 1024) {
        return [NSString stringWithFormat:@"%.1f MB", size / (1024 * 1024)];
    } else {
        return [NSString stringWithFormat:@"%.1f GB", size / (1024 * 1024 * 1024)];
    }
}

- (BOOL)isDarkMode {
    if (@available(macOS 10.14, *)) {
        NSAppearance *appearance = self.view.effectiveAppearance;
        if (!appearance) {
            appearance = [NSApp effectiveAppearance];
        }
        
        NSAppearanceName name = [appearance bestMatchFromAppearancesWithNames:@[
            NSAppearanceNameAqua,
            NSAppearanceNameDarkAqua
        ]];
        
        return [name isEqualToString:NSAppearanceNameDarkAqua];
    }
    return NO;
}

- (void)setStyledTextContent:(NSString *)content {
    // Apply styling
    NSMutableAttributedString *attributedContent = [[NSMutableAttributedString alloc] initWithString:content];
    NSRange fullRange = NSMakeRange(0, [content length]);
    
    // Determine text colors based on appearance
    BOOL isDark = [self isDarkMode];
    NSColor *defaultTextColor = isDark ? [NSColor whiteColor] : [NSColor blackColor];
    
    // Set default font and text color
    [attributedContent addAttribute:NSFontAttributeName
                              value:[NSFont systemFontOfSize:11]
                              range:fullRange];
    [attributedContent addAttribute:NSForegroundColorAttributeName
                              value:defaultTextColor
                              range:fullRange];
    
    // Style headers and sections
    NSArray *lines = [content componentsSeparatedByString:@"\n"];
    NSUInteger currentLocation = 0;
    
    for (NSString *line in lines) {
        if (currentLocation >= [content length]) break;
        
        NSUInteger lineLength = [line length];
        if (currentLocation + lineLength > [content length]) {
            lineLength = [content length] - currentLocation;
        }
        
        NSRange lineRange = NSMakeRange(currentLocation, lineLength);
        
        if ([line hasPrefix:@"🧠"] || [line hasPrefix:@"⚠️"]) {
            // Main title
            [attributedContent addAttribute:NSFontAttributeName
                                      value:[NSFont boldSystemFontOfSize:14]
                                      range:lineRange];
            [attributedContent addAttribute:NSForegroundColorAttributeName
                                      value:[NSColor controlAccentColor]
                                      range:lineRange];
        } else if ([line hasPrefix:@"📁"] || [line hasPrefix:@"📊"] ||
                   [line hasPrefix:@"🎨"] || [line hasPrefix:@"ℹ️"] ||
                   [line hasPrefix:@"📚"]) {
            // Section headers
            [attributedContent addAttribute:NSFontAttributeName
                                      value:[NSFont boldSystemFontOfSize:12]
                                      range:lineRange];
            [attributedContent addAttribute:NSForegroundColorAttributeName
                                      value:[NSColor secondaryLabelColor]
                                      range:lineRange];
        } else if ([line hasPrefix:@"="]) {
            // Separator lines
            [attributedContent addAttribute:NSForegroundColorAttributeName
                                      value:[NSColor tertiaryLabelColor]
                                      range:lineRange];
        } else if ([line hasPrefix:@"   •"]) {
            // Bullet points - explicitly set to default text color
            [attributedContent addAttribute:NSFontAttributeName
                                      value:[NSFont systemFontOfSize:11]
                                      range:lineRange];
            [attributedContent addAttribute:NSForegroundColorAttributeName
                                      value:defaultTextColor
                                      range:lineRange];
        }
        
        currentLocation += lineLength + 1; // +1 for newline
    }
    
    // Set the styled content
    [self.infoTextView.textStorage setAttributedString:attributedContent];
    
    // Also set the text view's default color as backup
    self.infoTextView.textColor = defaultTextColor;
}

- (void)viewDidLayout {
    [super viewDidLayout];
    // Maintain split view proportions (70% image, 30% info)
    if (self.splitView.subviews.count == 2) {
        CGFloat totalWidth = self.splitView.bounds.size.width;
        CGFloat imageWidth = totalWidth * 0.7;
        [self.splitView setPosition:imageWidth ofDividerAtIndex:0];
    }
    // Resize imageView to fill scrollView - was causing issues
//    if (self.scrollView && self.imageView) {
//        self.imageView.frame = self.scrollView.contentView.bounds;
//    }
}

@end
