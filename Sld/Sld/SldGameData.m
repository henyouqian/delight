//
//  SldGameData.m
//  Sld
//
//  Created by Wei Li on 14-5-5.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldGameData.h"
#import "SldUtil.h"
#import "SldHttpSession.h"

const UInt32 DEFUALT_SLIDER_NUM = 6;

//=========================
@implementation PackInfo
+ (instancetype)packWithDictionary:(NSDictionary*)dict {
    PackInfo *packInfo = [[PackInfo alloc] init];
    
    packInfo.id = [(NSNumber*)dict[@"Id"] longLongValue];
    packInfo.title = dict[@"Title"];
    packInfo.text = dict[@"Text"];
    packInfo.thumb = dict[@"Thumb"];
    packInfo.cover = dict[@"Cover"];
    packInfo.coverBlur = dict[@"CoverBlur"];
    if ([packInfo.coverBlur length] == 0) {
        packInfo.coverBlur = packInfo.cover;
    }
    packInfo.timeUnix = [(NSNumber*)dict[@"TimeUnix"] longLongValue];
    NSArray *imgs = dict[@"Images"];
    NSMutableArray *images = [NSMutableArray arrayWithCapacity:[imgs count]];
    for (NSDictionary *img in imgs) {
        [images addObject:img[@"Key"]];
    }
    packInfo.images = images;
    id thumbs = [dict objectForKey:@"Thumbs"];
    if ([thumbs isKindOfClass:[NSNull null].class]) {
        packInfo.thumbs = nil;
    } else {
        packInfo.thumbs = thumbs;
    }
    
    if (packInfo.text == nil || packInfo.text.length == 0) {
        packInfo.text = packInfo.title;
    }
    
    NSDictionary *authorDict = [dict objectForKey:@"Author"];
    if (authorDict) {
        packInfo.author = [PlayerInfo playerWithDictionary:authorDict];
    }
    
    return packInfo;
}
@end

//=========================
@implementation AdsConf

@end

//=========================
@implementation PlayerInfo

+ (instancetype)playerWithDictionary:(NSDictionary*)dict {
    SldGameData *gd = [SldGameData getInstance];
    PlayerInfo *info = [[PlayerInfo alloc] init];
    
    info.userId = [(NSNumber*)[dict objectForKey:@"UserId"] longLongValue];
    info.nickName = [dict objectForKey:@"NickName"];
    info.gender = [(NSNumber*)[dict objectForKey:@"Gender"] intValue];
    info.teamName = [dict objectForKey:@"TeamName"];
    info.gravatarKey = [dict objectForKey:@"GravatarKey"];
    info.customAvatarKey = [dict objectForKey:@"CustomAvatarKey"];
    info.email = [dict objectForKey:@"Email"];
    info.goldCoin = [(NSNumber*)[dict objectForKey:@"GoldCoin"] intValue];
    info.prize = [(NSNumber*)[dict objectForKey:@"Prize"] floatValue];
    info.totalPrize = [(NSNumber*)[dict objectForKey:@"TotalPrize"] floatValue];
    info.prizeCache = [(NSNumber*)[dict objectForKey:@"PrizeCache"] floatValue];
    info.betCloseBeforeEndSec = [(NSNumber*)[dict objectForKey:@"BetCloseBeforeEndSec"] intValue];
    
    NSDictionary *adsConf = [dict objectForKey:@"AdsConf"];
    info.adsConf = [[AdsConf alloc] init];
    info.adsConf.showPercent = [(NSNumber*)[adsConf objectForKey:@"ShowPercent"] floatValue];
    info.adsConf.delayPercent = [(NSNumber*)[adsConf objectForKey:@"DelayPercent"] floatValue];
    info.adsConf.delaySec = [(NSNumber*)[adsConf objectForKey:@"DelaySec"] floatValue];
    
    gd.ownerPrizeProportion = [(NSNumber*)[dict objectForKey:@"OwnerPrizeProportion"] floatValue];
    
    info.BattlePoint = [(NSNumber*)[dict objectForKey:@"BattlePoint"] intValue];
    info.BattleWinStreak = [(NSNumber*)[dict objectForKey:@"BattleWinStreak"] intValue];
    info.BattleWinStreakMax = [(NSNumber*)[dict objectForKey:@"BattleWinStreakMax"] intValue];
    info.BattleHeartZeroTime = [(NSNumber*)[dict objectForKey:@"BattleHeartZeroTime"] longLongValue];
    info.BattleHeartAddSec = [(NSNumber*)[dict objectForKey:@"BattleHeartAddSec"] intValue];
    
    //update player battle levels
    gd.PLAYER_BATTLE_LEVELS = [NSMutableArray array];
    NSArray *playerBattleLevelArray = dict[@"BattleLevels"];
    for (NSDictionary *levelDict in playerBattleLevelArray) {
        PlayerBattleLevel *level = [[PlayerBattleLevel alloc] initWithDict:levelDict];
        [gd.PLAYER_BATTLE_LEVELS addObject:level];
    }
    
    //
    gd.BATTLE_HELP_TEXT = [dict objectForKey:@"BattleHelpText"];
    
    info.followed = [(NSNumber*)dict[@"Followed"] boolValue];
    info.fanNum = [(NSNumber*)dict[@"FanNum"] intValue];
    info.followNum = [(NSNumber*)dict[@"FollowNum"] intValue];
    
    return info;
}

