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
#import "SldMatchPrepareController.h"
#import "SldUtil.h"
#import "config.h"
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
@property (nonatomic) MSWeakTimer *timer;
@property (nonatomic) SldGameData *gamedata;
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
    _gamedata = [SldGameData getInstance];
    
    //timer
    _timer = [MSWeakTimer scheduledTimerWithTimeInterval:1.f target:self selector:@selector(onTimer) userInfo:nil repeats:YES dispatchQueue:dispatch_get_main_queue()];
    
    self.view.backgroundColor = [UIColor clearColor];
    
    _playButton.enabled = _gamedata.eventInfo.state == RUNNING;
    _titleLabel.text = _gamedata.packInfo.title;
}

- (void)viewDidAppear:(BOOL)animated {
    [self updatePlayRecordWithHighscore];
}

- (void)updatePlayRecordWithHighscore {
    EventPlayRecored *record = _gamedata.eventPlayRecord;
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
    enum EventState state = [_gamedata.eventInfo updateState];
    
    if (state == CLOSED) {
        _timeRemainLabel.text = @"比赛已结束";
        _playButton.enabled = NO;
    } else if (state == COMMING) {
        NSTimeInterval beginIntv = [_gamedata.eventInfo.beginTime timeIntervalSinceNow];
        NSString *str = formatInterval((int)beginIntv);
        _timeRemainLabel.text = [NSString stringWithFormat:@"距离开始%@", str];
        _playButton.enabled = NO;
    } else if (state == RUNNING) {
        NSTimeInterval endIntv = [_gamedata.eventInfo.endTime timeIntervalSinceNow];
        NSString *str = formatInterval((int)endIntv);
        
        _timeRemainLabel.text = [NSString stringWithFormat:@"比赛剩余%@", str];
        if (_gamedata.packInfo) {
            _playButton.enabled = YES;
        } else {
            _playButton.enabled = NO;
        }
    }
}

- (void)reloadData {
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

- (IBAction)onClickMatch:(id)sender {
    _gamedata.gameMode = MATCH;
    
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
        [self checkGameCoin];
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
                        [self checkGameCoin];
                    }
                }];
            }
        }
    }
}

- (void)checkGameCoin {
    if (_gamedata.eventPlayRecord.gameCoinNum == 0) {
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
        
        NSString *title = [NSString stringWithFormat:@"花费一个游戏币开始比赛?\n(现有%d个游戏币)", _gamedata.eventPlayRecord.gameCoinNum];
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
    if (_gamedata.gameMode == MATCH) {
        SldHttpSession *session = [SldHttpSession defaultSession];
        NSDictionary *body = @{@"EventId":@(_gamedata.eventInfo.id)};
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
                _gamedata.eventPlayRecord.gameCoinNum = [(NSNumber*)[dict objectForKey:@"GameCoinNum"] intValue];
                _gameCoinLabel.text = [NSString stringWithFormat:@"游戏币: %d", _gamedata.eventPlayRecord.gameCoinNum];
            }
        }];
    }
    //update db
    FMDatabase *db = [SldDb defaultDb].fmdb;
    BOOL ok = [db executeUpdate:@"UPDATE event SET packDownloaded=1 WHERE id=?", @(_gamedata.eventInfo.id)];
    if (!ok) {
        lwError("Sql error:%@", [db lastErrorMessage]);
        return;
    }
}

- (void)onBuyGameCoinWithPackId:(NSInteger)packId {
    if (packId < _gameCoinPrices.count) {
        int price = [(NSNumber*)_gameCoinPrices[packId] intValue];
        if (_gamedata.money < price) {
            alert(@"买不起😱", nil);
            return;
        }
    }
    
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"EventId":@(_gamedata.eventInfo.id), @"GameCoinPackId":@(packId)};
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
        _gamedata.money = [(NSNumber*)[dict objectForKey:@"Money"] intValue];
        int gameCoinNum = [(NSNumber*)[dict objectForKey:@"GameCoinNum"] intValue];
        _gameCoinLabel.text = [NSString stringWithFormat:@"游戏币: %d", gameCoinNum];
        
        _gamedata.eventPlayRecord.gameCoinNum = gameCoinNum;
        if (gameCoinNum > 0) {
            [self onClickMatch:nil];
        }
    }];
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
    _moneyLabel.text = [NSString stringWithFormat:@"我的铜币：%lld", gd.money];
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






