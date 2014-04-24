//
//  config.m
//  Sld
//
//  Created by Wei Li on 14-4-24.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "config.h"

@implementation Config
+ (instancetype)sharedConf {
    static Config *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[self alloc] init];
    });
    
    inst.IMG_CACHE_DIR = @"imgCache";
    inst.DATA_HOST = @"http://sliderpack.qiniudn.com";
    
    return inst;
}
@end
