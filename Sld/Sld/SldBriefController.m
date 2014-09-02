//
//  SldEventDetailViewController.m
//  Sld
//
//  Created by Wei Li on 14-4-24.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldBriefController.h"
#import "SldEventListViewController.h"
#import "SldDb.h"
#import "SldGameController.h"
#import "SldHttpSession.h"
#import "SldGameScene.h"
#import "SldGameData.h"
#import "SldOfflineEventEnterControler.h"
//#import "SldMatchPrepareController.h"
#import "SldUtil.h"
#import "SldConfig.h"
#import "UIImageView+sldAsyncLoad.h"
#import "MSWeakTimer.h"


@interface SldBriefController ()
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *bestRecordLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeRemainLabel;
@property (weak, nonatomic) IBOutlet UILabel *rankLabel;
@property (weak, nonatomic) IBOutlet UILabel *rankNumLabel;
@property (weak, nonatomic) IBOutlet UILabel *gameCoinLabel;
@property (weak, nonatomic) IBOutlet UILabel *teamLabel;
@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property (weak, nonatomic) IBOutlet UIButton *practiceButton;
@property (weak, nonatomic) IBOutlet UIButton *commentButton;
@property (weak, nonatomic) IBOutlet UIImageView *bgImageView;
@property (weak, nonatomic) IBOutlet UIButton *rankButton;
@property (weak, nonatomic) IBOutlet UIButton *betButton;
@property (nonatomic) MSWeakTimer *timer;
@property (nonatomic) SldGameData *gd;
@property (nonatomic) NSMutableArray *gameCoinPrices;
@end

static __weak SldBriefController *g_briefController = nil;
static NSMutableSet *g_updatedPackIdSet = nil;

@implementation SldBriefController

+ (instancetype)getInstance {
    return g_briefController;
}

-(void)dealloc {
    [_timer invalidate];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    
    g_briefController = self;
    if (g_updatedPackIdSet == nil) {
        g_updatedPackIdSet = [NSMutableSet set];
    }
    _gd = [SldGameData getInstance];
    
    [_gd resetEvent];
    
    //timer
    _timer = [MSWeakTimer scheduledTimerWithTimeInterval:1.f target:self selector:@selector(onTimer) userInfo:nil repeats:YES dispatchQueue:dispatch_get_main_queue()];
    
    //disable all buttons
    //_playButton.enabled = _gd.eventInfo.state == RUNNING;
    _playButton.enabled = NO;
    _practiceButton.enabled = NO;
    _commentButton.enabled = NO;
    _rankButton.enabled = NO;
    _betButton.enabled = NO;
    
    
    //load pack data
    EventInfo *event = _gd.eventInfo;
    [_gd loadPack:event.packId completion:^(PackInfo *packInfo) {
        [self updatePackInfo];
    }];
    
//    EventInfo *event = _gd.eventInfo;
//    UInt64 packId = event.packId;
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
////        if (packInfo.timeUnix != event.packTimeUnix) {
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
    NSDictionary *body = @{@"EventId":@(_gd.eventInfo.id), @"UserId":@0};
    [session postToApi:@"event/getUserPlay" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
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
                _bestRecordLabel.alpha = 0.f;
            } completion:^(BOOL finished) {
                _bestRecordLabel.text = @"读取错误";
                [UIView animateWithDuration:.3f animations:^{
                    _bestRecordLabel.alpha = 1.f;
                }];
            }];
            return;
        }
        
        _gd.eventPlayRecord = [EventPlayRecored recordWithDictionary:dict];
        
        [self updatePlayRecord];
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updatePlayRecord];
}

