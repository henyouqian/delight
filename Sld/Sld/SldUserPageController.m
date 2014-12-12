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

//====================
@interface SldUserPageHeader : UICollectionReusableView
@property (weak, nonatomic) IBOutlet UIImageView *avatarView;
@property (weak, nonatomic) IBOutlet UILabel *userNameLabel;
@property (weak, nonatomic) IBOutlet UIView *segView;

@end

@implementation SldUserPageHeader

@end

//====================
@interface SldUserPageController () <DKScrollingTabControllerDelegate>

@property SldGameData *gd;

@property NSMutableArray *matches;
@property SldUserPageHeader *header;
@property SldMatchListFooter *footer;
@property (nonatomic) UIRefreshControl *refreshControl;
@property (nonatomic) MSWeakTimer *secTimer;
@property (nonatomic) BOOL refreshOnce;
@property (nonatomic) CBStoreHouseRefreshControl *storeHouseRefreshControl;

@end

@implementation SldUserPageController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.navigationController.view.backgroundColor = [UIColor whiteColor];
    
    _gd = [SldGameData getInstance];
    
    _matches = [NSMutableArray array];
    _refreshOnce = NO;
    
    [self refresh];
    
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
    
    NSDictionary *body = @{@"UserId": @(_gd.packInfo.author.userId), @"StartId": @(0), @"LastScore":@(0), @"Limit": @(MATCH_FETCH_LIMIT)};
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"match/listUserPublic" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
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
        
        if (matchesJs.count < MATCH_FETCH_LIMIT) {
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
        for (NSDictionary *dict in matchesJs) {
            Match *match = [[Match alloc] initWithDict:dict];
            [_matches addObject:match];
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:_matches.count-1 inSection:0];
            [insertIndexPathes addObject:indexPath];
        }
        [self.collectionView insertItemsAtIndexPaths:insertIndexPathes];
    }];
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

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
    PlayerInfo *author = _gd.packInfo.author;
    [SldUtil loadAvatar:_header.avatarView gravatarKey:author.gravatarKey customAvatarKey:author.customAvatarKey];
    
    [_header.avatarView.layer setMasksToBounds:YES];
    _header.avatarView.layer.cornerRadius = 5;
    
    _header.userNameLabel.text = author.nickName;
    
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
    
//    [tabController selectButtonWithIndex:0];
}

- (void)DKScrollingTabController:(DKScrollingTabController *)controller selection:(NSUInteger)selection {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        
    });
}

- (IBAction)onLoadMoreButton:(id)sender {
    if (_matches.count == 0) {
        return;
    }
    
    [_footer.spin startAnimating];
    _footer.spin.hidden = NO;
    _footer.loadMoreButton.enabled = NO;
    
    Match* lastMatch = [_matches lastObject];
    
    NSDictionary *body = @{@"StartId": @(lastMatch.id), @"BeginTime":@(lastMatch.beginTime), @"Limit": @(MATCH_FETCH_LIMIT)};
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
    SldMatchListCell *cell = sender;
    SldGameData *gd = [SldGameData getInstance];
    gd.match = cell.match;
}


@end
