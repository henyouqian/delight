//
//  SldChallengeBriefController.m
//  Sld
//
//  Created by 李炜 on 14-7-8.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldChallengeBriefController.h"
#import "SldGameData.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldDb.h"
#import "SldHttpSession.h"
#import "SldGameController.h"
#import "SldUtil.h"

@interface SldChallengeBriefController ()
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@property (weak, nonatomic) IBOutlet UILabel *starLabel1;
@property (weak, nonatomic) IBOutlet UILabel *starLabel2;
@property (weak, nonatomic) IBOutlet UILabel *starLabel3;
@property (weak, nonatomic) IBOutlet UILabel *rewardLabel1;
@property (weak, nonatomic) IBOutlet UILabel *rewardLabel2;
@property (weak, nonatomic) IBOutlet UILabel *rewardLabel3;
@property (weak, nonatomic) IBOutlet UIImageView *bgImageView;
@property (weak, nonatomic) IBOutlet UIButton *startButton;
@property (weak, nonatomic) IBOutlet UIButton *commentButton;
@property (nonatomic) SldGameData *gd;

@end

@implementation SldChallengeBriefController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _gd = [SldGameData getInstance];
    _startButton.enabled = NO;
    _commentButton.enabled = NO;
    
    [self updateChallengeInfo];
    
    //load pack data
    ChallengeInfo *cha = _gd.challengeInfo;
    UInt64 packId = cha.packId;
    
    [_gd loadPack:packId completion:^(PackInfo *packInfo) {
        [self updatePackInfo];
    }];
    
//    FMDatabase *db = [SldDb defaultDb].fmdb;
//    FMResultSet *rs = [db executeQuery:@"SELECT data FROM pack WHERE id = ?", [NSNumber numberWithUnsignedLongLong:packId]];
//    
//    BOOL needGetFromServer = NO;
//    if ([rs next]) { //local
//        NSString *data = [rs stringForColumnIndex:0];
//        NSError *error = nil;
//        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:[data dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
//        if (error) {
//            lwError("Json error:%@", [error localizedDescription]);
//            return;
//        }
//        
////        PackInfo *packInfo = [PackInfo packWithDictionary:dict];
////        if (packInfo.timeUnix != cha.packTimeUnix) {
////            needGetFromServer = YES;
////        } else {
////            _gd.packInfo = packInfo;
////            [self updatePackInfo];
////        }
//        
//        PackInfo *packInfo = [PackInfo packWithDictionary:dict];
//        _gd.packInfo = packInfo;
//        [self updatePackInfo];
//        
//    } else {
//        needGetFromServer = YES;
//    }
//    
//    if (needGetFromServer) {
//        SldHttpSession *session = [SldHttpSession defaultSession];
//        NSDictionary *body = @{@"Id":@(packId)};
//        [session postToApi:@"pack/get" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
//            if (error) {
//                alertHTTPError(error, data);
//                return;
//            }
//            
//            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
//            if (error) {
//                lwError("Json error:%@", [error localizedDescription]);
//                return;
//            }
//            _gd.packInfo = [PackInfo packWithDictionary:dict];
//            
//            //save to db
//            BOOL ok = [db executeUpdate:@"REPLACE INTO pack (id, data) VALUES(?, ?)", dict[@"Id"], data];
//            if (!ok) {
//                lwError("Sql error:%@", [db lastErrorMessage]);
//                return;
//            }
//            
//            [self updatePackInfo];
//        }];
//    }
    
    //get play result
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"ChallengeId":@(_gd.challengeInfo.id)};
    [session postToApi:@"challenge/getPlay" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        BOOL hasErr = NO;
        if (error) {
            alertHTTPError(error, data);
            hasErr = YES;
        }
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            hasErr = YES;
        }
        
        if (hasErr) {
            [UIView animateWithDuration:.3f animations:^{
                _timeLabel.alpha = 0.f;
            } completion:^(BOOL finished) {
                _timeLabel.text = @"读取错误";
                [UIView animateWithDuration:.3f animations:^{
                    _timeLabel.alpha = 1.f;
                }];
            }];
            return;
        }
        
        _gd.challengePlay = [ChallengePlay playWithDictionary:dict];
        
        [self updateTime];
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (_gd.needReloadChallengeTime) {
        _gd.needReloadChallengeTime = NO;
        [self updateTime];
    }
}