- (int)getHeartNum {
    int dt = (int)(getServerNowSec() - _BattleHeartZeroTime);
    int heartNum = dt / _BattleHeartAddSec;
    if (heartNum > 10) {
        return 10;
    }
    return heartNum;
}

- (NSString*)getHeartTime {
    int dt = (int)(getServerNowSec() - _BattleHeartZeroTime);
    int t = dt % _BattleHeartAddSec;
    t = _BattleHeartAddSec - t;
    int m = t / 60;
    int s = t % 60;
    return [NSString stringWithFormat:@"%d:%02d", m, s];
}

@end

//=========================
@implementation PlayerInfoLite

- (instancetype)initWithDict:(NSDictionary*)dict {
    if (self = [super init]) {
        _UserId = [(NSNumber*)[dict objectForKey:@"UserId"] longLongValue];
        _NickName = [dict objectForKey:@"NickName"];
        _TeamName = [dict objectForKey:@"TeamName"];
        _GravatarKey = [dict objectForKey:@"GravatarKey"];
        _CustomAvatarKey = [dict objectForKey:@"CustomAvatarKey"];
        _Text = [dict objectForKey:@"Text"];
    }
    return self;
}

@end

//=============================
@implementation Match

- (instancetype)initWithDict:(NSDictionary*)dict {
    if (self = [super init]) {
        _id = [(NSNumber*)[dict objectForKey:@"Id"] longLongValue];
        _packId = [(NSNumber*)[dict objectForKey:@"PackId"] longLongValue];
        _imageNum = [(NSNumber*)[dict objectForKey:@"ImageNum"] intValue];
        _ownerId = [(NSNumber*)[dict objectForKey:@"OwnerId"] longLongValue];
        _ownerName = [dict objectForKey:@"OwnerName"];
        _sliderNum = [(NSNumber*)[dict objectForKey:@"SliderNum"] intValue];
        _prize = [(NSNumber*)[dict objectForKey:@"Prize"] intValue];
        _thumb = [dict objectForKey:@"Thumb"];
        _title = [dict objectForKey:@"Title"];
        _playTimes = [(NSNumber*)[dict objectForKey:@"PlayTimes"] intValue];
        _extraPrize = [(NSNumber*)[dict objectForKey:@"ExtraPrize"] intValue];
        _beginTime = [(NSNumber*)[dict objectForKey:@"BeginTime"] longLongValue];
        _endTime = [(NSNumber*)[dict objectForKey:@"EndTime"] longLongValue];
        _hasResult = [(NSNumber*)[dict objectForKey:@"HasResult"] longLongValue];
        _rankPrizeProportions = [dict objectForKey:@"RankPrizeProportions"];
        if ((NSNull*)_rankPrizeProportions == [NSNull null]) {
            _rankPrizeProportions = nil;
        }
        _luckyPrizeProportion = [(NSNumber*)[dict objectForKey:@"LuckyPrizeProportion"] floatValue];
        _minPrizeProportion = [(NSNumber*)[dict objectForKey:@"MinPrizeProportion"] floatValue];
        _ownerPrizeProportion = [(NSNumber*)[dict objectForKey:@"OwnerPrizeProportion"] floatValue];
        _promoUrl = [dict objectForKey:@"PromoUrl"];
        _promoImage = [dict objectForKey:@"PromoImage"];
        _isPrivate = [(NSNumber*)[dict objectForKey:@"Private"] boolValue];
        _likeNum = [(NSNumber*)[dict objectForKey:@"LikeNum"] intValue];
        return self;
    }
    return nil;
}