- (void)updatePackInfo {
    [self checkAndEnableButtons];
    [self loadBackground];
    
    _titleLabel.text = _gd.packInfo.title;
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

- (void)checkAndEnableButtons {
    if (_gd.packInfo && _gd.eventPlayRecord) {
        _practiceButton.enabled = YES;
        _commentButton.enabled = YES;
        _rankButton.enabled = YES;
        _betButton.enabled = YES;
    }
    [self onTimer];
}

- (void)updatePlayRecord {
    [self checkAndEnableButtons];
    
    EventPlayRecored *record = _gd.eventPlayRecord;
    _highScoreStr = formatScore(record.highScore);
    
    if ([_bestRecordLabel.text compare:_highScoreStr] != 0) {
        [UIView animateWithDuration:.3f animations:^{
            _bestRecordLabel.alpha = 0.f;
        } completion:^(BOOL finished) {
            _bestRecordLabel.text = _highScoreStr;
            [UIView animateWithDuration:.3f animations:^{
                _bestRecordLabel.alpha = 1.f;
            }];
        }];
    }
    
    int rank = record.rank;
    int rankNum = record.rankNum;
    
    //team
    if (record.teamName.length == 0) {
        _teamLabel.text = @"未知";
    } else {
        _teamLabel.text = record.teamName;
    }
    
    //rank
    if (rank == 0) {
        _rankLabel.text = @"无名次";
    } else {
        _rankLabel.text = [NSString stringWithFormat:@"第%d名", rank];
    }
    _rankStr = [NSString stringWithFormat:@"%d", rank];
    
    //rankNum
    int beatNum = rankNum-rank;
    if (rank <= 0) {
        beatNum = 0;
    }
    float beatRate = 0.f;
    if (rankNum <= 1) {
        beatNum = 0;
    } else {
        beatRate = (float)beatNum/(float)(rankNum-1);
    }
    _rankNumLabel.text = [NSString stringWithFormat:@"%d人参赛(击败%.1f%%)", rankNum, beatRate*100];
    
    float sat1 = 0;
    float sat2 = 0.65;
    float sat = sat1 + (sat2-sat1)*beatRate;
    UIColor *color = [UIColor colorWithHue:136.f/360.f saturation:sat brightness:1.f alpha:1.f];
    _rankLabel.textColor = color;
    
    //game coin
    _gameCoinLabel.text = [NSString stringWithFormat:@"游戏币: %d", record.gameCoinNum];
}


- (void)onTimer {
    enum EventState state = [_gd.eventInfo updateState];
    
    if (state == CLOSED) {
        _timeRemainLabel.text = @"比赛已结束";
        _playButton.enabled = NO;
        [_playButton setTitle:@"已结束" forState:UIControlStateNormal|UIControlStateDisabled];
    } else if (state == COMMING) {
        NSTimeInterval beginIntv = [_gd.eventInfo.beginTime timeIntervalSinceNow];
        NSString *str = formatInterval((int)beginIntv);
        _timeRemainLabel.text = [NSString stringWithFormat:@"距离开始%@", str];
        _playButton.enabled = NO;
        [_playButton setTitle:@"未开始" forState:UIControlStateNormal|UIControlStateDisabled];
    } else if (state == RUNNING) {
        NSTimeInterval endIntv = [_gd.eventInfo.endTime timeIntervalSinceNow];
        NSString *str = formatInterval((int)endIntv);
        
        _timeRemainLabel.text = [NSString stringWithFormat:@"比赛剩余%@", str];
        if (_gd.packInfo) {
            _playButton.enabled = YES;
        } else {
            _playButton.enabled = NO;
        }
        [_playButton setTitle:@"开始" forState:UIControlStateNormal|UIControlStateDisabled];
    }
}

#pragma mark - Button callback

- (IBAction)onClickMatch:(id)sender {
    _gd.gameMode = MATCH;
    
    [self loadPacks];
}

- (IBAction)onClickParactice:(id)sender {
    _gd.gameMode = PRACTICE;
    [self loadPacks];
}

- (void)loadPacks {
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
        if (_gd.gameMode == MATCH) {
            [self checkGameCoin];
        } else if (_gd.gameMode == PRACTICE) {
            [self enterGame];
        }
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
                        if (_gd.gameMode == MATCH) {
                            [self checkGameCoin];
                        } else if (_gd.gameMode == PRACTICE) {
                            [self enterGame];
                        }
                    }
                }];
            }
        }
    }
}

