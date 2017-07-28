//
//  STGLView.m
//
//  Created by sluin on 16/5/12.
//  Copyright © 2016年 SenseTime. All rights reserved.
//

#import "STGLView.h"

@interface STGLView ()
{
    CGRect _rectDraw;
}
@property (nonatomic , strong) CIContext *ciContext;
@property (nonatomic , strong) EAGLContext *glContext;

@end

@implementation STGLView

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self) {
        
        self.layer.opaque = YES;
        
        CGAffineTransform scale = CGAffineTransformMakeScale(self.contentScaleFactor, self.contentScaleFactor);
        _rectDraw = CGRectApplyAffineTransform(self.bounds, scale);
        
        self.glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
        self.context = self.glContext;
        self.ciContext = [CIContext contextWithEAGLContext:self.glContext
                                                   options:@{kCIContextWorkingColorSpace : [NSNull null]}];
    }
    
    return self;
}

- (void)renderWithTexture:(unsigned int)name
                     size:(CGSize)size
                  flipped:(BOOL)flipped
      applyingOrientation:(int)orientation
{
    [self bindDrawable];
    
    EAGLContext *preContex = [self getPreContext];
    
    [self setCurrentContext:self.context];
    
    if (!self.window) {
        
        [self setCurrentContext:preContex];
        
        return;
    }
    
    CIImage *image = [CIImage imageWithTexture:name size:size flipped:flipped colorSpace:NULL];
    
    image = [image imageByApplyingOrientation:orientation];
    
    if (image) {
        
        [self renderWithCImage:image];
    }else{
        
        NSLog(@"create image with texture failed.");
    }
    
    [self setCurrentContext:preContex];
}

- (void)renderWithCImage:(CIImage *)image
{
    glClearColor(0.0, 0.0, 0.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT | GL_DEPTH_BUFFER_BIT);
    
    if (image) {
        
        [self.ciContext drawImage:image inRect:_rectDraw fromRect:[image extent]];
    }
    
    [self display];
}

- (EAGLContext *)getPreContext
{
    return [EAGLContext currentContext];
}

- (void)setCurrentContext:(EAGLContext *)context
{
    if ([EAGLContext currentContext] != context) {
        
        [EAGLContext setCurrentContext:context];
    }
}

@end
