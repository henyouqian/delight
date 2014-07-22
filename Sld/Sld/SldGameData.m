//
//  SldGameData.m
//  Sld
//
//  Created by Wei Li on 14-5-5.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldGameData.h"
#import "SldUtil.h"

const UInt32 DEFUALT_SLIDER_NUM = 6;

@implementation EventInfo
+ (instancetype)eventWithDictionary:(NSDictionary*)dict {
    EventInfo *event = [[EventInfo alloc] init];
    event.id = [(NSNumber*)dict[@"Id"] longLongValue];
    event.thumb = dict[@"Thumb"];
    event.packId = [(NSNumber*)dict[@"PackId"] longLongValue];
    event.beginTime = [NSDate dateWithTimeIntervalSince1970:[(NSNumber*)dict[@"BeginTime"] longLongValue]];
    SInt64 endTime = [(NSNumber*)dict[@"EndTime"] longLongValue];
    event.endTime = [NSDate dateWithTimeIntervalSince1970:endTime];
    NSNumber *betEndTime = [dict objectForKey:@"BetEndTime"];
    if (betEndTime) {
        event.betEndTime = [NSDate dateWithTimeIntervalSince1970:[(NSNumber*)betEndTime longLongValue]];
    } else {
        event.betEndTime = [NSDate dateWithTimeIntervalSince1970:endTime - 60*60];
    }
    
    event.hasResult = [(NSNumber*)[dict valueForKey:@"HasResult"] boolValue];
    event.sliderNum = [(NSNumber*)[dict valueForKey:@"SliderNum"] intValue];
    if (event.sliderNum == 0) {
        event.sliderNum = DEFUALT_SLIDER_NUM;
    }
    
    return event;
}

- (enum EventState)updateState {
    NSTimeInterval endIntv = [_endTime timeIntervalSinceNow];
    if (endIntv < 0 || _hasResult) {
        _state = CLOSED;
    } else {
        NSTimeInterval beginIntv = [_beginTime timeIntervalSinceNow];
        if (beginIntv > 0) {
            _state = COMMING;
        } else {
            _state = RUNNING;
        }
    }
    return _state;
}

@end

//=========================
@implementation ChallengeInfo
+ (instancetype)challengeWithDictionary:(NSDictionary*)dict {
    ChallengeInfo *cha = [[ChallengeInfo alloc] init];
    cha.id = [(NSNumber*)dict[@"Id"] longLongValue];
    cha.thumb = dict[@"Thumb"];
    cha.packId = [(NSNumber*)dict[@"PackId"] longLongValue];
    cha.challengeSecs = [dict valueForKey:@"ChallengeSecs"];
    if ([cha.challengeSecs isKindOfClass:[NSNull class]]) {
        cha.challengeSecs = [NSArray array];
    }
    cha.challengeRewards = [dict valueForKey:@"ChallengeRewards"];
    if (cha.challengeRewards == nil) {
        cha.challengeRewards = @[@100, @50, @50];
    }
    cha.sliderNum = [(NSNumber*)[dict valueForKey:@"SliderNum"] intValue];
    if (cha.sliderNum == 0) {
        cha.sliderNum = DEFUALT_SLIDER_NUM;
    }
    cha.cupType = [(NSNumber*)[dict valueForKey:@"CupType"] intValue];
    
    return cha;
}
@end

//=========================
@implementation ChallengePlay
+ (instancetype)playWithDictionary:(NSDictionary*)dict {
     ChallengePlay *play = [[ChallengePlay alloc] init];
    play.challengeId = [(NSNumber*)dict[@"ChallengeId"] longLongValue];
    play.highScore = [(NSNumber*)dict[@"HighScore"] intValue];
    play.cupType = [(NSNumber*)dict[@"CupType"] intValue];
    
    return play;
}

@end

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
    
    if (packInfo.text == nil || packInfo.text.length == 0) {
        packInfo.text = packInfo.title;
    }
    
    return packInfo;
}
@end

//=========================
@implementation PlayerInfo

