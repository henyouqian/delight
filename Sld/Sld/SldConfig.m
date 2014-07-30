//
//  SldConfig.m
//  Sld
//
//  Created by Wei Li on 14-4-24.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldConfig.h"

NSUInteger const LOCAL_SCORE_COUNT_LIMIT = 10;

@implementation SldConfig
+ (instancetype)getInstance {
    static SldConfig *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[self alloc] init];
    });
    
    inst.IMG_CACHE_DIR = @"imgCache";
    //inst.DATA_HOST = @"http://sliderpack.qiniudn.com";
    inst.DATA_HOST = @"http://dn-pintugame.qbox.me";
    inst.KEYCHAIN_SERVICE = @"com.liwei.Sld.HTTP_ACCOUNT";
    inst.STORE_ID = @"904649492";

    inst.HTML5_URL = @"http://pintuhtml5.qiniudn.com/index.html";
    inst.FLURRY_KEY = @"2P9DTVNTFZS8YBZ36QBZ";
    inst.MOGO_KEY = @"8c0728f759464dcda07c81afb00d3bf5";
    inst.UMENG_SOCIAL_KEY = @"53aeb00356240bdcb8050c26";
    inst.WEIXIN_KEY = @"wxe2fdd22f81b2eb28";
    

    inst.HOST = @"http://192.168.2.55:9998";
//    inst.HOST = @"http://192.168.1.43:9998";
//    inst.HOST = @"http://sld1_2.pintugame.com";
    
    return inst;
}
@end
