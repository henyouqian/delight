//
//  SldEventDetailViewController.m
//  Sld
//
//  Created by Wei Li on 14-4-24.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldEventDetailViewController.h"
#import "SldDb.h"
#import "SldGameController.h"
#import "SldHttpSession.h"
#import "SldGameScene.h"
#import "util.h"
#import "config.h"
#import "UIImage+animatedGIF.h"

@implementation PackInfo
+ (instancetype)packWithDictionary:(NSDictionary*)dict {
    PackInfo *packInfo = [[PackInfo alloc] init];
    NSError *error = nil;
//    NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:[json dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
//    if (error) {
//        lwError("Json error:%@", [error localizedDescription]);
//        return packInfo;
//    }
    packInfo.id = [(NSNumber*)dict[@"Id"] unsignedLongLongValue];
    packInfo.title = dict[@"Title"];
    packInfo.thumb = dict[@"Thumb"];
    packInfo.cover = dict[@"Cover"];
    packInfo.coverBlur = dict[@"CoverBlur"];
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

@interface SldEventDetailViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *bgView;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *bestRecordLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeRemainLabel;
@property (weak, nonatomic) NSTimer *timer;
@property (nonatomic) enum GameMode gameMode;
@end

@implementation SldEventDetailViewController

-(void)dealloc {
    
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    //load pack data
    FMDatabase *db = [SldDb defaultDb].fmdb;
    FMResultSet *rs = [db executeQuery:@"SELECT data FROM pack WHERE id = ?", [NSNumber numberWithUnsignedLongLong:self.event.packId]];
    if ([rs next]) { //local
        NSString *data = [rs stringForColumnIndex:0];
        NSError *error = nil;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:[data dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
            if (error) {
                lwError("Json error:%@", [error localizedDescription]);
                return;
            }
        self.packInfo = [PackInfo packWithDictionary:dict];
        
        [self loadBackground];
        [self reloadData];
    } else { //server
        SldHttpSession *session = [SldHttpSession defaultSession];
        NSDictionary *body = @{@"Id":@(self.event.packId)};
        [session postToApi:@"pack/get" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                lwError("Http error:%@", [error localizedDescription]);
                return;
            }
            
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error) {
                lwError("Json error:%@", [error localizedDescription]);
                return;
            }
            self.packInfo = [PackInfo packWithDictionary:dict];
            
            //save to db
            BOOL ok = [db executeUpdate:@"REPLACE INTO pack (id, data) VALUES(?, ?)", dict[@"Id"], data];
            if (!ok) {
                lwError("Sql error:%@", [db lastErrorMessage]);
                return;
            }
            
            [self loadBackground];
            [self reloadData];
        }];
    }

    
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    _timer = [NSTimer scheduledTimerWithTimeInterval:1.f target:self selector:@selector(onTimer) userInfo:nil repeats:YES];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [_timer invalidate];
}

- (void)onTimer {
    NSTimeInterval intv = [_event.endTime timeIntervalSinceNow];
    int sec = (int)intv;
    int hour = sec / 3600;
    int minute = (sec % 3600)/60;
    sec = (sec % 60);
    _timeRemainLabel.text = [NSString stringWithFormat:@"活动剩余%02d:%02d:%02d", hour, minute, sec];
}

- (void)reloadData {
    _titleLabel.text = _packInfo.title;
    
    [self onTimer];
    //NSDate *now = [NSDate dateWithTimeIntervalSinceNow:0];
    //_event.endTime;
}

