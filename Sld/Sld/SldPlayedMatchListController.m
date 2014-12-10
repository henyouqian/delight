//
//  SldPlayedMatchListController.m
//  pin
//
//  Created by 李炜 on 14-8-16.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldPlayedMatchListController.h"
#import "SldMatchListController.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldUtil.h"
#import "SldGameData.h"
#import "SldHttpSession.h"
#import "UIImage+ImageEffects.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldMyMatchController.h"
#import "SldConfig.h"
#import "CBStoreHouseRefreshControl.h"

//=============================
@interface SldPlayedMatchListController()

@property (nonatomic) NSMutableArray *matches;
@property (nonatomic) SldMatchListFooter *footer;
@property (nonatomic) UIRefreshControl *refreshControl;
@property (nonatomic) MSWeakTimer *secTimer;
@property (nonatomic) SldGameData *gd;
@property (nonatomic) SInt64 lastPlayedTime;
@property (nonatomic) BOOL refreshOnce;
@property (nonatomic) CBStoreHouseRefreshControl *storeHouseRefreshControl;

@end

@implementation SldPlayedMatchListController

static SldPlayedMatchListController* _inst = nil;

+ (instancetype)getInst {
    return _inst;
}

- (void)dealloc {
    [_secTimer invalidate];
    _inst = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _inst = self;
    _matches = [NSMutableArray array];
    _gd = [SldGameData getInstance];
    _refreshOnce = NO;
    
    //refresh control
//    self.refreshControl = [[UIRefreshControl alloc] init];
//    self.collectionView.alwaysBounceVertical = YES;
//    [self.collectionView addSubview:self.refreshControl];
//    [self.refreshControl addTarget:self action:@selector(refreshMatch) forControlEvents:UIControlEventValueChanged];
    
    self.collectionView.alwaysBounceVertical = YES;
    self.storeHouseRefreshControl = [CBStoreHouseRefreshControl attachToScrollView:self.collectionView target:self refreshAction:@selector(refreshMatch) plist:@"storehouse"];
    
    //
    _gd.needRefreshPlayedList = NO;
    
    //timer
    _secTimer = [MSWeakTimer scheduledTimerWithTimeInterval:1.f target:self selector:@selector(onSecTimer) userInfo:nil repeats:YES dispatchQueue:dispatch_get_main_queue()];
}

- (void)onSecTimer {
    NSArray *visibleCells = [self.collectionView visibleCells];
    for (SldMatchListCell *cell in visibleCells) {
        [self refreshTimeLabel:cell];
    }
}

static float _scrollY = -64;

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    CGFloat top = self.topLayoutGuide.length;
    CGFloat bottom = self.bottomLayoutGuide.length;
    UIEdgeInsets newInsets = UIEdgeInsetsMake(top, 0, bottom, 0);
    self.collectionView.contentInset = newInsets;
    
    [_refreshControl endRefreshing];
    
    //refesh
//    if (_gd.needRefreshPlayedList) {
//        [self refreshMatch];
//    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    _scrollY = self.collectionView.contentOffset.y;
}

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView
{
    return YES;
}

- (void)refreshMatch {
    _gd.needRefreshPlayedList = NO;
    _footer.loadMoreButton.enabled = NO;
    
    NSDictionary *body = @{@"StartId": @(0), @"PlayedTime":@(0), @"Limit": @(MATCH_FETCH_LIMIT)};
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"match/listMyPlayed" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        _footer.loadMoreButton.enabled = YES;
        [_refreshControl endRefreshing];
        [self.storeHouseRefreshControl finishingLoading];
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        NSArray *array = dict[@"Matches"];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        if (array.count < MATCH_FETCH_LIMIT) {
            [_footer.loadMoreButton setTitle:@"后面没有了" forState:UIControlStateNormal];
            _footer.loadMoreButton.enabled = NO;
        } else {
            [_footer.loadMoreButton setTitle:@"更多" forState:UIControlStateNormal];
            _footer.loadMoreButton.enabled = YES;
        }
        
        //delete
        int matchNum = _matches.count;
        [_matches removeAllObjects];
        NSMutableArray *deleteIndexPathes = [NSMutableArray array];
        for (int i = 0; i < matchNum; ++i) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
            [deleteIndexPathes addObject:indexPath];
        }
        [self.collectionView deleteItemsAtIndexPaths:deleteIndexPathes];
        
        //insert
        NSMutableArray *insertIndexPathes = [NSMutableArray array];
        for (NSDictionary *dict in array) {
            Match *match = [[Match alloc] initWithDict:dict];
            [_matches addObject:match];
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:_matches.count-1 inSection:0];
            [insertIndexPathes addObject:indexPath];
        }
        [self.collectionView insertItemsAtIndexPaths:insertIndexPathes];
        
        //
        _lastPlayedTime = [(NSNumber*)dict[@"LastPlayedTime"] longLongValue];
    }];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _matches.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    SldMatchListCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"matchListCell" forIndexPath:indexPath];
    Match *match = [_matches objectAtIndex:indexPath.row];
    [cell.imageView asyncLoadUploadImageWithKey:match.thumb showIndicator:NO completion:nil];
    cell.prizeLabel.text = [NSString stringWithFormat:@"奖金：%d", match.prize + match.extraPrize];
    if (match.prize + match.extraPrize == 0) {
        cell.prizeLabel.text = @"";
        cell.darker.hidden = YES;
    } else {
        cell.darker.hidden = NO;
    }
    cell.match = match;
    [self refreshTimeLabel:cell];
    
    return cell;
}

