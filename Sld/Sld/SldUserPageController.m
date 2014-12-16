//
//  SldUserPageController.m
//  pin
//
//  Created by 李炜 on 14/12/12.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldUserPageController.h"
#import "SldUtil.h"
#import "SldGameData.h"
#import "DKScrollingTabController.h"
#import "SldMatchListController.h"
#import "SldConfig.h"
#import "SldHttpSession.h"
#import "SldFollowListController.h"

//====================
@interface SldUserPageHeader : UICollectionReusableView
@property (weak, nonatomic) IBOutlet SldAsyncImageView *avatarView;
@property (weak, nonatomic) IBOutlet UILabel *userNameLabel;
@property (weak, nonatomic) IBOutlet UIView *segView;
@property (weak, nonatomic) IBOutlet UIButton *fanLabel;
@property (weak, nonatomic) IBOutlet UIButton *followLabel;

@end

@implementation SldUserPageHeader

@end

//====================
@interface SldUserPageController () <DKScrollingTabControllerDelegate>

@property SldGameData *gd;

@property NSMutableArray *matches;
@property NSMutableArray *likeMatches;
@property NSMutableArray *originalMatches;
@property NSMutableArray *playedMatches;
@property BOOL likeLoaded;
@property BOOL originalLoaded;
@property BOOL playedLoaded;
@property BOOL likeEnd;
@property BOOL originalEnd;
@property BOOL playedEnd;

@property SldUserPageHeader *header;
@property SldMatchListFooter *footer;
@property (nonatomic) UIRefreshControl *refreshControl;
@property (nonatomic) MSWeakTimer *secTimer;
@property (nonatomic) CBStoreHouseRefreshControl *storeHouseRefreshControl;

@property SInt64 likeLastScore;
@property SInt64 originalLastScore;
@property SInt64 playedLastScore;


@end

@implementation SldUserPageController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    /////
    self.navigationController.view.backgroundColor = [UIColor whiteColor];
    
    _gd = [SldGameData getInstance];
    
    _likeMatches = [NSMutableArray array];
    _originalMatches = [NSMutableArray array];
    _playedMatches = [NSMutableArray array];
    _matches = _likeMatches;
    
    [self updateFollowButton];
    
    [self refresh];
    _likeLoaded = YES;
    
    //refresh control
    self.collectionView.alwaysBounceVertical = YES;
    self.storeHouseRefreshControl = [CBStoreHouseRefreshControl attachToScrollView:self.collectionView
                                                                            target:self
                                                                     refreshAction:@selector(refresh) plist:@"storehouse"
                                                                             color:[UIColor orangeColor]
                                                                         lineWidth:4
                                                                        dropHeight:80
                                                                             scale:1
                                                              horizontalRandomness:150
                                                           reverseLoadingAnimation:NO
                                                           internalAnimationFactor:0.7];
    
    //timer
    _secTimer = [MSWeakTimer scheduledTimerWithTimeInterval:1.f target:self selector:@selector(onSecTimer) userInfo:nil repeats:YES dispatchQueue:dispatch_get_main_queue()];
    
    self.title = [NSString stringWithFormat:@"%@的主页", _playerInfo.nickName];
    
    self.collectionView.backgroundColor = [UIColor darkGrayColor];
}

- (void)dealloc {
    [_secTimer invalidate];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [_refreshControl endRefreshing];
}

- (BOOL)scrollViewShouldScrollToTop:(UIScrollView *)scrollView {
    return YES;
}

- (void)onSecTimer {
    NSArray *visibleCells = [self.collectionView visibleCells];
    for (SldMatchListCell *cell in visibleCells) {
        [self refreshTimeLabel:cell];
    }
}

