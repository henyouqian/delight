//
//  SldGameData.h
//  Sld
//
//  Created by Wei Li on 14-5-5.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EventInfo : NSObject
@property (nonatomic) UInt64 id;
@property (nonatomic) UInt64 packId;
@property (nonatomic) NSString *thumb;
@property (nonatomic) NSDate *beginTime;
@property (nonatomic) NSDate *endTime;
@property (nonatomic) BOOL hasResult;
@end

@interface PackInfo : NSObject
@property (nonatomic) UInt64 id;
@property (nonatomic) NSString *title;
@property (nonatomic) NSString *thumb;
@property (nonatomic) NSString *cover;
@property (nonatomic) NSString *coverBlur;
@property (nonatomic) NSMutableArray *images;

+ (instancetype)packWithDictionary:(NSDictionary*)dict;
@end

@interface SldGameData : NSObject

@property (nonatomic) NSMutableArray *eventInfos;
@property (nonatomic) EventInfo *eventInfo;
@property (nonatomic) PackInfo *packInfo;

@property (nonatomic) UInt64 userId;
@property (nonatomic) NSString *userName;

+ (instancetype)getInstance;

@end
