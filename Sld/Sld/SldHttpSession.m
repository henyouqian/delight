//
//  SldHttpSession.m
//  Sld
//
//  Created by Wei Li on 14-4-19.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldHttpSession.h"

static NSString *defaultHost = @"http://192.168.2.55:9999";

@interface SldHttpSession()
@property (nonatomic) NSURLSession *session;
@property (nonatomic) NSURL *baseUrl;
@end

@implementation SldHttpSession

+ (instancetype)sessionWithHost:(NSString*)host {
    return [[SldHttpSession alloc] initWithHost:host];
}

- (instancetype)initWithHost:(NSString*)host {
    if (self = [super init]) {
        self.baseUrl = [NSURL URLWithString:host];
        
        NSURLSessionConfiguration *conf = [NSURLSessionConfiguration defaultSessionConfiguration];
        self.session = [NSURLSession sessionWithConfiguration:conf];
    }
    
    return self;
}

- (void)postToApi:(NSString*)api body:(id)body completionHandler:(void (^)(id data, NSURLResponse *response, NSError *error))completionHandler {
    NSURL * url = [NSURL URLWithString:api relativeToURL:self.baseUrl];
    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:url];
    [request setHTTPMethod:@"POST"];
    
    if (body) {
        NSError *error;
        NSData *bodyData = [NSJSONSerialization dataWithJSONObject:body options:0 error:&error];
        if (error) {
            lwError("json encode error: %@", error);
            return;
        }
        [request setHTTPBody:bodyData];
    }
    
    NSURLSessionDataTask *task = [self.session dataTaskWithRequest:request
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *err) {
            __block NSError* error = err;
            dispatch_async(dispatch_get_main_queue(), ^{
                if (error) {
                    lwError("post error: %@", error);
                    completionHandler(data, response, error);
                    return;
                } else {
                    id jsonObj = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                    if (error) {
                        lwError("json decode error: %@", error);
                        completionHandler(data, response, error);
                        return;
                    }
                    NSInteger code = [(NSHTTPURLResponse*)response statusCode];
                    if (code != 200) {
                        lwError("post error: statusCode=%ld", (long)code);
                        NSString *desc = [NSString stringWithFormat:@"http error: statusCode=%ld", (long)code];
                        error = [NSError errorWithDomain:@"lw" code:code userInfo:@{NSLocalizedDescriptionKey:desc}];
                        completionHandler(jsonObj, response, error);
                        return;
                    }
                    completionHandler(jsonObj, response, error);
                    return;
                }
            });
        }];
    [task resume];
}

+ (instancetype)defaultSession {
    static SldHttpSession *sharedSession = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedSession = [[self alloc] initWithHost:defaultHost];
    });
    return sharedSession;
}

@end
