//
//  SldEventDetailViewController.m
//  Sld
//
//  Created by Wei Li on 14-4-24.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldEventDetailViewController.h"
#import "SldEventListViewController.h"
#import "SldDb.h"
#import "SldGameController.h"
#import "SldHttpSession.h"
#import "SldGameScene.h"
#import "SldGameData.h"
#import "SldOfflineEventEnterControler.h"
#import "util.h"
#import "config.h"
#import "UIImageView+sldAsyncLoad.h"


@interface SldEventDetailViewController ()
@property (weak, nonatomic) IBOutlet UIImageView *bgImageView;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *bestRecordLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeRemainLabel;
@property (weak, nonatomic) IBOutlet UILabel *rankLabel;
@property (weak, nonatomic) IBOutlet UILabel *beatLabel;
@property (weak, nonatomic) IBOutlet UIButton *matchButton;
@property (weak, nonatomic) NSTimer *timer;
@property (nonatomic) enum GameMode gameMode;
@property (nonatomic) SldGameData *gamedata;
@end

static __weak SldEventDetailViewController *g_eventDetailViewController = nil;

@implementation SldEventDetailViewController

+ (instancetype)getInstance {
    return g_eventDetailViewController;
}

-(void)dealloc {
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    g_eventDetailViewController = self;
    
    _gamedata = [SldGameData getInstance];
    
    //load pack data
    FMDatabase *db = [SldDb defaultDb].fmdb;
    FMResultSet *rs = [db executeQuery:@"SELECT data FROM pack WHERE id = ?", [NSNumber numberWithUnsignedLongLong:_gamedata.eventInfo.packId]];
    SldHttpSession *session = [SldHttpSession defaultSession];
    if ([rs next]) { //local
        NSString *data = [rs stringForColumnIndex:0];
        NSError *error = nil;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:[data dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        _gamedata.packInfo = [PackInfo packWithDictionary:dict];
        
        [self loadBackground];
        [self reloadData];
    } else { //server
        NSDictionary *body = @{@"Id":@(_gamedata.eventInfo.packId)};
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
            _gamedata.packInfo = [PackInfo packWithDictionary:dict];
            
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

    //get play result
    NSDictionary *body = @{@"EventId":@(_gamedata.eventInfo.id), @"UserId":@0};
    [session postToApi:@"event/getUserPlay" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        NSNumber *highScore = [dict objectForKey:@"HighScore"];
        NSNumber *rank = [dict objectForKey:@"Rank"];
        NSNumber *rankNum = [dict objectForKey:@"RankNum"];
        [self setPlayRecordWithHighscore:highScore rank:rank rankNum:rankNum];
    }];
    
//    //motion effect
//    UIInterpolatingMotionEffect *verticalMotionEffect =
//    [[UIInterpolatingMotionEffect alloc]
//     initWithKeyPath:@"center.y"
//     type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
//    verticalMotionEffect.minimumRelativeValue = @(-20);
//    verticalMotionEffect.maximumRelativeValue = @(20);
//    
//    // Set horizontal effect
//    UIInterpolatingMotionEffect *horizontalMotionEffect =
//    [[UIInterpolatingMotionEffect alloc]
//     initWithKeyPath:@"center.x"
//     type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
//    horizontalMotionEffect.minimumRelativeValue = @(-20);
//    horizontalMotionEffect.maximumRelativeValue = @(20);
//    
//    // Create group to combine both
//    UIMotionEffectGroup *group = [UIMotionEffectGroup new];
//    group.motionEffects = @[horizontalMotionEffect, verticalMotionEffect];
//    
//    // Add both effects to your view
//    [self.view addMotionEffect:group];
}

- (void)loadBackground{
    NSString *bgKey = [SldGameData getInstance].packInfo.coverBlur;
    
    BOOL imageExistLocal = imageExist(bgKey);
    [_bgImageView asyncLoadImageWithKey:bgKey showIndicator:NO completion:^{
        if (!imageExistLocal || _bgImageView.animationImages) {
            _bgImageView.alpha = 0.0;
            [UIView animateWithDuration:1.f animations:^{
                _bgImageView.alpha = 1.0;
            }];
        }
    }];
}

- (void)setPlayRecordWithHighscore:(NSNumber*)highScore rank:(NSNumber*)nRank rankNum:(NSNumber*)nRankNum {
    if (highScore) {
        if (_highScore == nil || [_highScore intValue] == 0 || [highScore intValue] > [_highScore intValue]) {
            _highScore = highScore;
            _highScoreStr = formatScore([highScore intValue]);
            
            [UIView animateWithDuration:.3f animations:^{
                _bestRecordLabel.alpha = 0.f;
            } completion:^(BOOL finished) {
                _bestRecordLabel.text = _highScoreStr;
                [UIView animateWithDuration:.3f animations:^{
                    _bestRecordLabel.alpha = 1.f;
                }];
            }];
        }
    }
    
    //rank
    int rank = 0;
    if (nRank) {
        rank = [nRank intValue];
        if (rank) {
            _rankLabel.text = [NSString stringWithFormat:@"第%d名", rank];
            _rankStr = [NSString stringWithFormat:@"%d", rank];
            
//            NSMutableAttributedString * string = [[NSMutableAttributedString alloc] initWithString:rankText];
//            [string addAttribute:NSForegroundColorAttributeName value:[UIColor redColor] range:NSMakeRange(1,[rankText length]-2)];
//            _rankLabel.attributedText=string;
        }
    }
    
    //beat
    if (rank && nRankNum) {
        int rankNum = [nRankNum intValue];
        if (rankNum) {
            int beatNum = rankNum-rank;
            float beatRate = 0.f;
            if (rankNum <= 1) {
                beatNum = 0;
            } else {
                beatRate = (float)(rankNum-rank)/(float)(rankNum-1);
            }
            _beatLabel.text = [NSString stringWithFormat:@"击败了%d人(%.1f%%)", beatNum, beatRate*100];
            
            float sat1 = 0;
            float sat2 = 0.65;
            float sat = sat1 + (sat2-sat1)*beatRate;
            UIColor *color = [UIColor colorWithHue:136.f/355.f saturation:sat brightness:1.f alpha:1.f];
            _rankLabel.textColor = color;
            //_beatLabel.textColor = color;
        }
        
        
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!_gamedata.eventInfo.hasResult) {
        _timer = [NSTimer scheduledTimerWithTimeInterval:1.f target:self selector:@selector(onTimer) userInfo:nil repeats:YES];
    }
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    [_timer invalidate];
}

- (void)onTimer {
    NSTimeInterval intv = [_gamedata.eventInfo.endTime timeIntervalSinceNow];
    if (intv < 0 || _gamedata.eventInfo.hasResult) {
        _timeRemainLabel.text = @"活动已结束";
        _matchButton.enabled = NO;
    } else {
        int sec = (int)intv;
        int hour = sec / 3600;
        int minute = (sec % 3600)/60;
        sec = (sec % 60);
        _timeRemainLabel.text = [NSString stringWithFormat:@"活动剩余%02d:%02d:%02d", hour, minute, sec];
        _matchButton.enabled = YES;
    }
}

- (void)reloadData {
    _titleLabel.text = _gamedata.packInfo.title;
    
    [self onTimer];
    //NSDate *now = [NSDate dateWithTimeIntervalSinceNow:0];
    //_event.endTime;
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

- (IBAction)onClickMatch:(id)sender {
    _gameMode = MATCH;
    [self loadPacks];
}

- (void)loadPacks {
    NSArray *imageKeys = _gamedata.packInfo.images;
    __block int localNum = 0;
    NSUInteger totalNum = [imageKeys count];
    if (totalNum == 0) {
        alert(@"Not downloaded", nil);
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
        [session cancelAllTask];
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
                    
                    //download complete
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
        controller.gameMode = _gameMode;
        controller.matchSecret = matchSecret;
        
        [self.navigationController pushViewController:controller animated:YES];
    };
    
    if (_gameMode == MATCH) {
        SldHttpSession *session = [SldHttpSession defaultSession];
        NSDictionary *body = @{@"EventId":@(_gamedata.eventInfo.id)};
        self.view.userInteractionEnabled = NO;
        [session postToApi:@"event/playBegin" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            self.view.userInteractionEnabled = YES;
            if (error) {
                alertHTTPError(error, data);
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
    } else { //practice
        //startGame(nil);
        SldOfflineEventEnterControler *controller = [self.storyboard instantiateViewControllerWithIdentifier:@"offlineEnter"];
        [self.navigationController pushViewController:controller animated:YES];
    }
    
    //update db
    FMDatabase *db = [SldDb defaultDb].fmdb;
    BOOL ok = [db executeUpdate:@"UPDATE event SET packDownloaded=1 WHERE id=?", @(_gamedata.eventInfo.id)];
    if (!ok) {
        lwError("Sql error:%@", [db lastErrorMessage]);
        return;
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
