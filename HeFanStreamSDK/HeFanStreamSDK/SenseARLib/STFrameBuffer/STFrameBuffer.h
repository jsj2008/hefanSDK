//
//  STFrameBuffer.h
//
//  Created by sluin on 16/8/31.
//  Copyright © 2016年 SenseTime. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface STFrame : NSObject

@property (nonatomic , assign) int width;
@property (nonatomic , assign) int height;
@property (nonatomic , assign) int stride;

@property (nonatomic , assign) int64_t pts;
@property (nonatomic , assign) int64_t microSec;

@property (nonatomic , strong) NSData *imageData;
@property (nonatomic , strong) NSData *extraData;


@end


@interface STFrameBuffer : NSObject

- (instancetype)initWithCapacity:(int)iCapacity;

- (void)enqueueFrameToBuffer:(STFrame *)frame;

- (STFrame *)readFrameFromBuffer;

- (int)getSize;

- (void)removeAllFrames;


@end
