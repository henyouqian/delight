//
//  SldEventListViewController.m
//  Sld
//
//  Created by Wei Li on 14-4-18.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldEventListViewController.h"
#import "SldHttpSession.h"
//#import "SldEventDetailViewController.h"
#import "SldGameData.h"
#import "SldUtil.h"
#import "config.h"
#import "SldStreamPlayer.h"
#import "SldDb.h"
#import "UIImageView+sldAsyncLoad.h"
#import "MSWeakTimer.h"

NSString *CELL_ID = @"cellID";
static const int FETCH_EVENT_COUNT = 20;

@interface EventCell()
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
//@property (weak, nonatomic) IBOutlet UIView *highlight;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UILabel *dateLabel;

@end

@implementation EventCell

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
    }
    return self;
}
//
//- (void)setHighlighted:(BOOL)highlighted {
//    [self.highlight setHidden:!highlighted];
//}

@end


//
@interface SldCollectionView : UICollectionView
@end

@implementation SldCollectionView

- (void)setContentInset:(UIEdgeInsets)contentInset {
    if (self.tracking) {
        CGFloat diff = contentInset.top - self.contentInset.top;
        CGPoint translation = [self.panGestureRecognizer translationInView:self];
        translation.y -= diff * 3.0 / 2.0;
        [self.panGestureRecognizer setTranslation:translation inView:self];
    }
    [super setContentInset:contentInset];
}

@end

@interface EventListFooterView()
@property (weak, nonatomic) IBOutlet UILabel *label;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spinner;

@end

@implementation EventListFooterView

@end


@interface SldEventListViewController ()
@property (weak, nonatomic) IBOutlet SldCollectionView *collectionView;
@property (weak, nonatomic) IBOutlet UIButton *rewardButton;
@property (nonatomic) UIRefreshControl *refreshControl;
@property (nonatomic) UIImage *loadingImage;
@property (nonatomic) SldGameData *gameData;
@property (weak, nonatomic) EventListFooterView *footerView;
@property (nonatomic) SInt64 fetchStartId;
@property (nonatomic) BOOL bottomFetched;
@property (nonatomic) BOOL appendable;
@property (nonatomic) BOOL reachBottom;
@property (nonatomic) MSWeakTimer *timer;
@property (nonatomic) MSWeakTimer *checkNewTimer;
@end

@implementation SldEventListViewController

-(void)dealloc {
    [_timer invalidate];
    [_checkNewTimer invalidate];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _gameData = [SldGameData getInstance];
    _fetchStartId = -1;
    _bottomFetched = NO;
    _appendable = YES;
    _reachBottom = NO;
    
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
    
    _footerView.hidden = YES;
    
    [_gameData.eventInfos removeAllObjects];

    
    //refresh control
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.collectionView.alwaysBounceVertical = YES;
    [self.collectionView addSubview:self.refreshControl];
    [self.refreshControl addTarget:self action:@selector(refershControlAction) forControlEvents:UIControlEventValueChanged];
    
    //
    _loadingImage = [UIImage imageNamed:@"ui/loading.png"];
    
    //timer
    _timer = [MSWeakTimer scheduledTimerWithTimeInterval:1.f target:self selector:@selector(onTimer) userInfo:nil repeats:YES dispatchQueue:dispatch_get_main_queue()];
    
    _checkNewTimer = [MSWeakTimer scheduledTimerWithTimeInterval:60 target:self selector:@selector(onCheckNewTimer) userInfo:nil repeats:YES dispatchQueue:dispatch_get_main_queue()];
    
    //
}

