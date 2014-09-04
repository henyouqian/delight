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
    inst.DATA_HOST = @"http://dn-pintugame.qbox.me";
    inst.UPLOAD_HOST = @"http://dn-pintuuserupload.qbox.me";
    inst.KEYCHAIN_SERVICE = @"com.liwei.Sld.HTTP_ACCOUNT";
    inst.KEYCHAIN_KV = @"com.liwei.Sld.KV";
    inst.STORE_ID = @"904649492";

    inst.HTML5_URL = @"http://pintuhtml5.qiniudn.com/index.html";
    inst.FLURRY_KEY = @"2P9DTVNTFZS8YBZ36QBZ";
    inst.MOGO_KEY = @"8c0728f759464dcda07c81afb00d3bf5";
    inst.UMENG_SOCIAL_KEY = @"53aeb00356240bdcb8050c26";
    inst.WEIXIN_KEY = @"wx9cb1a9d645c24d0a";
    

    inst.HOST = @"http://192.168.2.55:9998";
//    inst.HOST = @"http://192.168.1.43:9998";
//    inst.HOST = @"http://sld.pintugame.com";
    
    return inst;
}

- (void)updateWithDict:(NSDictionary*)dict {
    NSString *dataHost = [dict objectForKey:@"DataHost"];
    if (dataHost) {
        self.DATA_HOST = dataHost;
    }
    NSString *uploadHost = [dict objectForKey:@"UploadHost"];
    if (uploadHost) {
        self.UPLOAD_HOST = uploadHost;
    }
    NSString *storeId = [dict objectForKey:@"StoreId"];
    if (storeId) {
        self.STORE_ID = storeId;
    }
    NSString *html5Url = [dict objectForKey:@"Html5Url"];
    if (html5Url) {
        self.HTML5_URL = html5Url;
    }
    NSString *flurryKey = [dict objectForKey:@"FlurryKey"];
    if (flurryKey) {
        self.FLURRY_KEY = flurryKey;
    }
    NSString *mogoKey = [dict objectForKey:@"MogoKey"];
    if (mogoKey) {
        self.MOGO_KEY = mogoKey;
    }
    NSString *umengSocialKey = [dict objectForKey:@"UmengSocialKey"];
    if (umengSocialKey) {
        self.UMENG_SOCIAL_KEY = umengSocialKey;
    }
}

@end
