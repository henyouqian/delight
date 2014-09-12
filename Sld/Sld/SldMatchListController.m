//
//  SldMatchListController.m
//  pin
//
//  Created by 李炜 on 14-8-16.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldMatchListController.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldUtil.h"
#import "SldGameData.h"
#import "SldHttpSession.h"
#import "UIImage+ImageEffects.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldMyUserPackMenuController.h"
#import "SldMyMatchController.h"

static const int USER_PACK_LIST_LIMIT = 6;

//=============================
@interface SldMatchListCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet SldAsyncImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *rewardNumLabel;
@property (nonatomic) Match* match;
@end

@implementation SldMatchListCell

@end

//=============================
@interface SldMatchListFooter : UICollectionReusableView
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spin;
@property (weak, nonatomic) IBOutlet UIButton *loadMoreButton;
@end

@implementation SldMatchListFooter

@end

//=============================
@interface SldMatchListController()

@property (nonatomic) NSMutableArray *matches;
@property (nonatomic) SldMatchListFooter *footer;
@property (nonatomic) UIRefreshControl *refreshControl;

@end

@implementation SldMatchListController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _matches = [NSMutableArray array];
    
    //refresh control
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.collectionView.alwaysBounceVertical = YES;
    [self.collectionView addSubview:self.refreshControl];
    [self.refreshControl addTarget:self action:@selector(refreshMatch) forControlEvents:UIControlEventValueChanged];
    
    //
    [self refreshMatch];
}

- (void)refreshMatch {
    [_refreshControl endRefreshing];
    
    NSDictionary *body = @{@"StartId": @(0), @"BeginTime":@(0), @"Limit": @(USER_PACK_LIST_LIMIT)};
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"match/list" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        if (array.count < USER_PACK_LIST_LIMIT) {
            [_footer.loadMoreButton setTitle:@"没有了" forState:UIControlStateNormal];
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
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    UIEdgeInsets insets = self.collectionView.contentInset;
    insets.top = 64;
    insets.bottom = 50;
    
    self.collectionView.contentInset = insets;
    self.collectionView.scrollIndicatorInsets = insets;
    self.tabBarController.automaticallyAdjustsScrollViewInsets = NO;
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
    if (match.extraReward == 0) {
        cell.rewardNumLabel.text = [NSString stringWithFormat:@"奖金：%d", match.couponReward];
    } else {
        cell.rewardNumLabel.text = [NSString stringWithFormat:@"奖金：%d+%d", match.couponReward, match.extraReward];
    }
    
    cell.match = match;
    return cell;
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
    _footer.loadMoreButton.enabled = NO;
    
    Match* lastMatch = [_matches lastObject];
    
    NSDictionary *body = @{@"StartId": @(lastMatch.id), @"BeginTime":@(lastMatch.beginTime), @"Limit": @(USER_PACK_LIST_LIMIT)};
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"match/list" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [_footer.spin stopAnimating];
        _footer.loadMoreButton.enabled = YES;
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        if (array.count < USER_PACK_LIST_LIMIT) {
            [_footer.loadMoreButton setTitle:@"没有了" forState:UIControlStateNormal];
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

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    SldMatchListCell *cell = sender;
    SldGameData *gd = [SldGameData getInstance];
    gd.match = cell.match;
}

@end
