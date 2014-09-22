//
//  SldMatchBriefController.m
//  pin
//
//  Created by 李炜 on 14-9-4.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldMatchBriefController.h"
#import "SldGameData.h"
#import "SldHttpSession.h"
#import "SldConfig.h"
#import "SldGameController.h"
#import "SldIapController.h"
#import "SldUtil.h"
#import "MSWeakTimer.h"
#import "UIImageView+sldAsyncLoad.h"


//==============================
@interface SldMatchBriefController ()
@property (weak, nonatomic) IBOutlet UIButton *practiceButton;
@property (weak, nonatomic) IBOutlet UIButton *matchButton;
@property (weak, nonatomic) IBOutlet UIButton *rewardButton;
@property (weak, nonatomic) IBOutlet UIButton *rankButton;

@property (weak, nonatomic) IBOutlet UILabel *bestScoreLabel;
@property (weak, nonatomic) IBOutlet UILabel *rankLabel;
@property (weak, nonatomic) IBOutlet UILabel *matchTimeLabel;
@property (weak, nonatomic) IBOutlet UILabel *tryNumLabel;

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *rewardLabel;
@property (weak, nonatomic) IBOutlet UIImageView *bgImageView;

@property (nonatomic) SldGameData *gd;
@property (nonatomic) MSWeakTimer *secTimer;
@property (nonatomic) MSWeakTimer *minTimer;

@property (nonatomic) NSString *secret;
@end

@implementation SldMatchBriefController

-(void)dealloc {
    [_secTimer invalidate];
    [_minTimer invalidate];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _gd = [SldGameData getInstance];
    _gd.matchPlay = nil;
    
    //timer
    _secTimer = [MSWeakTimer scheduledTimerWithTimeInterval:1.f target:self selector:@selector(onSecTimer) userInfo:nil repeats:YES dispatchQueue:dispatch_get_main_queue()];
    
    _minTimer = [MSWeakTimer scheduledTimerWithTimeInterval:60.f target:self selector:@selector(onSecTimer) userInfo:nil repeats:YES dispatchQueue:dispatch_get_main_queue()];
    
    //button disable
    _practiceButton.enabled = NO;
    _matchButton.enabled = NO;
    _rewardButton.enabled = NO;
    _rankButton.enabled = NO;
    
    //match info
    Match *match = _gd.match;
    _titleLabel.text = match.title;
    
    [self onSecTimer];
    
    //load pack
    [_gd loadPack:_gd.match.packId completion:^(PackInfo *packInfo) {
        [self refreshDynamicData];
        [self loadBackground];
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (_gd.matchPlay) {
        [self refreshUI];
    }
}

- (void)loadBackground{
    NSString *bgKey = [SldGameData getInstance].packInfo.coverBlur;
    
    [_bgImageView asyncLoadUploadedImageWithKey:bgKey showIndicator:NO completion:^{
        _bgImageView.alpha = 0.0;
        [UIView animateWithDuration:1.f animations:^{
            _bgImageView.alpha = 1.0;
        }];
    }];
}

- (void)onSecTimer {
    Match *match = _gd.match;
    MatchPlay *matchPlay = _gd.matchPlay;
    
    NSDate *beginTime = [NSDate dateWithTimeIntervalSince1970:match.beginTime];
    NSTimeInterval beginIntv = [beginTime timeIntervalSinceNow];
    
    NSDate *endTime = [NSDate dateWithTimeIntervalSince1970:match.endTime];
    NSTimeInterval endIntv = [endTime timeIntervalSinceNow];
    
    if (beginIntv > 0) {
        NSString *str = formatInterval((int)beginIntv);
        _matchTimeLabel.text = [NSString stringWithFormat:@"距离开始：%@", str];
        [_matchButton setTitle:@"未开始" forState:UIControlStateDisabled|UIControlStateNormal];
        _matchButton.enabled = NO;
    } else if (endIntv <= 0 ) {
        _matchTimeLabel.text = @"比赛已结束";
        [_matchButton setTitle:@"已结束" forState:UIControlStateDisabled|UIControlStateNormal];
        _matchButton.enabled = NO;
    } else {
        NSString *str = formatInterval((int)endIntv);
        
        _matchTimeLabel.text = [NSString stringWithFormat:@"比赛剩余：%@", str];
        
        [_matchButton setTitle:@"比赛" forState:UIControlStateDisabled|UIControlStateNormal];
        if (_gd.packInfo && matchPlay) {
            _matchButton.enabled = YES;
        } else {
            _matchButton.enabled = NO;
        }
    }
}

- (void)onMinTimer {
    [self refreshDynamicData];
}

- (void)refreshDynamicData {
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"MatchId":@(_gd.match.id)};
    [session postToApi:@"match/getDynamicData" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        _gd.matchPlay = [[MatchPlay alloc] initWithDict:dict];
        
        //reward
        _gd.match.extraReward = _gd.matchPlay.extraReward;
        _gd.match.playTimes = _gd.matchPlay.playTimes;
        
        //buttons
        _practiceButton.enabled = YES;
        _rewardButton.enabled = YES;
        _rankButton.enabled = YES;
        
        [self refreshUI];
    }];

}

- (void)refreshUI {
    //reward
    Match *match = _gd.match;
    if (match.extraReward == 0) {
        _rewardLabel.text = [NSString stringWithFormat:@"比赛奖金：%d", match.couponReward];
    } else {
        _rewardLabel.text = [NSString stringWithFormat:@"比赛奖金：%d+%d", match.couponReward, match.extraReward];
    }
    
    //score
    _bestScoreLabel.text = [NSString stringWithFormat:@"%@", formatScore(_gd.matchPlay.highScore)];
    
    //rank
    _rankLabel.text = [NSString stringWithFormat:@"我的排名：%d/%d", _gd.matchPlay.myRank, _gd.matchPlay.rankNum];
    
    //try number
    _tryNumLabel.text = [NSString stringWithFormat:@"尝试次数：%d", _gd.matchPlay.tries];
}