- (void)refresh {
    _footer.loadMoreButton.enabled = NO;
    
    NSString *api = @"";
    if (_matches == _likeMatches) {
        api = @"match/listLike";
    } else if (_matches == _originalMatches) {
        api = @"match/listOriginal";
    } else if (_matches == _playedMatches) {
        api = @"match/listPlayed";
    }
    
    NSDictionary *body = @{@"UserId": @(_playerInfo.userId), @"StartId": @(0), @"LastScore":@(0), @"Limit": @(MATCH_FETCH_LIMIT)};
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:api body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        _footer.loadMoreButton.enabled = YES;
        [_refreshControl endRefreshing];
        [self.storeHouseRefreshControl finishingLoading];
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        NSDictionary *msgJs = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        NSArray *matchesJs = [msgJs objectForKey:@"Matches"];
        SInt64 lastScore = [(NSNumber*)[msgJs objectForKey:@"LastScore"]longLongValue];
        BOOL *listEnd = nil;
        if (_matches == _likeMatches) {
            _likeLastScore = lastScore;
            listEnd = &_likeEnd;
        } else if (_matches == _originalMatches) {
            _originalLastScore = lastScore;
            listEnd = &_originalEnd;
        } else if (_matches == _playedMatches) {
            _playedLastScore = lastScore;
            listEnd = &_playedEnd;
        }
        
        if (matchesJs.count < MATCH_FETCH_LIMIT) {
            *listEnd = YES;
        } else {
            *listEnd = NO;
        }
        
//        //delete
//        int matchNum = _matches.count;
//        [_matches removeAllObjects];
//        NSMutableArray *deleteIndexPathes = [NSMutableArray array];
//        for (int i = 0; i < matchNum; ++i) {
//            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
//            [deleteIndexPathes addObject:indexPath];
//        }
//        [self.collectionView deleteItemsAtIndexPaths:deleteIndexPathes];
//        
//        //insert
//        NSMutableArray *insertIndexPathes = [NSMutableArray array];
//        for (NSDictionary *dict in matchesJs) {
//            Match *match = [[Match alloc] initWithDict:dict];
//            [_matches addObject:match];
//            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:_matches.count-1 inSection:0];
//            [insertIndexPathes addObject:indexPath];
//        }
//        [self.collectionView insertItemsAtIndexPaths:insertIndexPathes];
        
        [_matches removeAllObjects];
        for (NSDictionary *dict in matchesJs) {
            Match *match = [[Match alloc] initWithDict:dict];
            [_matches addObject:match];
        }
        [self updateInsets];
        [self updateListEnd];
        [self.collectionView reloadData];
    }];
}

- (void)updateInsets {
//    int n = _matches.count;
//    float height = ((n-1)/3+1) * (100+4) + 70 + 60 + 20;
//    float h = self.collectionView.frame.size.height-height;
//    if (h > 0) {
//        self.collectionView.contentInset = UIEdgeInsetsMake(self.collectionView.contentInset.top, 0, h, 0);
//    }
}

- (void)updateListEnd {
    BOOL listEnd;
    if (_matches == _likeMatches) {
        listEnd = _likeEnd;
    } else if (_matches == _originalMatches) {
        listEnd = _originalEnd;
    } else if (_matches == _playedMatches) {
        listEnd = _playedEnd;
    }
    
    if (listEnd) {
        [_footer.loadMoreButton setTitle:@"后面没有了" forState:UIControlStateNormal];
        _footer.loadMoreButton.enabled = NO;
    } else {
        [_footer.loadMoreButton setTitle:@"更多" forState:UIControlStateNormal];
        _footer.loadMoreButton.enabled = YES;
    }
}

#pragma mark <UICollectionViewDataSource>

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
    [cell.timeLebel.layer setAffineTransform:CGAffineTransformMakeRotation(M_PI_4)];
    if (match.prize + match.extraPrize == 0) {
        cell.prizeLabel.text = @"";
        cell.darker.hidden = YES;
    } else {
        cell.darker.hidden = NO;
    }
    //
    cell.match = match;
    [self refreshTimeLabel:cell];
    
    if (cell.timeLebel.hidden) {
        cell.prizeLabel.text = @"";
        cell.darker.hidden = YES;
    }
    
    cell.layer.shouldRasterize = YES;
    cell.layer.rasterizationScale = [UIScreen mainScreen].scale;
    
    return cell;
}