@end

//========================
@implementation MatchPlay

- (instancetype)initWithDict:(NSDictionary*)dict {
    if (self = [super init]) {
        _playTimes = [(NSNumber*)dict[@"PlayTimes"] intValue];
        _likeNum = [(NSNumber*)dict[@"LikeNum"] intValue];
        _extraPrize = [(NSNumber*)dict[@"ExtraPrize"] intValue];
        _highScore = [(NSNumber*)dict[@"HighScore"] intValue];
        _finalRank = [(NSNumber*)dict[@"FinalRank"] intValue];
        _freeTries = [(NSNumber*)dict[@"FreeTries"] intValue];
        _tries = [(NSNumber*)dict[@"Tries"] intValue];
        _myRank = [(NSNumber*)dict[@"MyRank"] intValue];
        _rankNum = [(NSNumber*)dict[@"RankNum"] intValue];
        _team = dict[@"Team"];
        _like = [dict[@"Like"] boolValue];
        _played = [dict[@"Played"] boolValue];
    }
    return self;
}

@end

//========================
@implementation PlayerBattleLevel

- (instancetype)initWithDict:(NSDictionary*)dict {
    if (self = [super init]) {
        _Level = [(NSNumber*)dict[@"Level"] intValue];
        _Title = dict[@"Title"];
        _StartPoint = [(NSNumber*)dict[@"StartPoint"] intValue];
    }
    return self;
}

@end


//========================
@implementation SldGameData

static SldGameData *g_inst = nil;

+ (instancetype)getInstance {
    if (g_inst == nil) {
        g_inst = [[SldGameData alloc] init];
    }
    return g_inst;
}

- (void)dealloc {
    
}

- (instancetype)init {
    if ([super init]) {
        _eventInfos = [NSMutableArray array];
        
        [self reset];
        
        _TEAM_NAMES = @[@"安徽",@"澳门",@"北京",@"重庆",@"福建",@"甘肃",@"广东",@"广西",@"贵州",@"海南",@"河北",@"河南",@"黑龙江",@"湖北",@"湖南",@"江苏",@"江西",@"吉林",@"辽宁",@"内蒙古",@"宁夏",@"青海",@"陕西",@"山东",@"上海",@"山西",@"四川",@"台湾",@"天津",@"香港",@"新疆",@"西藏",@"云南",@"浙江"];
        
        _packDict = [NSMutableDictionary dictionary];
    }
    return self;
}

- (void)resetEvent {
    _packInfo = nil;
    _recentScore = 0;
}

- (void)reset {
    _eventInfos = [NSMutableArray array];
    _online = NO;
    _recentScore = 0;
    _packInfo = nil;
    _playerInfo = nil;
    
    _userId = 0;
    _userName = nil;
    
    _needReloadEventList = NO;
    
    _needRefreshPlayedList = YES;
    _needRefreshOwnerList = YES;
}

- (void)loadPack:(SInt64)packId completion:(void (^)(PackInfo*))completion {
    //local
    PackInfo *packInfo = [_packDict objectForKey:@(packId)];
    if (packInfo && completion) {
        _packInfo = packInfo;
        completion(packInfo);
        return;
    }
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"Id":@(packId)};
    [session postToApi:@"pack/get" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        _packInfo = [PackInfo packWithDictionary:dict];
        
        if (completion) {
            completion(_packInfo);
        }
    }];
}

- (NSString*)getPlayerBattleLevelTitle {
    NSString *title = @"⁉️";
    for (PlayerBattleLevel *lvData in _PLAYER_BATTLE_LEVELS) {
        if (_playerInfo.BattlePoint >= lvData.StartPoint) {
            title = lvData.Title;
        } else {
            break;
        }
    }
    return title;
}

- (NSString*)getPlayerBattleLevelTitleWithPoint:(int)point {
    NSString *title = @"⁉️";
    for (PlayerBattleLevel *lvData in _PLAYER_BATTLE_LEVELS) {
        if (point >= lvData.StartPoint) {
            title = lvData.Title;
        } else {
            break;
        }
    }
    return title;
}

@end