- (void)checkGameCoin {
    if (_gd.eventPlayRecord.gameCoinNum == 0) {
        SldHttpSession *session = [SldHttpSession defaultSession];
        self.view.userInteractionEnabled = NO;
        [session postToApi:@"store/listGameCoinPack" body:nil completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            self.view.userInteractionEnabled = YES;
            if (error) {
                alertHTTPError(error, data);
            } else {
                NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                if (error) {
                    alert(@"Json error", [error localizedDescription]);
                    return;
                }
                NSArray *gameCoinPacks = [dict objectForKey:@"GameCoinPacks"];
                
                _gameCoinPrices = [NSMutableArray array];
                NSMutableArray *strings = [NSMutableArray array];
                for (NSDictionary *pack in gameCoinPacks) {
                    int price = [(NSNumber*)[pack objectForKey:@"Price"] intValue];
                    int coinNum = [(NSNumber*)[pack objectForKey:@"CoinNum"] intValue];
                    NSString *str = [NSString stringWithFormat:@"%d金币 购买 %d个游戏币", price, coinNum];
                    [strings addObject:str];
                    [_gameCoinPrices addObject:@(price)];
                }
                
                //
                SldGameCoinBuyController* vc = (SldGameCoinBuyController*)[getStoryboard() instantiateViewControllerWithIdentifier:@"buyGameCoin"];
                vc.strings = strings;
                [self addChildViewController:vc];
                [self.view addSubview:vc.view];
                vc.view.alpha = 0.f;
                [UIView animateWithDuration:.3f animations:^{
                    vc.view.alpha = 1.f;
                }];
            }
        }];
    } else {
        RIButtonItem *cancelItem = [RIButtonItem itemWithLabel:@"否" action:^{
        }];
        
        RIButtonItem *okItem = [RIButtonItem itemWithLabel:@"是" action:^{
            [self enterGame];
        }];
        
        NSString *title = [NSString stringWithFormat:@"花费一个游戏币开始比赛?\n(现有%d个游戏币)", _gd.eventPlayRecord.gameCoinNum];
        [[[UIAlertView alloc] initWithTitle:title
                                    message:nil
                           cancelButtonItem:cancelItem
                           otherButtonItems:okItem, nil] show];
    }
}

- (void)alertView:(UIAlertView *)alertView didDismissWithButtonIndex:(NSInteger)buttonIndex {
    [[SldHttpSession defaultSession] cancelAllTask];
}

- (void)enterGame {
    if (_gd.gameMode == MATCH) {
        SldHttpSession *session = [SldHttpSession defaultSession];
        NSDictionary *body = @{@"EventId":@(_gd.eventInfo.id)};
        self.view.userInteractionEnabled = NO;
        [session postToApi:@"event/playBegin" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            self.view.userInteractionEnabled = YES;
            if (error) {
                NSString *errType = getServerErrorType(data);
                if ([errType compare:@"err_game_coin"] == 0) {
                    alertHTTPError(error, data);
                } else {
                    alertHTTPError(error, data);
                }
                return;
            } else {
                NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                if (error) {
                    alert(@"Json error", [error localizedDescription]);
                    return;
                }
                NSString *matchSecret = [dict objectForKey:@"Secret"];
                
                //
                SldGameController *controller = [self.storyboard instantiateViewControllerWithIdentifier:@"game"];
                controller.matchSecret = matchSecret;
                [self.navigationController pushViewController:controller animated:YES];
                
                //
                _gd.eventPlayRecord.gameCoinNum = [(NSNumber*)[dict objectForKey:@"GameCoinNum"] intValue];
                _gameCoinLabel.text = [NSString stringWithFormat:@"游戏币: %d", _gd.eventPlayRecord.gameCoinNum];
            }
        }];
    } else if (_gd.gameMode == PRACTICE) {
        SldGameController *controller = [self.storyboard instantiateViewControllerWithIdentifier:@"game"];
        [self.navigationController pushViewController:controller animated:YES];
    }
    //update db
    FMDatabase *db = [SldDb defaultDb].fmdb;
    BOOL ok = [db executeUpdate:@"UPDATE event SET packDownloaded=1 WHERE id=?", @(_gd.eventInfo.id)];
    if (!ok) {
        lwError("Sql error:%@", [db lastErrorMessage]);
        return;
    }
}

