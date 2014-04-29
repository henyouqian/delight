//
//  SldHttpSession.m
//  Sld
//
//  Created by Wei Li on 14-4-19.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldHttpSession.h"

static NSString *defaultHost = @"http://192.168.2.55:9999";
//static NSString *defaultHost = @"http://192.168.1.43:9999";

@interface SldHttpSession()
@property (nonatomic) NSURLSession *session;
@property (nonatomic) NSURL *baseUrl;
@end

@implementation SldHttpSession

+ (instancetype)defaultSession {
    static SldHttpSession *sharedSession = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedSession = [[self alloc] initWithHost:defaultHost];
    });
    return sharedSession;
}

+ (instancetype)sessionWithHost:(NSString*)host {
    return [[SldHttpSession alloc] initWithHost:host];
}

- (instancetype)initWithHost:(NSString*)host {
    if (self = [super init]) {
        self.baseUrl = [NSURL URLWithString:host];
        
        NSURLSessionConfiguration *conf = [NSURLSessionConfiguration defaultSessionConfiguration];
        //self.session = [NSURLSession sessionWithConfiguration:conf];
        self.session = [NSURLSession sessionWithConfiguration:conf delegate:nil delegateQueue: [NSOperationQueue mainQueue]];
    }
    
    return self;
}

- (void)postToApi:(NSString*)api body:(id)body completionHandler:(void (^)(NSData *data, NSURLResponse *response, NSError *error))completionHandler {
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
        completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            NSInteger code = [(NSHTTPURLResponse*)response statusCode];
            if (!error && code != 200) {
                lwError("post error: statusCode=%ld", (long)code);
                NSString *desc = [NSString stringWithFormat:@"Http error: statusCode=%ld", (long)code];
                error = [NSError errorWithDomain:@"lw" code:code userInfo:@{NSLocalizedDescriptionKey:desc}];
            }
            completionHandler(data, response, error);
        }];
    [task resume];
}

- (void)downloadFromUrl:(NSString*)url
                 toPath:(NSString*)path
               withData:(id)data
      completionHandler:(void (^)(NSURL *location, NSError *error, id data))completionHandler
{
    NSURL * nsurl = [NSURL URLWithString:url];
    
    NSURLSessionDownloadTask *task =[self.session downloadTaskWithURL:nsurl
        completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        if(error == nil) {
            NSError *err = nil;
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSURL *destURL = [NSURL fileURLWithPath:path];
            if ([fileManager moveItemAtURL:location
                                       toURL:destURL
                                       error: &err]) {
                completionHandler(destURL, nil, data);
            } else {
                completionHandler(nil, err, data);
            }
        } else {
            completionHandler(nil, error, data);
        }
    }];
    [task resume];
}

@end
