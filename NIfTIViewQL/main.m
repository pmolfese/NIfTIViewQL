//
//  main.m
//  NIfTIViewQL
//
//  Created by Molfese, Peter  [E] on 8/11/25.
//

#import <Cocoa/Cocoa.h>
#import "nifti1.h"
#import "nifti1_io.h"

int main(int argc, const char * argv[]) {
    @autoreleasepool {
        // Setup code that might create autoreleased objects goes here.
        
        int znz = nifti_compiled_with_zlib();
        NSLog(@"nifti_clib compiled with zlib: %d", znz);
        
        
        
        
    }
    return NSApplicationMain(argc, argv);
}