- (void)onTimer {
    int eventNum = [_gameData.eventInfos count];
    NSMutableArray *reloadIndexPathes = [NSMutableArray array];
    if (eventNum > 0) {
        for (int i = 0; i < eventNum; ++i) {
            EventInfo *eventInfo = _gameData.eventInfos[i];
            if (eventInfo.state == CLOSED) {
                continue;
            }
            
            enum EventState prevState = eventInfo.state;
            [eventInfo updateState];
            
            if (prevState != eventInfo.state) {
                if (prevState != UNDEFINED) {
                    [reloadIndexPathes addObject:[NSIndexPath indexPathForRow:i inSection:0]];
                }
            }
        }
        if (reloadIndexPathes.count) {
            [self.collectionView reloadItemsAtIndexPaths:reloadIndexPathes];
        }
    }
//    NSTimeInterval endIntv = [_gamedata.eventInfo.endTime timeIntervalSinceNow];
//    if (endIntv < 0 || _gamedata.eventInfo.hasResult) {
//        _timeRemainLabel.text = @"活动已结束";
//        _matchButton.enabled = NO;
//    } else {
//        NSTimeInterval beginIntv = [_gamedata.eventInfo.beginTime timeIntervalSinceNow];
//        if (beginIntv > 0) {
//            int sec = (int)beginIntv;
//            int hour = sec / 3600;
//            int minute = (sec % 3600)/60;
//            sec = (sec % 60);
//            _timeRemainLabel.text = [NSString stringWithFormat:@"距离开始%02d:%02d:%02d", hour, minute, sec];
//            _matchButton.enabled = NO;
//        } else {
//            int sec = (int)endIntv;
//            int hour = sec / 3600;
//            int minute = (sec % 3600)/60;
//            sec = (sec % 60);
//            _timeRemainLabel.text = [NSString stringWithFormat:@"活动剩余%02d:%02d:%02d", hour, minute, sec];
//            if (!_hasNetError && _gamedata.packInfo) {
//                _matchButton.enabled = YES;
//            } else {
//                _matchButton.enabled = NO;
//            }
//        }
//    }
}

- (void)checkRewardButton {
    if (_gameData.playerInfo.rewardCache > 0) {
        [_rewardButton setTitle:[NSString stringWithFormat:@"可领取奖金%lld", _gameData.playerInfo.rewardCache] forState:UIControlStateNormal];
        _rewardButton.hidden = NO;
        CGRect frame = _rewardButton.frame;
        frame.origin.y = 0;
        _rewardButton.frame = frame;
        [UIView animateWithDuration:.5 delay:0.5 usingSpringWithDamping:.4 initialSpringVelocity:0.5 options:UIViewAnimationOptionCurveLinear animations:^
         {
             CGRect frame = _rewardButton.frame;
             frame.origin.y = 64;
             _rewardButton.frame = frame;
         } completion:nil];
    } else {
        _rewardButton.hidden = YES;
    }
}

- (void)onCheckNewTimer {
    if (_gameData.eventInfos && _gameData.eventInfos.count > 0) {
        SldHttpSession *session = [SldHttpSession defaultSession];
        [session postToApi:@"event/checkNew" body:nil completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                alertHTTPError(error, data);
                return;
            }
            
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error) {
                lwError("Json error:%@", [error localizedDescription]);
                return;
            }
            
            int eventId = [(NSNumber*)[dict objectForKey:@"EventId"] intValue];
            int rewardCache = [(NSNumber*)[dict objectForKey:@"RewardCache"] intValue];
            
            EventInfo *eventInfo = _gameData.eventInfos.firstObject;
            if (eventId != eventInfo.id) {
                UILabel *label = [[UILabel alloc] initWithFrame:CGRectZero];
                label.textColor = [_rewardButton.backgroundColor colorWithAlphaComponent:1.0];
                label.text = @"有新赛事，请下拉更新";
                [label sizeToFit];
                self.navigationItem.titleView = label;
            }
            
            _gameData.playerInfo.rewardCache = rewardCache;
            [self checkRewardButton];
        }];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    
    if ([_gameData.eventInfos count] == 0) {
        [self refreshList];
    } else if (_gameData.needReloadEventList){
        [self.collectionView reloadData];
    }
     _gameData.needReloadEventList = NO;
    
    [self checkRewardButton];
    
    [self.collectionView reloadData];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)refershControlAction {
    [self refreshList];
}

