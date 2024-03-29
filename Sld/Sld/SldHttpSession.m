//
//  SldHttpSession.m
//  Sld
//
//  Created by Wei Li on 14-4-19.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldHttpSession.h"
#import "SldUtil.h"
#import "SldConfig.h"
#import "SldLoginViewController.h"
#import "SldUUIDLoginController.h"
#import "SldGameData.h"

@interface SldHttpSession()
@property (nonatomic) NSURLSession *session;
@property (nonatomic) NSURL *baseUrl;
@end

@implementation SldHttpSession

+ (instancetype)defaultSession {
    static SldHttpSession *sharedSession = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSString *host = [SldConfig getInstance].HOST;
        sharedSession = [[self alloc] initWithHost:host];
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
        conf.timeoutIntervalForRequest = 10;
        self.session = [NSURLSession sessionWithConfiguration:conf delegate:self delegateQueue: [NSOperationQueue mainQueue]];
    }
    
    return self;
}

- (void)URLSession:(NSURLSession *)session didReceiveChallenge:(NSURLAuthenticationChallenge *)challenge completionHandler:(void (^)(NSURLSessionAuthChallengeDisposition, NSURLCredential *))completionHandler{
    if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust]){
        if([challenge.protectionSpace.host isEqualToString:@"sld.pintugame.com"]){
            NSURLCredential *credential = [NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust];
            completionHandler(NSURLSessionAuthChallengeUseCredential,credential);
        }
    }
}

- (void)logoutWithComplete:(void(^)(void))complete{
    [_session resetWithCompletionHandler:^{
        if (complete) {
            complete();
        }
    }];
}

- (void)cancelAllTask {
    [_session invalidateAndCancel];
    NSURLSessionConfiguration *conf = [NSURLSessionConfiguration defaultSessionConfiguration];
    _session = [NSURLSession sessionWithConfiguration:conf delegate:nil delegateQueue: [NSOperationQueue mainQueue]];
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
                //lwError("post error: statusCode=%ld", (long)code);
                NSString *desc = [NSString stringWithFormat:@"Http error: statusCode=%ld", (long)code];
                error = [NSError errorWithDomain:@"lw" code:code userInfo:@{NSLocalizedDescriptionKey:desc}];
            }
            completionHandler(data, response, error);
        }];
    [task resume];
}

- (NSURLSessionDownloadTask*)downloadFromUrl:(NSString*)url
                 toPath:(NSString*)path
               withData:(id)data
      completionHandler:(void (^)(NSURL *location, NSURLResponse *response, NSError *error, id data))completionHandler
{
    NSURL * nsurl = [NSURL URLWithString:url];
    
    NSURLSessionDownloadTask *task =[self.session downloadTaskWithURL:nsurl
        completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
        if(error == nil) {
            NSError *err = nil;
            NSFileManager *fileManager = [NSFileManager defaultManager];
            NSURL *destURL = [NSURL fileURLWithPath:path];
            if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
                completionHandler(destURL, response, nil, data);
            } else {
                if ([fileManager moveItemAtURL:location
                                         toURL:destURL
                                         error: &err]) {
                    completionHandler(destURL, response, nil, data);
                } else {
                    completionHandler(nil, response, err, data);
                }
            }
        } else {
            completionHandler(nil, response, error, data);
        }
    }];
    [task resume];
    return task;
}

- (void)loadImageFromUrl:(NSString*)url
       completionHandler:(void (^)(NSString* localPath, NSError *error))completionHandler
{
    NSString *localPath = makeImagePathFromUrl(url);
    
    //complete if exist in local
    if ([[NSFileManager defaultManager] fileExistsAtPath:localPath]) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completionHandler(localPath, nil);
        });
        return;
    }
    
    NSURL* nsurl = [NSURL URLWithString:url];
    NSURLSessionDownloadTask *task =[self.session downloadTaskWithURL:nsurl
        completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error) {
            if(error == nil) {
                NSError *err = nil;
                NSFileManager *fileManager = [NSFileManager defaultManager];
                NSURL *destURL = [NSURL fileURLWithPath:localPath];
                if ([fileManager moveItemAtURL:location
                                         toURL:destURL
                                         error: &err]) {
                    completionHandler(localPath, nil);
                } else {
                    completionHandler(nil, err);
                }
            } else {
                completionHandler(nil, error);
            }
        }];
    [task resume];
}

BOOL isServerError(NSError *error) {
    if (!error) {
        return NO;
    }
    return (error.code == 400 || error.code == 500);
}

NSString* getServerErrorType(NSData *data) {
    NSError *jsonErr;
    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
    if (jsonErr) {
        return @"err_not_server_error";
    }
    NSString *errorType = [dict objectForKey:@"Error"];
    if (errorType) {
        return errorType;
    } else {
        return @"err_not_server_error";
    }
}

static BOOL _ishttpErrorShown = NO;

void alertHTTPError(NSError *error, NSData *data) {
    if (!error) return;
    if (error.code == 400 || error.code == 500) {
        NSError *jsonErr;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
        if (jsonErr) {
            alert(@"Json error", [jsonErr localizedDescription]);
            return;
        }
        NSString *errorType = [dict objectForKey:@"Error"];
        NSString *errorString = [dict objectForKey:@"ErrorString"];
        if (errorType && errorString) {
            if ([errorType compare:@"err_auth"] == 0) {
                UIViewController *vc = [[[UIApplication sharedApplication] keyWindow] visibleViewController];
                [[[UIAlertView alloc] initWithTitle:@"账号异常，请重新登录。"
                                            message:nil
                                   cancelButtonItem:[RIButtonItem itemWithLabel:@"好的" action:^{
                    SldGameData *gd = [SldGameData getInstance];
                    if (gd.online) {
                        //[SldLoginViewController createAndPresentWithCurrentController:vc animated:NO];
                        [SldUUIDLoginController presentWithCurrentController:vc animated:YES];
                    }
                    
                }]
                                   otherButtonItems:nil] show];
                
            } else {
                alert(errorType, errorString);
            }
            
            return;
        } else {
            alert(@"Error format error", [error localizedDescription]);
            return;
        }
    }
    
    //alert(@"HTTP error", [error localizedDescription]);
    
    if (!_ishttpErrorShown) {
        _ishttpErrorShown = YES;
        NSString *title = @"HTTP error";
        NSString *message = [error localizedDescription];
        if (error.code == -1004) {
            title = @"无法连接到服务器";
            message = nil;
        }
        
        [[[UIAlertView alloc] initWithTitle:title
                                    message:message
                           cancelButtonItem:[RIButtonItem itemWithLabel:@"OK" action:^{
            _ishttpErrorShown = NO;
        }]
                           otherButtonItems:nil] show];
    }
}


@end
