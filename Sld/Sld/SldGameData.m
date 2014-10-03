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
    
    if (packInfo.text == nil || packInfo.text.length == 0) {
        packInfo.text = packInfo.title;
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
    info.goldCoin = [(NSNumber*)[dict objectForKey:@"GoldCoin"] intValue];
    info.coupon = [(NSNumber*)[dict objectForKey:@"Coupon"] floatValue];
    info.totalCoupon = [(NSNumber*)[dict objectForKey:@"TotalCoupon"] floatValue];
    info.couponCache = [(NSNumber*)[dict objectForKey:@"CouponCache"] floatValue];
    info.betCloseBeforeEndSec = [(NSNumber*)[dict objectForKey:@"BetCloseBeforeEndSec"] intValue];
    info.currChallengeId = [(NSNumber*)[dict objectForKey:@"CurrChallengeId"] intValue];
    info.rateReward = [(NSNumber*)[dict objectForKey:@"RateReward"] intValue];
    
    NSDictionary *adsConf = [dict objectForKey:@"AdsConf"];
    info.adsConf = [[AdsConf alloc] init];
    info.adsConf.showPercent = [(NSNumber*)[adsConf objectForKey:@"ShowPercent"] floatValue];
    info.adsConf.delayPercent = [(NSNumber*)[adsConf objectForKey:@"DelayPercent"] floatValue];
    info.adsConf.delaySec = [(NSNumber*)[adsConf objectForKey:@"DelaySec"] floatValue];
    
    gd.ownerRewardProportion = [(NSNumber*)[dict objectForKey:@"OwnerRewardProportion"] floatValue];
    return info;
}

@end

//=============================
@implementation Match

- (instancetype)initWithDict:(NSDictionary*)dict {
    if (self = [super init]) {
        _id = [(NSNumber*)[dict objectForKey:@"Id"] longLongValue];
        _packId = [(NSNumber*)[dict objectForKey:@"PackId"] longLongValue];
        _ownerId = [(NSNumber*)[dict objectForKey:@"OwnerId"] longLongValue];
        _sliderNum = [(NSNumber*)[dict objectForKey:@"SliderNum"] intValue];
        _rewardCoupon = [(NSNumber*)[dict objectForKey:@"RewardCoupon"] intValue];
        _thumb = [dict objectForKey:@"Thumb"];
        _title = [dict objectForKey:@"Title"];
        _playTimes = [(NSNumber*)[dict objectForKey:@"PlayTimes"] intValue];
        _extraCoupon = [(NSNumber*)[dict objectForKey:@"ExtraCoupon"] intValue];
        _beginTime = [(NSNumber*)[dict objectForKey:@"BeginTime"] longLongValue];
        _endTime = [(NSNumber*)[dict objectForKey:@"EndTime"] longLongValue];
        _hasResult = [(NSNumber*)[dict objectForKey:@"HasResult"] longLongValue];
        _rankRewardProportions = [dict objectForKey:@"RankRewardProportions"];
        if ((NSNull*)_rankRewardProportions == [NSNull null]) {
            _rankRewardProportions = nil;
        }
        _luckyRewardProportion = [(NSNumber*)[dict objectForKey:@"LuckyRewardProportion"] floatValue];
        _oneCoinRewardProportion = [(NSNumber*)[dict objectForKey:@"OneCoinRewardProportion"] floatValue];
        _ownerRewardProportion = [(NSNumber*)[dict objectForKey:@"OwnerRewardProportion"] floatValue];
        _challengeSeconds = [(NSNumber*)[dict objectForKey:@"ChallengeSeconds"] intValue];
        _promoUrl = [dict objectForKey:@"PromoUrl"];
        _promoImage = [dict objectForKey:@"PromoImage"];
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
        _extraCoupon = [(NSNumber*)dict[@"ExtraCoupon"] intValue];
        _highScore = [(NSNumber*)dict[@"HighScore"] intValue];
        _finalRank = [(NSNumber*)dict[@"FinalRank"] intValue];
        _freeTries = [(NSNumber*)dict[@"FreeTries"] intValue];
        _tries = [(NSNumber*)dict[@"Tries"] intValue];
        _myRank = [(NSNumber*)dict[@"MyRank"] intValue];
        _rankNum = [(NSNumber*)dict[@"RankNum"] intValue];
        _team = dict[@"Team"];
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


@end

