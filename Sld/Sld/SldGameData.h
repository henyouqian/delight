//
//  SldGameData.h
//  Sld
//
//  Created by Wei Li on 14-5-5.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <Foundation/Foundation.h>

extern const UInt32 DEFUALT_SLIDER_NUM;

@interface EventInfo : NSObject
@property (nonatomic) UInt64 id;
@property (nonatomic) UInt64 packId;
@property (nonatomic) NSString *thumb;
@property (nonatomic) NSDate *beginTime;
@property (nonatomic) NSDate *endTime;
@property (nonatomic) BOOL hasResult;
@property (nonatomic) BOOL sliderNum;
@property (nonatomic) NSArray *challengeSecs;
@property (nonatomic) int state; //undefined:0, comming:1, running:2, closed:3
@property (nonatomic) int cupType; //none:0, gold:1, silver:2, bronze:3

+ (instancetype)eventWithDictionary:(NSDictionary*)dict;
@end

//=================
@interface PackInfo : NSObject
@property (nonatomic) UInt64 id;
@property (nonatomic) NSString *title;
@property (nonatomic) NSString *text;
@property (nonatomic) NSString *thumb;
@property (nonatomic) NSString *cover;
@property (nonatomic) NSString *coverBlur;
@property (nonatomic) NSMutableArray *images;

+ (instancetype)packWithDictionary:(NSDictionary*)dict;
@end

//=================
@interface EventPlayRecored : NSObject
@property (nonatomic) int highScore;
@property (nonatomic) int trys;
@property (nonatomic) int rank;
@property (nonatomic) int rankNum;
@property (nonatomic) NSString *teamName;
@property (nonatomic) int gameCoinNum;
@property (nonatomic) int challangeHighScore;


+ (instancetype)recordWithDictionary:(NSDictionary*)dict;
@end

//=================
enum GameMode{
    PRACTICE,
    CHALLANGE,
    MATCH,
};

//=================
@interface SldGameData : NSObject

//event
@property (nonatomic) NSMutableArray *eventInfos;
@property (nonatomic) EventInfo *eventInfo;
@property (nonatomic) PackInfo *packInfo;
@property (nonatomic) EventPlayRecored *eventPlayRecord;
@property (nonatomic) int recentScore;
- (void)resetEvent;

//player
@property (nonatomic) UInt64 userId;
@property (nonatomic) NSString *userName;
@property (nonatomic) BOOL online;

@property (nonatomic) NSString *nickName;
@property (nonatomic) uint gender;
@property (nonatomic) NSString *teamName;
@property (nonatomic) NSString *gravatarKey;
@property (nonatomic) int money;

@property (nonatomic) enum GameMode gameMode;

@property (nonatomic) BOOL needReloadEventList;

+ (instancetype)getInstance;
- (void)reset;

@end
