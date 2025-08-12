//
//  PreviewProvider.h
//  NIfTIQuickLook
//
//  Created by Molfese, Peter  [E] on 8/11/25.
//

#import <Cocoa/Cocoa.h>
#import <Quartz/Quartz.h>
#import <QuickLook/QuickLook.h>
#import <QuickLookUI/QuickLookUI.h>
#import "NiftiImage.h"

@interface PreviewProvider : QLPreviewProvider <QLPreviewingController>

@end