- (IBAction)onPracticeButton:(id)sender {
    _gd.gameMode = M_PRACTICE;
    _gd.autoPaging = NO;
    
    [self loadAndEnterGame];
}

- (IBAction)onMatchButton:(id)sender {
    MatchPlay *matchPlay = _gd.matchPlay;
    
    if (matchPlay.freeTries > 0) {
        NSString *str = [NSString stringWithFormat:@"剩余%d次免费机会，开始游戏吗？", matchPlay.freeTries];
        [[[UIAlertView alloc] initWithTitle:str
                                    message:nil
                           cancelButtonItem:[RIButtonItem itemWithLabel:@"取消" action:^{
            // Handle "Cancel"
        }]
                           otherButtonItems:[RIButtonItem itemWithLabel:@"开始游戏" action:^{
            [self playBegin];
        }], nil] show];
    } else {
        //check gold coin
        if (_gd.playerInfo.goldCoin == 0) {
            [[[UIAlertView alloc] initWithTitle:@"购买金币？"
                                        message:@"使用金币游戏可以：1.多一次挑战高分的机会。2.开启自动翻页，助你获得更好成绩。3.此金币加入到奖池中，您可能获得更高到奖金。"
                               cancelButtonItem:[RIButtonItem itemWithLabel:@"取消" action:^{
                // Handle "Cancel"
            }]
                               otherButtonItems:[RIButtonItem itemWithLabel:@"去购买金币" action:^{
                // buy
                SldIapController* vc = (SldIapController*)[getStoryboard() instantiateViewControllerWithIdentifier:@"iapController"];
                [self.navigationController pushViewController:vc animated:YES];
                
            }], nil] show];
        } else {
            NSString *str = [NSString stringWithFormat:@"花一枚金币，开始游戏？(现有%d金币)", _gd.playerInfo.goldCoin];
            
            [[[UIAlertView alloc] initWithTitle:str
                                        message:nil
                               cancelButtonItem:[RIButtonItem itemWithLabel:@"取消" action:^{
                // Handle "Cancel"
            }]
                               otherButtonItems:[RIButtonItem itemWithLabel:@"开始游戏" action:^{
                [self playBegin];
            }], nil] show];
        }
    }
    
//    [self loadAndEnterGame];
}

- (void)playBegin {
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"MatchId":@(_gd.match.id)};
    [session postToApi:@"match/playBegin" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        _gd.matchSecret = dict[@"Secret"];
        _gd.matchPlay.freeTries = [(NSNumber*)dict[@"FreeTries"] intValue];
        _gd.playerInfo.goldCoin = [(NSNumber*)dict[@"GoldCoin"] intValue];
        _gd.gameMode = M_MATCH;
        _gd.autoPaging = [(NSNumber*)dict[@"AutoPaging"] boolValue];
        
        [self loadAndEnterGame];
    }];
}

- (void)loadAndEnterGame {
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
        SldConfig *conf = [SldConfig getInstance];
        for (NSString *imageKey in imageKeys) {
            if (!imageExist(imageKey)) {
                [session downloadFromUrl:makeImageServerUrl2(imageKey, conf.UPLOAD_HOST)
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
    SldGameController *controller = [self.storyboard instantiateViewControllerWithIdentifier:@"game"];
    
    [self.navigationController pushViewController:controller animated:YES];
}

- (IBAction)onSocial:(id)sender {
    SldHttpSession *session = [SldHttpSession defaultSession];
    int msec = 0;
    if (_gd.matchPlay) {
        msec = -_gd.matchPlay.highScore;
    }
    
    UIAlertView* alt = alertNoButton(@"正在生成我的比赛...");
    NSDictionary *body = @{@"PackId":@(_gd.match.packId), @"SliderNum":@(_gd.match.sliderNum), @"Msec":@(msec)};
    [session postToApi:@"social/newPack" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [alt dismissWithClickedButtonIndex:0 animated:YES];
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        NSString *key = [dict objectForKey:@"Key"];
        
        //
        NSString *path = makeImagePath(_gd.match.thumb);
        UIImage *image = [UIImage imageWithContentsOfFile:path];
        NSString *url = [NSString stringWithFormat:@"%@?key=%@", [SldConfig getInstance].HTML5_URL, key];
        
        [[[UIAlertView alloc] initWithTitle:@"邀请朋友一起玩。朋友可以直接点开链接挑战，也可以下载客户端一起玩。"
                                    message:nil
                           cancelButtonItem:[RIButtonItem itemWithLabel:@"不了" action:^{
            // Handle "Cancel"
        }]
                           otherButtonItems:[RIButtonItem itemWithLabel:@"好的" action:^{
            NSString *text = [NSString stringWithFormat:@"我创建了一场比赛，敢来挑战么？"];
            if (_gd.matchPlay && _gd.matchPlay.highScore != 0) {
                text = [NSString stringWithFormat:@"我只用了%@就完成了比赛，敢来挑战么？", formatScore(_gd.matchPlay.highScore)];
            }
            [UMSocialData defaultData].extConfig.title = @"";
            [UMSocialData defaultData].extConfig.wechatSessionData.url = url;
            [UMSocialSnsService presentSnsIconSheetView:self
                                                 appKey:nil
                                              shareText:text
                                             shareImage:image
                                        shareToSnsNames:@[UMShareToWechatSession,UMShareToWechatTimeline]
                                               delegate:self];
        }], nil] show];
    }];
    
}


@end