- (void)refreshList {
    FMDatabase *db = [SldDb defaultDb].fmdb;
    NSMutableArray *insertIndexPaths = [NSMutableArray arrayWithCapacity:20];
    
    //online
    if (_gameData.online) {
        if (_fetchStartId == 0) {
            return;
        }
        _fetchStartId = 0;
        NSDictionary *body = @{@"StartId":@0, @"Limit":@(FETCH_EVENT_COUNT)};
        SldHttpSession *session = [SldHttpSession defaultSession];
        
        [session postToApi:@"event/list" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
         {
             self.navigationItem.titleView = nil;
             _fetchStartId = -1;
             [self.refreshControl endRefreshing];
             
             if (error) {
                 alertHTTPError(error, data);
                 return;
             }
             NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
             if (error) {
                 lwError("Json error, error=%@", [error localizedDescription]);
                 return;
             }
             if (array.count == 0) {
                 return;
             }
             
             EventInfo *oldTopEvent = nil;
             if ([_gameData.eventInfos count]) {
                 oldTopEvent = _gameData.eventInfos[0];
             }
             
             EventInfo *newBottomEvent = [EventInfo eventWithDictionary:array.lastObject];
             BOOL refreshAll = NO;
             if (newBottomEvent && oldTopEvent) {
                 if (newBottomEvent.id > oldTopEvent.id) {
                     [_gameData.eventInfos removeAllObjects];
                 }
             }
             
             if (_gameData.eventInfos.count == 0) {
                 refreshAll = YES;
             }
             
             for (int i = 0; i < [array count]; ++i) {
                 NSDictionary *dict = array[i];
                 EventInfo *event = [EventInfo eventWithDictionary:dict];
                 
                 if (oldTopEvent && oldTopEvent.id >= event.id) {
                     for (__strong EventInfo *oldEvent in _gameData.eventInfos) {
                         if (event.id == oldEvent.id) {
                             oldEvent = event;
                             refreshAll = YES;
                         }
                     }
                 } else {
                     [_gameData.eventInfos insertObject:event atIndex:i];
                     [insertIndexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
                 }
                 
                 NSData *eventData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
                 if (error) {
                     lwError("Json error, error=%@", [error localizedDescription]);
                     return;
                 }
                 
                 //save to db
                 FMResultSet *rs = [db executeQuery:@"SELECT packDownloaded FROM event WHERE id=?", dict[@"Id"]];
                 BOOL packDownloaded = NO;
                 if ([rs next]) {
                     packDownloaded = [rs boolForColumnIndex:0];
                 }
                 
                 BOOL ok = [db executeUpdate:@"REPLACE INTO event (id, data, packDownloaded) VALUES(?, ?, ?)", dict[@"Id"], eventData, @(packDownloaded)];
                 if (!ok) {
                     lwError("Sql error:%@", [db lastErrorMessage]);
                 }
             }
             
             if (refreshAll) {
                 [self.collectionView reloadData];
             } else if (insertIndexPaths.count) {
                 [self.collectionView insertItemsAtIndexPaths:insertIndexPaths];
             }
             
         }];
    }
    
//    //offline
//    else {
//        [self.refreshControl endRefreshing];
//        FMResultSet *rs = [db executeQuery:@"SELECT data FROM event ORDER BY id DESC LIMIT ? OFFSET 0", @(FETCH_EVENT_COUNT)];
//        int i = 0;
//        while ([rs next]) {
//            NSString *data = [rs stringForColumnIndex:0];
//            NSError *error = nil;
//            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:[data dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
//            if (error) {
//                lwError("Json error:%@", [error localizedDescription]);
//                return;
//            }
//            
//            EventInfo *event = [EventInfo eventWithDictionary:dict];
//            [_gameData.eventInfos insertObject:event atIndex:i];
//            [insertIndexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
//            i++;
//        }
//    }
}



- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [_gameData.eventInfos count];
}


