//
//  STMaterialDisplayConfig.m
//  SenseArLiveBroadcastingSample
//
//  Created by sluin on 16/12/30.
//  Copyright © 2016年 SenseTime. All rights reserved.
//

#import "STMaterialDisplayConfig.h"

@implementation STMaterialDisplayConfig

- (instancetype)init
{
    self = [super init];
    if (self) {
        
        self.iCurrentPartsIndex = -1;
    }
    return self;
}

- (NSArray<NSString *> *)nextParts
{
    _iCurrentPartsIndex ++;
    _iCurrentPartsIndex %= _arrMaterialPartsSequence.count;
    
    return
    _arrMaterialPartsSequence.count > 0 ? _arrMaterialPartsSequence[_iCurrentPartsIndex] : nil;
}

@end
