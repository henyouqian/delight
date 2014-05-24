//
//  SldGameData.m
//  Sld
//
//  Created by Wei Li on 14-5-5.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldGameData.h"

@implementation EventInfo
+ (instancetype)eventWithDictionary:(NSDictionary*)dict {
    EventInfo *event = [[EventInfo alloc] init];
    
    event.id = [(NSNumber*)dict[@"Id"] unsignedLongLongValue];
    event.thumb = dict[@"Thumb"];
    event.packId = [(NSNumber*)dict[@"PackId"] unsignedLongLongValue];
    event.beginTime = [NSDate dateWithTimeIntervalSince1970:[(NSNumber*)dict[@"BeginTime"] longLongValue]];
    event.endTime = [NSDate dateWithTimeIntervalSince1970:[(NSNumber*)dict[@"EndTime"] longLongValue]];
    event.hasResult = [(NSNumber*)[dict valueForKey:@"HasResult"] boolValue];
    
    return event;
}
@end

@implementation PackInfo
+ (instancetype)packWithDictionary:(NSDictionary*)dict {
    PackInfo *packInfo = [[PackInfo alloc] init];
    
    packInfo.id = [(NSNumber*)dict[@"Id"] unsignedLongLongValue];
    packInfo.title = dict[@"Title"];
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
    
    return packInfo;
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
        _online = NO;
        _recentScore = 0;
    }
    return self;
}

@end

