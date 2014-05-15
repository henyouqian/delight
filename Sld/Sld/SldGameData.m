//
//  SldGameData.m
//  Sld
//
//  Created by Wei Li on 14-5-5.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldGameData.h"

@implementation EventInfo

@end

@implementation PackInfo
+ (instancetype)packWithDictionary:(NSDictionary*)dict {
    PackInfo *packInfo = [[PackInfo alloc] init];
    NSError *error = nil;

    packInfo.id = [(NSNumber*)dict[@"Id"] unsignedLongLongValue];
    packInfo.title = dict[@"Title"];
    packInfo.thumb = dict[@"Thumb"];
    packInfo.cover = dict[@"Cover"];
    packInfo.coverBlur = dict[@"CoverBlur"];
    if ([packInfo.coverBlur length] == 0) {
        packInfo.coverBlur = packInfo.cover;
    }
    NSArray *imgs = dict[@"Images"];
    if (error) {
        lwError("Json error:%@", [error localizedDescription]);
        return packInfo;
    }
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

- (instancetype)init {
    if ([super init]) {
        _eventInfos = [NSMutableArray arrayWithCapacity:20];
        _online = NO;
    }
    return self;
}

@end

