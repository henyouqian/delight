//
//  util.m
//  Sld
//
//  Created by Wei Li on 14-4-7.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "util.h"
#import "config.h"

NSString* getResFullPath(NSString* fileName) {
    return [[NSBundle mainBundle] pathForResource:fileName ofType:nil];
}

NSString* makeDocPath(NSString* path) {
    NSString *docsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
    return [docsPath stringByAppendingPathComponent:path];
}

UIAlertView* alert(NSString *title, NSString *message) {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title
                                                    message:message
                                                   delegate:nil
                                          cancelButtonTitle:@"OK"
                                          otherButtonTitles:nil];
    [alert show];
    return alert;
}

BOOL imageExist(NSString *imageKey) {
    NSString *path = makeImagePath(imageKey);
    return [[NSFileManager defaultManager] fileExistsAtPath:path];
}

NSString* makeImagePath(NSString *imageKey) {
    Config *conf = [Config sharedConf];
    return makeDocPath([NSString stringWithFormat:@"%@/%@", conf.IMG_CACHE_DIR, imageKey]);
}

NSString* makeImageServerUrl(NSString *imageKey) {
    Config *conf = [Config sharedConf];
    return [NSString stringWithFormat:@"%@/%@", conf.DATA_HOST, imageKey];
}

UIColor* makeUIColor(int r, int g, int b, int a) {
    return [UIColor colorWithRed:r/255.f green:g/255.f blue:b/255.f alpha:a/255.f];
}

UIStoryboard* getStoryboard() {
    UIApplication *application = [UIApplication sharedApplication];
    UIWindow *backWindow = application.windows[0];
    return backWindow.rootViewController.storyboard;
}

static NSTimeInterval serverTimeCorrect = 0;
void setServerNow(SInt64 now) {
    NSDate *nowDate = [NSDate dateWithTimeIntervalSinceNow:0];
    NSTimeInterval dt = [nowDate timeIntervalSince1970];
    serverTimeCorrect = now - dt;
    serverTimeCorrect = floor(serverTimeCorrect);
}

NSDate *getServerNow() {
    NSDate *now = [NSDate dateWithTimeIntervalSinceNow:serverTimeCorrect];
    return now;
}



