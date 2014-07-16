//
//  SldGameData.h
//  Sld
//
//  Created by Wei Li on 14-5-5.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <Foundation/Foundation.h>

extern const UInt32 DEFUALT_SLIDER_NUM;

enum EventState{
    UNDEFINED,
    COMMING,
    RUNNING,
    CLOSED,
};

enum CupType{
    CUP_NONE = 0,
    CUP_GOLD = 1,
    CUP_SILVER = 2,
    CUP_BRONZE = 3,
};

@interface EventInfo : NSObject
@property (nonatomic) SInt64 id;
@property (nonatomic) SInt64 packId;
@property (nonatomic) SInt64 packTimeUnix;
@property (nonatomic) NSString *thumb;
@property (nonatomic) NSDate *beginTime;
@property (nonatomic) NSDate *endTime;
@property (nonatomic) NSDate *betEndTime;
@property (nonatomic) BOOL hasResult;
@property (nonatomic) int sliderNum;
@property (nonatomic) NSArray *challengeSecs;
@property (nonatomic) NSArray *challengeRewards;
@property (nonatomic) enum EventState state; //undefined:0, comming:1, running:2, closed:3
@property (nonatomic) int cupType; //none:0, gold:1, silver:2, bronze:3
@property (nonatomic) BOOL isLoading;
@property (nonatomic) BOOL missing;

+ (instancetype)eventWithDictionary:(NSDictionary*)dict;
- (enum EventState)updateState;
@end

//=================
@interface PackInfo : NSObject
@property (nonatomic) SInt64 id;
@property (nonatomic) NSString *title;
@property (nonatomic) NSString *text;
@property (nonatomic) NSString *thumb;
@property (nonatomic) NSString *cover;
@property (nonatomic) NSString *coverBlur;
@property (nonatomic) NSMutableArray *images;
@property (nonatomic) SInt64 timeUnix;

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
@property (nonatomic) int challengeHighScore;
@property (nonatomic) SInt64 matchReward;
@property (nonatomic) SInt64 betReward;
@property (nonatomic) NSMutableDictionary *bet;    //[teamName:string]betMoney:int64
@property (nonatomic) SInt64 BetMoneySum;


+ (instancetype)recordWithDictionary:(NSDictionary*)dict;
@end

//=================
enum GameMode{
    PRACTICE,
    CHALLENGE,
    MATCH,
    OFFLINE,
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
@property (nonatomic) SInt64 userId;
@property (nonatomic) NSString *userName;
@property (nonatomic) BOOL online;

@property (nonatomic) NSString *nickName;
@property (nonatomic) uint gender;
@property (nonatomic) NSString *teamName;
@property (nonatomic) NSString *gravatarKey;
@property (nonatomic) NSString *customAvatarKey;
@property (nonatomic) SInt64 money;
@property (nonatomic) SInt64 totalReward;
@property (nonatomic) SInt64 rewardCache;
@property (nonatomic) float adsPercent;
@property (nonatomic) int challengeEventId;
@property (nonatomic) int rateReward;

@property (nonatomic) int betCloseBeforeEndSec;

@property (nonatomic) enum GameMode gameMode;

@property (nonatomic) BOOL needReloadEventList;
@property (nonatomic) BOOL needReloadChallengeTime;

//iap
@property (nonatomic) NSArray *iapProducts;

//const
@property (nonatomic) NSArray *TEAM_NAMES;

//star mode
@property (nonatomic) NSMutableArray *challengeEventInfos;


//
+ (instancetype)getInstance;
- (void)reset;

@end