- (void)refreshTimeLabel:(SldMatchListCell*)cell {
    NSDate *endTime = [NSDate dateWithTimeIntervalSince1970:cell.match.endTime];
    NSDate *now = getServerNow();
    NSTimeInterval endIntv = [endTime timeIntervalSinceDate:now];
    if (endIntv <= 0) {
        cell.timeLebel.text = @"已结束";
        cell.timeLebel.backgroundColor = _matchTimeLabelRed;
    } else {
        cell.timeLebel.backgroundColor = _matchTimeLabelGreen;
        if (endIntv > 3600) {
            cell.timeLebel.text = [NSString stringWithFormat:@"%d小时", (int)endIntv/3600];
        } else {
            cell.timeLebel.text = [NSString stringWithFormat:@"%d分钟", (int)endIntv/60];
        }
    }
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    if (kind == UICollectionElementKindSectionFooter) {
        _footer = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"matchListFooter" forIndexPath:indexPath];
        return _footer;
    }
    return nil;
}

- (IBAction)onLoadMoreButton:(id)sender {
    if (_matches.count == 0) {
        return;
    }
        
    [_footer.spin startAnimating];
    _footer.spin.hidden = NO;
    _footer.loadMoreButton.enabled = NO;
    
    Match* lastMatch = [_matches lastObject];
    
    NSDictionary *body = @{@"StartId": @(lastMatch.id), @"PlayedTime":@(_lastPlayedTime), @"Limit": @(MATCH_FETCH_LIMIT)};
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"match/listMyPlayed" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [_footer.spin stopAnimating];
        _footer.loadMoreButton.enabled = YES;
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        NSArray *array = dict[@"Matches"];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        if (array.count < MATCH_FETCH_LIMIT) {
            [_footer.loadMoreButton setTitle:@"后面没有了" forState:UIControlStateNormal];
            _footer.loadMoreButton.enabled = NO;
        }
        
        NSMutableArray *insertIndexPathes = [NSMutableArray array];
        for (NSDictionary *dict in array) {
            Match *match = [[Match alloc] initWithDict:dict];
            [_matches addObject:match];
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:_matches.count-1 inSection:0];
            [insertIndexPathes addObject:indexPath];
        }
        [self.collectionView insertItemsAtIndexPaths:insertIndexPathes];
        
        //
        _lastPlayedTime = [(NSNumber*)dict[@"LastPlayedTime"] longLongValue];
    }];
}

//- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
//    if (_matches.count == 0 || _reachEnd) {
//        return;
//    }
//    
//    float contentHeight = scrollView.contentSize.height + scrollView.contentInset.top + scrollView.contentInset.bottom;
//    
//    if (contentHeight > scrollView.frame.size.height
//        &&(scrollView.contentOffset.y + scrollView.frame.size.height) > contentHeight) {
//        if (!_scrollUnderBottom) {
//            _scrollUnderBottom = YES;
//            if (![_footer.spin isAnimating]) {
//                [_footer.spin startAnimating];
//                
//                SInt64 startId = 0;
//                if (_matches.count > 0) {
//                    Match *match = [_matches lastObject];
//                    startId = match.id;
//                }
////
////                NSDictionary *body = @{@"StartId": @(startId), @"Limit": @(ADVICE_LIMIT)};
////                SldHttpSession *session = [SldHttpSession defaultSession];
////                [session postToApi:@"etc/listAdvice" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
////                    [_bottomRefresh endRefreshing];
////                    if (error) {
////                        alertHTTPError(error, data);
////                        return;
////                    }
////                    NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
////                    if (error) {
////                        lwError("Json error:%@", [error localizedDescription]);
////                        return;
////                    }
////                    
////                    if (array.count < ADVICE_LIMIT) {
////                        _reachEnd = YES;
////                    }
////                    
////                    NSMutableArray *insertIndexPathes = [NSMutableArray array];
////                    for (NSDictionary *dict in array) {
////                        AdviceData *adviceData = [AdviceData adviceDataWithDictionary:dict];
////                        [_adviceDatas addObject:adviceData];
////                        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:_adviceDatas.count-1 inSection:1];
////                        [insertIndexPathes addObject:indexPath];
////                    }
////                    [self.tableView insertRowsAtIndexPaths:insertIndexPathes withRowAnimation:UITableViewRowAnimationAutomatic];
////                }];
//            }
//        }
//        
//    } else {
//        _scrollUnderBottom = NO;
//    }
//}

//- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
//{
//    SldMatchListCell* cell = (SldMatchListCell*)[collectionView cellForItemAtIndexPath:indexPath];
//    
//    //
//    SldGameData *gd = [SldGameData getInstance];
//    gd.match = cell.match;
//    
//    SldMatchBriefController *controller = [self.storyboard instantiateViewControllerWithIdentifier:@"matchBrief"];
//    [self.tabBarController.navigationController pushViewController:controller animated:YES];
//    self.tabBarController.navigationController.navigationBarHidden = NO;
//}

//- (void) viewDidLayoutSubviews {
//    CGFloat top = self.topLayoutGuide.length;
//    CGFloat bottom = self.bottomLayoutGuide.length;
//    UIEdgeInsets newInsets = UIEdgeInsetsMake(top, 0, bottom, 0);
//    self.collectionView.contentInset = newInsets;
//}

- (void)onTabSelect {
    if (!_refreshOnce) {
        _refreshOnce = YES;
        [self refreshMatch];
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    SldMatchListCell *cell = sender;
    SldGameData *gd = [SldGameData getInstance];
    gd.match = cell.match;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self.storeHouseRefreshControl scrollViewDidScroll];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    [self.storeHouseRefreshControl scrollViewDidEndDragging];
}
@end
