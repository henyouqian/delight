//
//  SldGameData.m
//  Sld
//
//  Created by Wei Li on 14-5-5.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldGameData.h"

const UInt32 DEFUALT_SLIDER_NUM = 6;

@implementation EventInfo
+ (instancetype)eventWithDictionary:(NSDictionary*)dict {
    EventInfo *event = [[EventInfo alloc] init];
    
    event.id = [(NSNumber*)dict[@"Id"] unsignedLongLongValue];
    event.thumb = dict[@"Thumb"];
    event.packId = [(NSNumber*)dict[@"PackId"] unsignedLongLongValue];
    event.beginTime = [NSDate dateWithTimeIntervalSince1970:[(NSNumber*)dict[@"BeginTime"] longLongValue]];
    event.endTime = [NSDate dateWithTimeIntervalSince1970:[(NSNumber*)dict[@"EndTime"] longLongValue]];
    event.hasResult = [(NSNumber*)[dict valueForKey:@"HasResult"] boolValue];
    event.challengeSecs = [dict valueForKey:@"ChallengeSecs"];
    if ([event.challengeSecs isKindOfClass:[NSNull class]]) {
        event.challengeSecs = [NSArray array];
    }
    event.sliderNum = [(NSNumber*)[dict valueForKey:@"SliderNum"] unsignedLongValue];
    if (event.sliderNum == 0) {
        event.sliderNum = DEFUALT_SLIDER_NUM;
    }
    
    return event;
}
@end

@implementation PackInfo
+ (instancetype)packWithDictionary:(NSDictionary*)dict {
    PackInfo *packInfo = [[PackInfo alloc] init];
    
    packInfo.id = [(NSNumber*)dict[@"Id"] unsignedLongLongValue];
    packInfo.title = dict[@"Title"];
    packInfo.text = dict[@"Text"];
    packInfo.thumb = dict[@"Thumb"];
    packInfo.cover = dict[@"Cover"];
    packInfo.coverBlur = dict[@"CoverBlur"];
    if ([packInfo.coverBlur length] == 0) {
        packInfo.coverBlur = packInfo.cover;
    }
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

@implementation EventPlayRecored
+ (instancetype)recordWithDictionary:(NSDictionary*)dict {
    EventPlayRecored *record = [[EventPlayRecored alloc] init];
    record.highScore = [(NSNumber*)[dict objectForKey:@"HighScore"] intValue];
    record.trys = [(NSNumber*)[dict objectForKey:@"Trys"] intValue];
    record.rank = [(NSNumber*)[dict objectForKey:@"Rank"] intValue];
    record.rankNum = [(NSNumber*)[dict objectForKey:@"RankNum"] intValue];
    record.teamName = [dict objectForKey:@"TeamName"];
    if (record.teamName.length == 0) {
        record.teamName = [SldGameData getInstance].teamName;
    }
    record.gameCoinNum = [(NSNumber*)[dict objectForKey:@"GameCoinNum"] intValue];
    record.challangeHighScore = [(NSNumber*)[dict objectForKey:@"ChallangeHighScore"] intValue];
    
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
        _eventInfos = [NSMutableArray arrayWithCapacity:20];
        
        [self reset];
    }
    return self;
}

- (void)resetEvent {
    _packInfo = nil;
    _recentScore = 0;
}

- (void)reset {
    _online = NO;
    _recentScore = 0;
    _eventInfo = nil;
    _packInfo = nil;
    
    _userId = 0;
    _userName = nil;
    
    _nickName = nil;
    _gender = 0;
    _teamName = nil;
    _gravatarKey = nil;
    _money = 0;
}

@end