- (void)onBuyGameCoinWithPackId:(NSInteger)packId {
    if (packId < _gameCoinPrices.count) {
        int price = [(NSNumber*)_gameCoinPrices[packId] intValue];
        if (_gd.playerInfo.money < price) {
            alert(@"买不起😱", nil);
            return;
        }
    }
    
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"EventId":@(_gd.eventInfo.id), @"GameCoinPackId":@(packId)};
    [session postToApi:@"store/buyGameCoin" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        _gd.playerInfo.money = [(NSNumber*)[dict objectForKey:@"Money"] intValue];
        int gameCoinNum = [(NSNumber*)[dict objectForKey:@"GameCoinNum"] intValue];
        _gameCoinLabel.text = [NSString stringWithFormat:@"游戏币: %d", gameCoinNum];
        
        _gd.eventPlayRecord.gameCoinNum = gameCoinNum;
        if (gameCoinNum > 0) {
            [self onClickMatch:nil];
        }
    }];
}

- (IBAction)onSocial:(id)sender {
    SldHttpSession *session = [SldHttpSession defaultSession];
    int msec = 0;
    if (_gd.eventPlayRecord) {
        msec = -_gd.eventPlayRecord.highScore;
    }
    
    UIAlertView* alt = alertNoButton(@"正在生成我的比赛...");
    NSDictionary *body = @{@"PackId":@(_gd.eventInfo.packId), @"SliderNum":@(_gd.eventInfo.sliderNum), @"Msec":@(msec)};
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
        NSString *path = makeImagePath(_gd.packInfo.thumb);
        UIImage *image = [UIImage imageWithContentsOfFile:path];
        NSString *url = [NSString stringWithFormat:@"%@?key=%@", [SldConfig getInstance].HTML5_URL, key];
        
        [[[UIAlertView alloc] initWithTitle:@"邀请朋友一起玩。朋友可以直接点开链接挑战，也可以下载客户端一起玩。"
                                    message:nil
                           cancelButtonItem:[RIButtonItem itemWithLabel:@"不了" action:^{
            // Handle "Cancel"
        }]
                           otherButtonItems:[RIButtonItem itemWithLabel:@"好的" action:^{
            NSString *text = [NSString stringWithFormat:@"我创建了一场比赛，敢来挑战么？"];
            if (_gd.eventPlayRecord && _gd.eventPlayRecord.highScore != 0) {
                text = [NSString stringWithFormat:@"我只用了%@就完成了比赛，敢来挑战么？", formatScore(_gd.eventPlayRecord.highScore)];
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

-(void)didFinishGetUMSocialDataInViewController:(UMSocialResponseEntity *)response
{
//    //根据`responseCode`得到发送结果,如果分享成功
//    if(response.responseCode == UMSResponseCodeSuccess)
//    {
//        //得到分享到的微博平台名
//        NSLog(@"share to sns name is %@",[[response.data allKeys] objectAtIndex:0]);
//    }
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

@interface SldGameCoinBuyController ()
@property (weak, nonatomic) IBOutlet UIPickerView *pickerView;

@property (weak, nonatomic) IBOutlet UILabel *moneyLabel;

@end

@implementation SldGameCoinBuyController

- (void)viewDidLoad {
    _pickerView.delegate = self;
    _pickerView.dataSource = self;
    SldGameData *gd = [SldGameData getInstance];
    _moneyLabel.text = [NSString stringWithFormat:@"我的铜币：%lld", gd.playerInfo.money];
}

- (IBAction)onCancel:(id)sender {
    [UIView animateWithDuration:.3f animations:^{
        self.view.alpha = 0.f;
    } completion:^(BOOL finished) {
        [self.view removeFromSuperview];
        [self removeFromParentViewController];
    }];
}

- (IBAction)onBuy:(id)sender {
    [UIView animateWithDuration:.3f animations:^{
        self.view.alpha = 0.f;
    } completion:^(BOOL finished) {
        [self.view removeFromSuperview];
        [self removeFromParentViewController];
    }];
    
    SldBriefController *parentVc = (SldBriefController*)self.parentViewController;
    [parentVc onBuyGameCoinWithPackId:[_pickerView selectedRowInComponent:0]];
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

// returns the # of rows in each component..
- (NSInteger)pickerView:(UIPickerView *)pickerView numberOfRowsInComponent:(NSInteger)component {
    return _strings.count;
}


- (NSString *)pickerView:(UIPickerView *)pickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return _strings[row];
}

@end