- (void)updateChallengeInfo {
    NSArray *secs = _gd.challengeInfo.challengeSecs;
    if (secs != nil && secs.count == 3) {
        _starLabel3.text = formatScore([(NSNumber*)secs[0] intValue]*-1000);
        _starLabel2.text = formatScore([(NSNumber*)secs[1] intValue]*-1000);
        _starLabel1.text = formatScore([(NSNumber*)secs[2] intValue]*-1000);
    } else {
        NSString *text = @"−:−−.−−−";
        _starLabel3.text = text;
        _starLabel2.text = text;
        _starLabel1.text = text;
    }
    
    NSArray *rewards = _gd.challengeInfo.challengeRewards;
    if (rewards != nil && rewards.count == 3) {
        int reward0 = [(NSNumber*)rewards[0] intValue];
        int reward1 = [(NSNumber*)rewards[1] intValue];
        int reward2 = [(NSNumber*)rewards[2] intValue];
        
        _rewardLabel3.text = [NSString stringWithFormat:@"%d金币", reward0+reward1+reward2];
        _rewardLabel2.text = [NSString stringWithFormat:@"%d金币", reward1+reward2];
        _rewardLabel1.text = [NSString stringWithFormat:@"%d金币", reward2];
    }
}

- (void)updatePackInfo {
    [self loadBackground];
    _titleLabel.text = _gd.packInfo.title;
    _startButton.enabled = YES;
    _commentButton.enabled = YES;
}

- (void)updateTime {
    //update time label
    NSString *str = formatScore(_gd.challengePlay.highScore);
    [UIView animateWithDuration:.3f animations:^{
        _timeLabel.alpha = 0.f;
    } completion:^(BOOL finished) {
        _timeLabel.text = str;
        [UIView animateWithDuration:.3f animations:^{
            _timeLabel.alpha = 1.f;
        }];
    }];
    
    //set star time color
    _starLabel1.textColor = [UIColor whiteColor];
    _starLabel2.textColor = [UIColor whiteColor];
    _starLabel3.textColor = [UIColor whiteColor];
    _rewardLabel1.textColor = [UIColor whiteColor];
    _rewardLabel2.textColor = [UIColor whiteColor];
    _rewardLabel3.textColor = [UIColor whiteColor];
    
    NSArray *secs = _gd.challengeInfo.challengeSecs;
    if (secs != nil && secs.count == 3) {
        int msec = -_gd.challengePlay.highScore;
        UIColor *color = _timeLabel.textColor;
        if (msec > 0) {
            if (msec <= [(NSNumber*)secs[0] intValue]*1000) {
                _starLabel3.textColor = color;
                _rewardLabel3.textColor = color;
                //self.title = @"挑战模式⭐️⭐️⭐️";
            } else if (msec <= [(NSNumber*)secs[1] intValue]*1000) {
                _starLabel2.textColor = color;
                _rewardLabel2.textColor = color;
                //self.title = @"挑战模式⭐️⭐️";
            } else if (msec <= [(NSNumber*)secs[2] intValue]*1000) {
                _starLabel1.textColor = color;
                _rewardLabel1.textColor = color;
                //self.title = @"挑战模式⭐️";
            }
        }
    }
}

- (void)loadBackground{
    NSString *bgKey = [SldGameData getInstance].packInfo.coverBlur;
    
    [_bgImageView asyncLoadImageWithKey:bgKey showIndicator:NO completion:^{
        _bgImageView.alpha = 0.0;
        [UIView animateWithDuration:1.f animations:^{
            _bgImageView.alpha = 1.0;
        }];
    }];
}

- (IBAction)onStartButton:(id)sender {
    NSArray *imageKeys = _gd.packInfo.images;
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
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"图集下载中..."
                                                        message:msg
                                                       delegate:self
                                              cancelButtonTitle:@"取消"
                                              otherButtonTitles:nil];
        [alert show];
        
        //download
        SldHttpSession *session = [SldHttpSession defaultSession];
        [session cancelAllTask];
        for (NSString *imageKey in imageKeys) {
            if (!imageExist(imageKey)) {
                [session downloadFromUrl:makeImageServerUrl(imageKey)
                                  toPath:makeImagePath(imageKey)
                                withData:nil completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error, id data)
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

- (void)enterGame {
    _gd.gameMode = CHALLENGE;
    //update db
    FMDatabase *db = [SldDb defaultDb].fmdb;
    BOOL ok = [db executeUpdate:@"UPDATE event SET packDownloaded=1 WHERE id=?", @(_gd.challengeInfo.id)];
    if (!ok) {
        lwError("Sql error:%@", [db lastErrorMessage]);
        return;
    }
    
    //
    SldGameController *controller = [self.storyboard instantiateViewControllerWithIdentifier:@"game"];
    _gd.matchSecret = nil;
    
    [self.navigationController pushViewController:controller animated:YES];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
