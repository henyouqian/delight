//
//  SldConfig.h
//  Sld
//
//  Created by Wei Li on 14-4-24.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSUInteger const LOCAL_SCORE_COUNT_LIMIT;

@interface SldConfig : NSObject
+ (instancetype)getInstance;

@property (nonatomic) NSString *IMG_CACHE_DIR;
@property (nonatomic) NSString *DATA_HOST;
@property (nonatomic) NSString *KEYCHAIN_SERVICE;
@property (nonatomic) NSString *STORE_ID;
@end
