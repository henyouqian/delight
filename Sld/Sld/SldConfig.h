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
- (void)updateWithDict:(NSDictionary*)dict;

@property (nonatomic) NSString *IMG_CACHE_DIR;
@property (nonatomic) NSString *DATA_HOST;
@property (nonatomic) NSString *UPLOAD_HOST;
@property (nonatomic) NSString *KEYCHAIN_SERVICE;
@property (nonatomic) NSString *KEYCHAIN_KV;
@property (nonatomic) NSString *STORE_ID;
@property (nonatomic) NSString *HOST;
@property (nonatomic) NSString *HTML5_URL;
@property (nonatomic) NSString *FLURRY_KEY;
@property (nonatomic) NSString *MOGO_KEY;
@property (nonatomic) NSString *UMENG_SOCIAL_KEY;
@property (nonatomic) NSString *WEIXIN_KEY;

@end

extern const int MATCH_FETCH_LIMIT;