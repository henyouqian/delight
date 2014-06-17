//
//  SldEventMenuController.m
//  Sld
//
//  Created by 李炜 on 14-6-10.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldEventMenuController.h"
#import "SldGameData.h"
#import "SldDb.h"
#import "SldHttpSession.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldOfflineEventEnterControler.h"
#import "MSWeakTimer.h"

@interface SldEventMenuController ()
@property (weak, nonatomic) IBOutlet UIImageView *bgImageView;
@property (weak, nonatomic) IBOutlet UIButton *matchButton;
@property (weak, nonatomic) IBOutlet UIButton *challangeButton;
@property (weak, nonatomic) IBOutlet UILabel *timeRemainLabel;
@property (nonatomic) SldGameData *gd;
@property (nonatomic) MSWeakTimer *timer;
@end

static NSMutableSet *g_updatedPackIdSet = nil;

@implementation SldEventMenuController


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _gd = [SldGameData getInstance];
    [_gd resetEvent];
    
    _matchButton.enabled = NO;
    _challangeButton.enabled = NO;
    
    //load pack data
    UInt64 packId = _gd.eventInfo.packId;
    FMDatabase *db = [SldDb defaultDb].fmdb;
    FMResultSet *rs = [db executeQuery:@"SELECT data FROM pack WHERE id = ?", [NSNumber numberWithUnsignedLongLong:packId]];
    SldHttpSession *session = [SldHttpSession defaultSession];
    if ([rs next]) { //local
        NSString *data = [rs stringForColumnIndex:0];
        NSError *error = nil;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:[data dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        _gd.packInfo = [PackInfo packWithDictionary:dict];
        
        [self loadBackground];
//        [self reloadData];
    }
    
    if (![g_updatedPackIdSet containsObject:@(packId)]) { //server
        NSDictionary *body = @{@"Id":@(packId)};
        [session postToApi:@"pack/get" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                alertHTTPError(error, data);
                return;
            }
            
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error) {
                lwError("Json error:%@", [error localizedDescription]);
                return;
            }
            _gd.packInfo = [PackInfo packWithDictionary:dict];
            
            //save to db
            BOOL ok = [db executeUpdate:@"REPLACE INTO pack (id, data) VALUES(?, ?)", dict[@"Id"], data];
            if (!ok) {
                lwError("Sql error:%@", [db lastErrorMessage]);
                return;
            }
            
            [self loadBackground];
//            [self reloadData];
            [g_updatedPackIdSet addObject:@(packId)];
            
            [self onTimer];
        }];
    }
    
    //get play result
    NSDictionary *body = @{@"EventId":@(_gd.eventInfo.id), @"UserId":@0};
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
        
        _gd.eventPlayRecord = [EventPlayRecored recordWithDictionary:dict];
        
    }];
    
    //timer
    _timer = [MSWeakTimer scheduledTimerWithTimeInterval:1.f target:self selector:@selector(onTimer) userInfo:nil repeats:YES dispatchQueue:dispatch_get_main_queue()];
    
    [self onTimer];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)loadBackground{
    NSString *bgKey = [SldGameData getInstance].packInfo.coverBlur;
    
    BOOL imageExistLocal = imageExist(bgKey);
    NSString* localPath = makeImagePath(bgKey);
    if (imageExistLocal) {
        _bgImageView.image = [UIImage imageWithContentsOfFile:localPath];
    } else {
        [_bgImageView asyncLoadImageWithKey:bgKey showIndicator:NO completion:^{
            _bgImageView.alpha = 0.0;
            [UIView animateWithDuration:1.f animations:^{
                _bgImageView.alpha = 1.0;
            }];
        }];
    }
}

- (void)onTimer {
    if (!_gd.packInfo || !_gd.eventPlayRecord) {
        _matchButton.enabled = NO;
        _challangeButton.enabled = NO;
        return;
    }
    
    enum EventState state = [_gd.eventInfo updateState];
    
    if (state == CLOSED) {
        _matchButton.enabled = YES;
        [_matchButton setTitle:@"已结束" forState:UIControlStateNormal];
        _challangeButton.enabled = YES;
        _timeRemainLabel.hidden = YES;
    } else if (state == COMMING) {
        NSTimeInterval beginIntv = [_gd.eventInfo.beginTime timeIntervalSinceNow];
        NSString *str = formatInterval((int)beginIntv);
        
        _matchButton.enabled = NO;
        _challangeButton.enabled = NO;
        
        _timeRemainLabel.hidden = NO;
        _timeRemainLabel.text = [NSString stringWithFormat:@"距离比赛开始%@", str];
    } else if (state == RUNNING) {
        NSTimeInterval endIntv = [_gd.eventInfo.endTime timeIntervalSinceNow];
        NSString *str = formatInterval((int)endIntv);
        
        _timeRemainLabel.text = [NSString stringWithFormat:@"比赛剩余%@", str];
        _matchButton.enabled = YES;
        _challangeButton.enabled = YES;
        _timeRemainLabel.hidden = NO;
    }
}

- (IBAction)onMatchButton:(id)sender {
    _gd.gameMode = MATCH;
}

- (IBAction)onChallangeButton:(id)sender {
    _gd.gameMode = CHALLANGE;
    SldOfflineEventEnterControler *controller = [self.storyboard instantiateViewControllerWithIdentifier:@"offlineEnter"];
    [self.navigationController pushViewController:controller animated:YES];
}

@end