// The cell that is returned must be retrieved from a call to -dequeueReusableCellWithReuseIdentifier:forIndexPath:
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    __weak EventCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:CELL_ID forIndexPath:indexPath];
    
    //
    NSInteger idx = indexPath.row;
    if (idx >= [_gameData.eventInfos count]) {
        lwError("Out of range.");
        return cell;
    }
    EventInfo *event = [_gameData.eventInfos objectAtIndex:idx];
    
    cell.imageView.image = _loadingImage;
    [cell.imageView asyncLoadImageWithKey:event.thumb showIndicator:NO completion:nil];
    
    //check finished
    NSDate *now = getServerNow();
    if (event.hasResult || [now compare:event.endTime] == NSOrderedDescending) {
        [cell.statusLabel setHidden:NO];
        cell.statusLabel.text = @"已结束";
        cell.statusLabel.backgroundColor = makeUIColor(60, 60, 60, 180);
    } else if ([event.beginTime compare:now] == NSOrderedAscending && [now compare:event.endTime] == NSOrderedAscending) {
        [cell.statusLabel setHidden:NO];
        cell.statusLabel.text = @"进行中";
        //cell.statusLabel.backgroundColor = makeUIColor(91, 212, 62, 180);
        cell.statusLabel.backgroundColor = makeUIColor(71, 186, 43, 180);
    } else if ([now compare:event.beginTime] == NSOrderedAscending) {
        [cell.statusLabel setHidden:NO];
        cell.statusLabel.text = @"即将开始";
        cell.statusLabel.backgroundColor = makeUIColor(212, 62, 91, 180);
    }
    
    //date label
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    NSLocale *usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    [dateFormatter setLocale:usLocale];
    NSString *strDate = [dateFormatter stringFromDate:event.beginTime];
    NSArray *comps = [strDate componentsSeparatedByString:@","];
    cell.dateLabel.text = [comps objectAtIndex:0];
    
    return cell;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (_gameData.eventInfos.count == 0) {
        return;
    }
    
    if ((scrollView.contentOffset.y + scrollView.frame.size.height + _footerView.frame.size.height) >= scrollView.contentSize.height) {
        EventInfo *lastEventInfo = _gameData.eventInfos.lastObject;
        if (_fetchStartId == lastEventInfo.id || !_appendable || _reachBottom) {
            return;
        }
        _footerView.hidden = NO;
        _fetchStartId = lastEventInfo.id;
        
        NSDictionary *body = @{@"StartId":@(lastEventInfo.id), @"Limit":@(FETCH_EVENT_COUNT)};
        SldHttpSession *session = [SldHttpSession defaultSession];
        _appendable = NO;
        [session postToApi:@"event/list" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
         {
             void(^onReachBottom)() = ^(){
                 _reachBottom = YES;
                 [_footerView.spinner stopAnimating];
                 _footerView.spinner.hidden = YES;
                 _footerView.label.text = @"后面没有了";
             };
             _fetchStartId = -1;
             if (error) {
                 NSString *errType = getServerErrorType(data);
                 if ([errType compare:@"err_not_found"] == 0) {
                     onReachBottom();
                 } else {
                     alertHTTPError(error, data);
                 }
                 return;
             }
             NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
             if (error) {
                 alert([NSString stringWithFormat:@"Json error, error=%@", [error localizedDescription]], nil);
                 return;
             }
             if (array.count < FETCH_EVENT_COUNT) {
                 onReachBottom();
             }
             
             FMDatabase *db = [SldDb defaultDb].fmdb;
             NSMutableArray *insertIndexPaths = [NSMutableArray arrayWithCapacity:20];
             
             for (int i = 0; i < [array count]; ++i) {
                 NSDictionary *dict = array[i];
                 EventInfo *event = [EventInfo eventWithDictionary:dict];
    
                 [insertIndexPaths addObject:[NSIndexPath indexPathForRow:_gameData.eventInfos.count inSection:0]];
                 [_gameData.eventInfos addObject:event];
                 
                 //save to db
                 NSData *eventData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
                 if (error) {
                     lwError("Json error, error=%@", [error localizedDescription]);
                     return;
                 }
                 FMResultSet *rs = [db executeQuery:@"SELECT packDownloaded FROM event WHERE id=?", dict[@"Id"]];
                 
                 BOOL packDownloaded = NO;
                 if ([rs next]) {
                     packDownloaded = [rs boolForColumnIndex:0];
                 }
                 
                 BOOL ok = [db executeUpdate:@"REPLACE INTO event (id, data, packDownloaded) VALUES(?, ?, ?)", dict[@"Id"], eventData, @(packDownloaded)];
                 if (!ok) {
                     lwError("Sql error:%@", [db lastErrorMessage]);
                 }
             }
             
             if (insertIndexPaths.count) {
                 [self.collectionView insertItemsAtIndexPaths:insertIndexPaths];
             }
         }];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    _appendable = YES;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    if (kind == UICollectionElementKindSectionFooter) {
        _footerView = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"eventListFooter" forIndexPath:indexPath];
        
        return _footerView;
    }
//    } else {
//        UICollectionReusableView *view = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"eventListHeader" forIndexPath:indexPath];
//        return view;
//    }
    
    return nil;
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if (segue.identifier && [segue.identifier compare:@"matchBriefSeg"] == 0) {
        UIButton *button = sender;
        UICollectionViewCell *cell = (UICollectionViewCell*)button.superview.superview;
        NSIndexPath *indexPath = [self.collectionView indexPathForCell:cell];
        if (indexPath.row < [_gameData.eventInfos count]) {
            _gameData.eventInfo = [_gameData.eventInfos objectAtIndex:indexPath.row];
        }
    }
}

@end

























