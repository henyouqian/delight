//
//  SldGameData.h
//  Sld
//
//  Created by Wei Li on 14-5-5.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <Foundation/Foundation.h>

extern const UInt32 DEFUALT_SLIDER_NUM;
@class PlayerInfo;

//=================
@interface PackInfo : NSObject
@property (nonatomic) SInt64 id;
@property (nonatomic) NSString *title;
@property (nonatomic) NSString *text;
@property (nonatomic) NSString *thumb;
@property (nonatomic) NSString *cover;
@property (nonatomic) NSString *coverBlur;
@property (nonatomic) NSMutableArray *images;
@property (nonatomic) NSArray *thumbs;
@property (nonatomic) SInt64 timeUnix;
@property (nonatomic) PlayerInfo *author;

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
@property (nonatomic) NSString *email;
@property (nonatomic) int goldCoin;
@property (nonatomic) int prize;
@property (nonatomic) int totalPrize;
@property (nonatomic) int prizeCache;
@property (nonatomic) int betCloseBeforeEndSec;
@property (nonatomic) AdsConf *adsConf;
@property (nonatomic) BOOL followed;
@property (nonatomic) int followNum;
@property (nonatomic) int fanNum;

@property (nonatomic) int BattlePoint;
@property (nonatomic) int BattleWinStreak;
@property (nonatomic) int BattleWinStreakMax;
@property (nonatomic) SInt64 BattleHeartZeroTime;
@property (nonatomic) int BattleHeartAddSec;

+ (instancetype)playerWithDictionary:(NSDictionary*)dict;
- (int)getHeartNum;
- (NSString*)getHeartTime;
@end

//=================
@interface PlayerInfoLite : NSObject

@property SInt64 UserId;
@property NSString *NickName;
@property NSString *TeamName;
@property NSString *GravatarKey;
@property NSString *CustomAvatarKey;
@property NSString *Text;

- (instancetype)initWithDict:(NSDictionary*)dict;

@end

//============================
@interface Match : NSObject
@property (nonatomic) SInt64 id;
@property (nonatomic) SInt64 packId;
@property (nonatomic) int imageNum;
@property (nonatomic) SInt64 ownerId;
@property (nonatomic) NSString *ownerName;
@property (nonatomic) int sliderNum;
@property (nonatomic) int prize;
@property (nonatomic) NSString *thumb;
@property (nonatomic) NSString *title;
@property (nonatomic) int playTimes;
@property (nonatomic) int extraPrize;
@property (nonatomic) SInt64 beginTime;
@property (nonatomic) SInt64 endTime;
@property (nonatomic) BOOL hasResult;
@property (nonatomic) NSArray *rankPrizeProportions;
@property (nonatomic) float luckyPrizeProportion;
@property (nonatomic) float minPrizeProportion;
@property (nonatomic) float ownerPrizeProportion;
@property (nonatomic) NSString *promoUrl;
@property (nonatomic) NSString *promoImage;
@property (nonatomic) BOOL isPrivate;
@property (nonatomic) int likeNum;

- (instancetype)initWithDict:(NSDictionary*)dict;
@end

//==================
@interface MatchPlay : NSObject

@property (nonatomic) int playTimes;
@property (nonatomic) int extraPrize;
@property (nonatomic) int highScore;
@property (nonatomic) int finalRank;
@property (nonatomic) int freeTries;
@property (nonatomic) int tries;
@property (nonatomic) int myRank;
@property (nonatomic) int rankNum;
@property (nonatomic) BOOL like;
@property (nonatomic) NSString *team;

- (instancetype)initWithDict:(NSDictionary*)dict;

@end

//=================
@interface PlayerBattleLevel : NSObject

@property (nonatomic) int Level;
@property (nonatomic) NSString *Title;
@property (nonatomic) int StartPoint;

- (instancetype)initWithDict:(NSDictionary*)dict;

@end

//=================
enum GameMode{
    M_TEST,
    M_PRACTICE,
    M_MATCH,
};

//=================
@interface SldGameData : NSObject

//
@property (nonatomic) NSMutableArray *eventInfos;
@property (nonatomic) PackInfo *packInfo;
@property (nonatomic) int recentScore;
@property (nonatomic) PlayerInfo *playerInfo;
@property (nonatomic) Match *match;
@property (nonatomic) NSString *matchSecret;
@property (nonatomic) NSString *token;

- (void)resetEvent;

//player
@property (nonatomic) SInt64 userId;
@property (nonatomic) NSString *userName;
@property (nonatomic) BOOL online;
@property (nonatomic) NSMutableArray* PLAYER_BATTLE_LEVELS;
@property (nonatomic) NSString *BATTLE_HELP_TEXT;

- (NSString*)getPlayerBattleLevelTitle;
- (NSString*)getPlayerBattleLevelTitleWithPoint:(int)point;

@property (nonatomic) enum GameMode gameMode;
@property (nonatomic) BOOL autoPaging;

@property (nonatomic) BOOL needReloadEventList;
@property (nonatomic) BOOL needReloadChallengeTime;

//iap
@property (nonatomic) NSArray *iapProducts;

//const
@property (nonatomic) NSArray *TEAM_NAMES;


//
+ (instancetype)getInstance;
- (void)reset;

//load pack
- (void)loadPack:(SInt64)packId completion:(void (^)(PackInfo*))completion;
@property (nonatomic) NSMutableDictionary* packDict;

//user pack test
@property (nonatomic) NSMutableArray *userPackTestHistory; //NSString[]

//
@property (nonatomic) MatchPlay *matchPlay;
@property (nonatomic) BOOL needRefreshPlayedList;
@property (nonatomic) BOOL needRefreshOwnerList;
@property (nonatomic) BOOL needRefreshLikeList;

//etc
@property (nonatomic) float ownerPrizeProportion;
@property (nonatomic) int sliderNum;

@property (nonatomic) SRWebSocket *webSocket;
@end


