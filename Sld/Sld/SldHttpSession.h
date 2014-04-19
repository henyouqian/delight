//
//  SldHttpSession.h
//  Sld
//
//  Created by Wei Li on 14-4-19.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

@interface SldHttpSession : NSObject

+ (instancetype)sessionWithHost:(NSString*)host;
- (void)postToApi:(NSString*)api body:(id)body completionHandler:(void (^)(id data, NSURLResponse *response, NSError *error))completionHandler;

+ (instancetype)defaultSession;

@end
