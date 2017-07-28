//
//  STGLView.h//
//  Created by sluin on 16/5/12.
//  Copyright © 2016年 SenseTime. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GLKit/GLKit.h>
#import <CoreImage/CoreImage.h>

@interface STGLView : GLKView

- (void)renderWithCImage:(CIImage *)image;

- (void)renderWithTexture:(unsigned int)name
                     size:(CGSize)size
                  flipped:(BOOL)flipped
      applyingOrientation:(int)orientation;


@end