- (void)refreshTimeLabel:(SldMatchListCell*)cell {
    NSDate *endTime = [NSDate dateWithTimeIntervalSince1970:cell.match.endTime];
    NSDate *now = getServerNow();
    NSTimeInterval endIntv = [endTime timeIntervalSinceDate:now];
    if (endIntv <= 0) {
        cell.timeLebel.hidden = YES;
        
        cell.timeLebel.text = @"已结束";
        cell.timeLebel.backgroundColor = _matchTimeLabelRed;
        cell.timeLebel.alpha = 230;
    } else {
        cell.timeLebel.hidden = NO;
        cell.timeLebel.backgroundColor = _matchTimeLabelGreen;
        if (endIntv > 3600) {
            cell.timeLebel.text = [NSString stringWithFormat:@"%d小时", (int)endIntv/3600];
        } else {
            cell.timeLebel.text = [NSString stringWithFormat:@"%d分钟", (int)endIntv/60];
        }
        cell.timeLebel.alpha = 255;
    }
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    
    if (kind == UICollectionElementKindSectionHeader) {
        if (_header) {
            return _header;
        }
        _header = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"header" forIndexPath:indexPath];
        [self updateHeader];
        return _header;
    } else if (kind == UICollectionElementKindSectionFooter) {
        _footer = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"matchListFooter" forIndexPath:indexPath];
        return _footer;
    }
    return nil;
}

- (void)updateHeader{
    [SldUtil loadAvatar:_header.avatarView gravatarKey:_playerInfo.gravatarKey customAvatarKey:_playerInfo.customAvatarKey];
    
    [_header.avatarView.layer setMasksToBounds:YES];
    _header.avatarView.layer.cornerRadius = 5;
    
    _header.userNameLabel.text = _playerInfo.nickName;
    
    //
    DKScrollingTabController *tabController = [[DKScrollingTabController alloc] init];
    tabController.delegate = self;
    
    [self addChildViewController:tabController];
    [tabController didMoveToParentViewController:self];
    [_header addSubview:tabController.view];
    tabController.view.backgroundColor = [UIColor whiteColor];
    tabController.view.frame = _header.segView.frame;
    
    // controller customization
    tabController.selectionFont = [UIFont boldSystemFontOfSize:12];
    tabController.buttonInset = 30;
    tabController.buttonPadding = 4;
    tabController.firstButtonInset = 30;
    
    tabController.translucent = YES;
    
    CGRect frame = tabController.toolbar.frame;
    frame.size.width = 12000;
    tabController.toolbar.frame = frame;
    
    //remove scroll bar
    tabController.buttonsScrollView.showsHorizontalScrollIndicator = NO;
    
    //add indicator
    tabController.selectedTextColor = [UIColor orangeColor];
    tabController.underlineIndicator = YES; // the color is from selectedTextColor property
    
    //this has to be done after customization
    tabController.selection = @[@"喜欢", @"原创", @"参与"];
    
    [self updateFollowAndFanLabel];
}

- (void)updateFollowAndFanLabel {
    NSString *title = [NSString stringWithFormat:@"关注:%d", _playerInfo.followNum];
    [_header.followLabel setTitle:title forState:UIControlStateNormal];
    
    title = [NSString stringWithFormat:@"粉丝:%d", _playerInfo.fanNum];
    [_header.fanLabel setTitle:title forState:UIControlStateNormal];
}

- (void)DKScrollingTabController:(DKScrollingTabController *)controller selection:(NSUInteger)selection {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        BOOL needRefresh = NO;
        if (selection == 0) {
            _matches = _likeMatches;
            if (!_likeLoaded) {
                needRefresh = _likeLoaded = YES;
            }
        } else if (selection == 1) {
            _matches = _originalMatches;
            if (!_originalLoaded) {
                needRefresh = _originalLoaded = YES;
            }
        } else if (selection == 2) {
            _matches = _playedMatches;
            if (!_playedLoaded) {
                needRefresh = _playedLoaded = YES;
            }
        }
        
        if (needRefresh) {
            [self refresh];
        } else {
            [self updateInsets];
            [self updateListEnd];
            [self.collectionView reloadData];
            
//            [self.collectionView performBatchUpdates:^{
//                int n = [self.collectionView numberOfItemsInSection:0];
//                NSMutableArray *indexPaths = [NSMutableArray arrayWithCapacity:n];
//                for (int i = 0; i < n; ++i) {
//                    [indexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
//                }
//                [self.collectionView deleteItemsAtIndexPaths:indexPaths];
//                
//                n = _matches.count;
//                indexPaths = [NSMutableArray arrayWithCapacity:n];
//                for (int i = 0; i < n; ++i) {
//                    [indexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
//                }
//                [self.collectionView insertItemsAtIndexPaths:indexPaths];
//            } completion:nil];
        }
    });
}

