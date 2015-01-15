//
//  SldConfig.m
//  Sld
//
//  Created by Wei Li on 14-4-24.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldConfig.h"
#import "SldUtil.h"

NSUInteger const LOCAL_SCORE_COUNT_LIMIT = 10;
const int MATCH_FETCH_LIMIT = 30;

UIColor *_matchTimeLabelRed = nil;
UIColor *_matchTimeLabelGreen = nil;

@implementation SldConfig
+ (instancetype)getInstance {
    static SldConfig *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[self alloc] init];
        
        inst.IMG_CACHE_DIR = @"imgCache";
        inst.DATA_HOST = @"http://dn-pintugame.qbox.me";
        inst.UPLOAD_HOST = @"http://dn-pintuuserupload.qbox.me";
        inst.PRIVATE_UPLOAD_HOST = @"http://7tebsf.com1.z0.glb.clouddn.com";
        inst.KEYCHAIN_SERVICE = @"com.liwei.Sld.HTTP_ACCOUNT";
        inst.KEYCHAIN_KV = @"com.liwei.Sld.KV";
        inst.STORE_ID = @"923531990";
        
        inst.USER_HOME_URL = @"http://www.pintugame.com/user.html";
        inst.HTML5_URL = @"http://pintuhtml5.qiniudn.com/index.html";
        inst.FLURRY_KEY = @"2P9DTVNTFZS8YBZ36QBZ";
        inst.MOGO_KEY = @"8c0728f759464dcda07c81afb00d3bf5";
        inst.UMENG_SOCIAL_KEY = @"53aeb00356240bdcb8050c26";
        inst.WEIXIN_KEY = @"wxa959a211a5061fb6";
        inst.WEIXIN_SEC = @"b3e3e5593a736a3439529d881cf85a1e";
        
        inst.GRAVATAR_URL = @"http://en.gravatar.com/avatar";
        
        inst.WEB_SOCKET_URL = @"ws://192.168.2.55:9977/ws";
        
        //distcheck
//        inst.HOST = @"http://192.168.2.55:9998";
//        inst.HOST = @"http://192.168.1.43:9998";
        inst.HOST = @"http://sld.pintugame.com";
//        inst.HOST = @"http://120.27.31.146:9998";
        
        _matchTimeLabelGreen = makeUIColor(71, 186, 43, 180);
        _matchTimeLabelRed = makeUIColor(40, 40, 40, 120);
    });
    
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
    NSString *privateUploadHost = [dict objectForKey:@"PrivateUploadHost"];
    if (privateUploadHost) {
        self.PRIVATE_UPLOAD_HOST = privateUploadHost;
    }

    NSString *storeId = [dict objectForKey:@"StoreId"];
    if (storeId) {
        self.STORE_ID = storeId;
    }
    NSString *userHomeUrl = [dict objectForKey:@"UserHomeUrl"];
    if (userHomeUrl) {
        self.USER_HOME_URL = userHomeUrl;
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
    NSString *weixinKey = [dict objectForKey:@"WeiXinKey"];
    if (weixinKey) {
        self.WEIXIN_KEY = weixinKey;
    }
    NSString *weixinSec = [dict objectForKey:@"WeiXinSec"];
    if (weixinSec) {
        self.WEIXIN_SEC = weixinSec;
    }
    
    NSString *gravatarUrl = [dict objectForKey:@"GravatarUrl"];
    if (gravatarUrl) {
        self.GRAVATAR_URL = gravatarUrl;
    }
    
    NSString *websocketUrl = [dict objectForKey:@"WebSocketUrl"];
    if (websocketUrl) {
        self.WEB_SOCKET_URL = websocketUrl;
    }
}

@end
