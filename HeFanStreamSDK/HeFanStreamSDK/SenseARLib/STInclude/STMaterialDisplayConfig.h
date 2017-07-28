//
//  STMaterialDisplayConfig.h
//  SenseArLiveBroadcastingSample
//
//  Created by sluin on 16/12/30.
//  Copyright © 2016年 SenseTime. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface STMaterialDisplayConfig : NSObject

@property (nonatomic , strong) NSArray <NSArray <NSString *> *> *arrMaterialPartsSequence;
@property (nonatomic , assign) int32_t iTriggerType;
@property (nonatomic , assign) int iCurrentPartsIndex;


- (NSArray <NSString *>*)nextParts;

@end