- (IBAction)onLoadMoreButton:(id)sender {
    if (_matches.count == 0) {
        return;
    }
    
    [_footer.spin startAnimating];
    _footer.spin.hidden = NO;
    _footer.loadMoreButton.enabled = NO;
    
    NSString *api = @"";
    SInt64 *lastScore = nil;
    BOOL *listEnd = nil;
    if (_matches == _likeMatches) {
        api = @"match/listLike";
        lastScore = &_likeLastScore;
        listEnd = &_likeEnd;
    } else if (_matches == _originalMatches) {
        api = @"match/listOriginal";
        lastScore = &_originalLastScore;
        listEnd = &_originalEnd;
    } else if (_matches == _playedMatches) {
        api = @"match/listPlayed";
        lastScore = &_playedLastScore;
        listEnd = &_playedEnd;
    }
    
    Match* lastMatch = [_matches lastObject];
    NSDictionary *body = @{@"UserId": @(_playerInfo.userId), @"StartId": @(lastMatch.id), @"LastScore":@(*lastScore), @"Limit": @(MATCH_FETCH_LIMIT)};
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:api body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [_footer.spin stopAnimating];
        _footer.loadMoreButton.enabled = YES;
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        NSDictionary *msgJs = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        NSArray *matchesJs = [msgJs objectForKey:@"Matches"];
        *lastScore = [(NSNumber*)[msgJs objectForKey:@"LastScore"]longLongValue];
        
        if (matchesJs.count < MATCH_FETCH_LIMIT) {
            *listEnd = YES;
        } else {
            *listEnd = NO;
        }
        
        NSMutableArray *insertIndexPathes = [NSMutableArray array];
        for (NSDictionary *dict in matchesJs) {
            Match *match = [[Match alloc] initWithDict:dict];
            [_matches addObject:match];
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:_matches.count-1 inSection:0];
            [insertIndexPathes addObject:indexPath];
        }
        [self.collectionView insertItemsAtIndexPaths:insertIndexPathes];
        [self updateInsets];
        [self updateListEnd];
    }];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self.storeHouseRefreshControl scrollViewDidScroll];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    [self.storeHouseRefreshControl scrollViewDidEndDragging];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier compare:@"segueMatch"] == 0) {
        SldMatchListCell *cell = sender;
        SldGameData *gd = [SldGameData getInstance];
        gd.match = cell.match;
    } else if ([segue.identifier compare:@"segueFollow"] == 0) {
        SldFollowListController *vc = segue.destinationViewController;
        vc.follow = true;
        vc.playerInfo = _playerInfo;
    } else if ([segue.identifier compare:@"segueFans"] == 0) {
        SldFollowListController *vc = segue.destinationViewController;
        vc.follow = false;
        vc.playerInfo = _playerInfo;
    }
}

- (void)updateFollowButton {
    if (_playerInfo.userId == _gd.playerInfo.userId) {
        self.navigationItem.rightBarButtonItem.enabled = false;
        [self.navigationItem.rightBarButtonItem setTitle:@""];
    } else {
        self.navigationItem.rightBarButtonItem.enabled = true;
        if (_playerInfo.followed) {
            [self.navigationItem.rightBarButtonItem setTitle:@"已关注"];
        } else {
            [self.navigationItem.rightBarButtonItem setTitle:@"关注"];
        }
    }
}

- (void)doFollow:(BOOL)follow {
    NSString *api = nil;
    if (follow) {
        api = @"player/follow";
    } else {
        api = @"player/unfollow";
    }
    
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"UserId":@(_playerInfo.userId)};
    [session postToApi:api body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        bool follow = [(NSNumber*)[dict objectForKey:@"Follow"] boolValue];
        _playerInfo.followed = follow;
        [self updateFollowButton];
    }];

}

- (IBAction)onFollowButton:(id)sender {
    if (_playerInfo.followed) {

        [[[UIAlertView alloc] initWithTitle:@"取消关注?"
                                    message:nil
                           cancelButtonItem:[RIButtonItem itemWithLabel:@"以后再说" action:^{
            // Handle "Cancel"
        }]
                           otherButtonItems:[RIButtonItem itemWithLabel:@"取消关注" action:^{
            [self doFollow:false];
        }], nil] show];
    } else {
        [self doFollow:true];
    }
}

@end