+ (instancetype)playerWithDictionary:(NSDictionary*)dict {
    PlayerInfo *info = [[PlayerInfo alloc] init];
    
    info.userId = [(NSNumber*)[dict objectForKey:@"UserId"] longLongValue];
    info.nickName = [dict objectForKey:@"NickName"];
    info.gender = [(NSNumber*)[dict objectForKey:@"Gender"] intValue];
    info.teamName = [dict objectForKey:@"TeamName"];
    info.gravatarKey = [dict objectForKey:@"GravatarKey"];
    info.customAvatarKey = [dict objectForKey:@"CustomAvatarKey"];
    info.money = [(NSNumber*)[dict objectForKey:@"Money"] intValue];
    [info setTotalRewardRaw:[(NSNumber*)[dict objectForKey:@"TotalReward"] longLongValue]];
    info.rewardCache = [(NSNumber*)[dict objectForKey:@"RewardCache"] longLongValue];
    info.betCloseBeforeEndSec = [(NSNumber*)[dict objectForKey:@"BetCloseBeforeEndSec"] intValue];
    info.adsPercent = [(NSNumber*)[dict objectForKey:@"AdsPercent"] floatValue];
    info.currChallengeId = [(NSNumber*)[dict objectForKey:@"CurrChallengeId"] intValue];
    info.rateReward = [(NSNumber*)[dict objectForKey:@"RateReward"] intValue];
    return info;
}

- (void)setTotalRewardRaw:(SInt64)totalReward {
    _totalReward = totalReward;
}

- (void)setTotalReward:(SInt64)reward {
    int lv = self.level;
    _totalReward = reward;
    int newLv = self.level;
    if (lv != newLv) {
        NSString *str = [NSString stringWithFormat:@"升级啦🎉。%d➔%d", lv, newLv];
        alert(str, nil);
    }
}

- (int)level {
    SldGameData *gd = [SldGameData getInstance];
    for (int lv = 1; lv < gd.levelArray.count; lv++) {
        SInt64 v = [(NSNumber*)gd.levelArray[lv] longLongValue];
        if (_totalReward < v) {
            return lv - 1;
        }
    }
    
    return 100;
}

@end

//=========================
@implementation EventPlayRecored
+ (instancetype)recordWithDictionary:(NSDictionary*)dict {
    EventPlayRecored *record = [[EventPlayRecored alloc] init];
    record.highScore = [(NSNumber*)[dict objectForKey:@"HighScore"] intValue];
    record.trys = [(NSNumber*)[dict objectForKey:@"Trys"] intValue];
    record.rank = [(NSNumber*)[dict objectForKey:@"Rank"] intValue];
    record.rankNum = [(NSNumber*)[dict objectForKey:@"RankNum"] intValue];
    record.teamName = [dict objectForKey:@"TeamName"];
    if (record.teamName.length == 0) {
        record.teamName = [SldGameData getInstance].playerInfo.teamName;
    }
    record.gameCoinNum = [(NSNumber*)[dict objectForKey:@"GameCoinNum"] intValue];
    record.challengeHighScore = [(NSNumber*)[dict objectForKey:@"ChallengeHighScore"] intValue];
    
    record.matchReward = [(NSNumber*)[dict objectForKey:@"MatchReward"] longLongValue];
    record.betReward = [(NSNumber*)[dict objectForKey:@"BetReward"] longLongValue];
    record.betMoneySum = [(NSNumber*)[dict objectForKey:@"BetMoneySum"] longLongValue];
    id bet = (NSDictionary*)[dict objectForKey:@"Bet"];
    if ([bet isKindOfClass:[NSDictionary class]]) {
        record.bet = [NSMutableDictionary dictionaryWithDictionary:bet];
    } else {
        record.bet = [NSMutableDictionary dictionary];
    }
    return record;
}

@end

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
        
        if (_levelArray == nil) {
            _levelArray = [NSMutableArray arrayWithCapacity:101];
            
            SInt64 exp = 0;
            SInt64 add = 100;
            [_levelArray addObject:@(0)];
            for (int i = 0; i < 100; ++i) {
                [_levelArray addObject:@(exp)];
                exp += add;
                add *= 1.1;
            }
        }
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
    _eventInfo = nil;
    _packInfo = nil;
    _playerInfo = nil;
    _challengeInfo = nil;
    _challengePlay = nil;
    
    _userId = 0;
    _userName = nil;
    
    _needReloadEventList = NO;
}



@end

