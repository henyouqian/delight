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
@property (nonatomic) NSString *thumb;
@property (nonatomic) NSDate *beginTime;
@property (nonatomic) NSDate *endTime;
@property (nonatomic) NSDate *betEndTime;
@property (nonatomic) BOOL hasResult;
@property (nonatomic) int sliderNum;
@property (nonatomic) enum EventState state; //undefined:0, comming:1, running:2, closed:3

+ (instancetype)eventWithDictionary:(NSDictionary*)dict;
- (enum EventState)updateState;
@end

//=================
@interface ChallengeInfo : NSObject
@property (nonatomic) SInt64 id;
@property (nonatomic) SInt64 packId;
@property (nonatomic) NSString *thumb;
@property (nonatomic) int sliderNum;
@property (nonatomic) NSArray *challengeSecs;
@property (nonatomic) NSArray *challengeRewards;
@property (nonatomic) int cupType; //none:0, gold:1, silver:2, bronze:3
@property (nonatomic) BOOL missing;
@property (nonatomic) BOOL isLoading;

+ (instancetype)challengeWithDictionary:(NSDictionary*)dict;
@end

//=================
@interface ChallengePlay : NSObject
@property (nonatomic) SInt64 challengeId;
@property (nonatomic) int highScore;
@property (nonatomic) int cupType;

+ (instancetype)playWithDictionary:(NSDictionary*)dict;

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
@interface AdsConf : NSObject
@property (nonatomic) float showPercent;
@property (nonatomic) float delayPercent;
@property (nonatomic) float delaySec;
@end

//=================
@interface PlayerInfo : NSObject

@property (nonatomic) SInt64 userId;

@property (nonatomic) NSString *nickName;
@property (nonatomic) int gender;
@property (nonatomic) NSString *teamName;
@property (nonatomic) NSString *gravatarKey;
@property (nonatomic) NSString *customAvatarKey;
@property (nonatomic) SInt64 money;
@property (nonatomic) int goldCoin;
@property (nonatomic) int coupon;
@property (nonatomic) SInt64 totalReward;
@property (nonatomic, readonly) int level;
@property (nonatomic) SInt64 rewardCache;
@property (nonatomic) int betCloseBeforeEndSec;
@property (nonatomic) AdsConf *adsConf;
@property (nonatomic) int currChallengeId;
@property (nonatomic) int rateReward;

+ (instancetype)playerWithDictionary:(NSDictionary*)dict;
- (void)setTotalRewardRaw:(SInt64)totalReward;
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

//============================
@interface Match : NSObject
@property (nonatomic) SInt64 id;
@property (nonatomic) SInt64 packId;
@property (nonatomic) int sliderNum;
@property (nonatomic) int couponReward;
@property (nonatomic) NSString *thumb;
@property (nonatomic) int playTimes;
@property (nonatomic) int extraReward;
@property (nonatomic) SInt64 beginTime;
@property (nonatomic) SInt64 endTime;
@property (nonatomic) BOOL hasResult;
@property (nonatomic) NSArray *rankRewardProportions;
@property (nonatomic) float luckyRewardProportion;
@property (nonatomic) float oneCoinRewardProportion;
@property (nonatomic) float ownerRewardProportion;
@property (nonatomic) int challengeSeconds;
@property (nonatomic) NSString *promoUrl;
@property (nonatomic) NSString *promoImage;

- (instancetype)initWithDict:(NSDictionary*)dict;
@end

//=================
enum GameMode{
    PRACTICE,
    CHALLENGE,
    MATCH,
    OFFLINE,
    USERPACK,
    M_TEST,
    M_PRACTICE,
    M_MATCH,
};

//=================
@interface SldGameData : NSObject

//
@property (nonatomic) NSMutableArray *eventInfos;
@property (nonatomic) EventInfo *eventInfo;
@property (nonatomic) NSMutableArray *challengeInfos;
@property (nonatomic) ChallengeInfo *challengeInfo;
@property (nonatomic) ChallengePlay *challengePlay;
@property (nonatomic) PackInfo *packInfo;
@property (nonatomic) EventPlayRecored *eventPlayRecord;
@property (nonatomic) int recentScore;
@property (nonatomic) PlayerInfo *playerInfo;
@property (nonatomic) Match *match;
- (void)resetEvent;

//player
@property (nonatomic) SInt64 userId;
@property (nonatomic) NSString *userName;
@property (nonatomic) BOOL online;


@property (nonatomic) enum GameMode gameMode;

@property (nonatomic) BOOL needReloadEventList;
@property (nonatomic) BOOL needReloadChallengeTime;

//iap
@property (nonatomic) NSArray *iapProducts;

//const
@property (nonatomic) NSArray *TEAM_NAMES;

//
@property (nonatomic) NSMutableArray *levelArray;


//
+ (instancetype)getInstance;
- (void)reset;

//load pack
- (void)loadPack:(SInt64)packId completion:(void (^)(PackInfo*))completion;
@property (nonatomic) NSMutableDictionary* packDict;

//user pack test
@property (nonatomic) NSMutableArray *userPackTestHistory; //NSString[]

@end