- (void)loadBackground {
    Config *conf = [Config sharedConf];
    NSString *bgFile = self.packInfo.cover;
    if ([self.packInfo.coverBlur length]) {
        bgFile = self.packInfo.coverBlur;
    }
    NSString *bgPath = makeDocPath([NSString stringWithFormat:@"%@/%@", conf.IMG_CACHE_DIR, bgFile]);
    if ([[NSFileManager defaultManager] fileExistsAtPath:bgPath]) { //local
        UIImage *image = nil;
        if ([[[bgPath pathExtension] lowercaseString] compare:@"gif"] == 0) {
            NSURL *url = [NSURL fileURLWithPath:bgPath];
            image = [UIImage animatedImageWithAnimatedGIFURL:url];
        } else {
            image = [UIImage imageWithContentsOfFile:bgPath];
        }
        self.bgView.image = image;
    } else { //server
        //download
        SldHttpSession *session = [SldHttpSession defaultSession];
        [session downloadFromUrl:[NSString stringWithFormat:@"%@/%@", conf.DATA_HOST, bgFile]
                          toPath:bgPath
                        withData:nil completionHandler:^(NSURL *location, NSError *error, id data)
         {
             UIImage *image = [UIImage imageWithContentsOfFile:bgPath];
             self.bgView.image = image;
             
             self.bgView.alpha = 0.0;
             [UIView beginAnimations:@"fade in" context:nil];
             [UIView setAnimationDuration:1.0];
             self.bgView.alpha = 1.0;
             [UIView commitAnimations];
         }];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Button callback
- (IBAction)onClickPractice:(id)sender {
    _gameMode = PRACTICE;
    [self loadPacks];
}

- (IBAction)onClickBattle:(id)sender {
    _gameMode = BATTLE;
    [self loadPacks];
}

- (IBAction)onClickMatch:(id)sender {
    _gameMode = MATCH;
    [self loadPacks];
}

- (void)loadPacks {
    NSArray *imageKeys = self.packInfo.images;
    __block int localNum = 0;
    NSUInteger totalNum = [imageKeys count];
    if (totalNum == 0) {
        return;
    }
    for (NSString *imageKey in imageKeys) {
        if (imageExist(imageKey)) {
            localNum++;
        }
    }
    if (localNum == totalNum) {
        [self enterGame];
        return;
    } else if (localNum < totalNum) {
        NSString *msg = [NSString stringWithFormat:@"%d%%", (int)(100.f*(float)localNum/(float)totalNum)];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Download..."
                                                        message:msg
                                                       delegate:self
                                              cancelButtonTitle:@"Cancel"
                                              otherButtonTitles:nil];
        [alert show];
        
        //download
        SldHttpSession *session = [SldHttpSession defaultSession];
        for (NSString *imageKey in imageKeys) {
            if (!imageExist(imageKey)) {
                [session downloadFromUrl:makeImageServerUrl(imageKey)
                                  toPath:makeImagePath(imageKey)
                                withData:nil completionHandler:^(NSURL *location, NSError *error, id data)
                {
                    if (error) {
                        lwError("Download error: %@", error.localizedDescription);
                        [alert dismissWithClickedButtonIndex:0 animated:YES];
                        return;
                    }
                    localNum++;
                    [alert setMessage:[NSString stringWithFormat:@"%d%%", (int)(100.f*(float)localNum/(float)totalNum)]];
                    
                    if (localNum == totalNum) {
                        [alert dismissWithClickedButtonIndex:0 animated:YES];
                        [self enterGame];
                    }
                }];
            }
        }
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    [[SldHttpSession defaultSession] cancelAllTask];
}

- (void)enterGame {
    void (^startGame)(NSString *) = ^(NSString *matchSecret){
        SldGameController *controller = [self.storyboard instantiateViewControllerWithIdentifier:@"game"];
        controller.packInfo = self.packInfo;
        controller.gameMode = _gameMode;
        controller.matchSecret = matchSecret;
        [self.navigationController pushViewController:controller animated:YES];
    };
    
    if (_gameMode == MATCH) {
        SldHttpSession *session = [SldHttpSession defaultSession];
        NSDictionary *body = @{@"EventId":@(_event.id)};
        [session postToApi:@"event/playBegin" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                alertServerError(error, data);
            } else {
                NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                if (error) {
                    alert(@"Json error", [error localizedDescription]);
                    return;
                }
                NSString *matchSecret = [dict objectForKey:@"Secret"];
                startGame(matchSecret);
            }
        }];
        
    } else {
        startGame(nil);
    }
    
}

#pragma mark - Navigation
//- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
//{
//    SldGameController *controller = [segue destinationViewController];
//    controller.packInfo = self.packInfo;
//    
//    
////    if ([segue.identifier compare:@"practice"] == 0) {
////        
////    } else if ([segue.identifier compare:@"match"] == 0) {
////        
////    }
//}


@end
