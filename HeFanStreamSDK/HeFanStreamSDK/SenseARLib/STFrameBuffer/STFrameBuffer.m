//
//  STFrameBuffer.m
//
//  Created by sluin on 16/8/31.
//  Copyright © 2016年 SenseTime. All rights reserved.
//

#import "STFrameBuffer.h"

@implementation STFrame

@end

#define STSemaphoreLock() dispatch_semaphore_wait(self->_lock, DISPATCH_TIME_FOREVER)
#define STSemaphoreUnlock() dispatch_semaphore_signal(self->_lock)

@interface STFrameBuffer ()
{
    dispatch_semaphore_t _lock;
}

@property (nonatomic , strong) NSMutableArray *arrBufferFrames;
@property (nonatomic , assign) int iCapacity;

@end

@implementation STFrameBuffer

- (instancetype)init
{
    NSLog(@"does not recognize selector 'init' , use 'initWithCapacity'.");
    
    [self doesNotRecognizeSelector:@selector(init)];
    
    return nil;
}

- (instancetype)initWithCapacity:(int)iCapacity
{
    self = [super init];
    
    if (self) {
        
        if (iCapacity < 1) {
            
            NSLog(@"capacity must be greater than 0");
            
            return nil;
        }
        
        self.iCapacity = iCapacity;
        _lock = dispatch_semaphore_create(1);
        
        self.arrBufferFrames = [NSMutableArray arrayWithCapacity:self.iCapacity];
        
    }
    
    return self;
}

- (void)enqueueFrameToBuffer:(STFrame *)frame
{
    STSemaphoreLock();
    
    [self.arrBufferFrames addObject:frame];
    
    if ([self.arrBufferFrames count] > self.iCapacity) {
        
        [self.arrBufferFrames removeObjectAtIndex:0];
    }
    STSemaphoreUnlock();
}

- (STFrame *)readFrameFromBuffer
{
    STSemaphoreLock();
    
    STFrame *frame = nil;
    
    if ([self.arrBufferFrames count]) {
        
        frame = [self.arrBufferFrames firstObject];
        
        [self.arrBufferFrames removeObjectAtIndex:0];
    }
    
    STSemaphoreUnlock();
    
    return frame;
}

- (int)getSize
{
    STSemaphoreLock();
    
    int iCount = (int)self.arrBufferFrames.count;
    
    STSemaphoreUnlock();
    
    return iCount;
}

- (void)removeAllFrames
{
    STSemaphoreLock();
    
    [self.arrBufferFrames removeAllObjects];
    
    STSemaphoreUnlock();
}

@end
