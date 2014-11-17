//
//  SldRewardListController.m
//  pin
//
//  Created by 李炜 on 14-9-26.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldRewardListController.h"
#import "SldHttpSession.h"
#import "SldGameData.h"
#import "SldTradeController.h"
#import "UIImageView+sldAsyncLoad.h"

static const int REWARD_LIST_FETCH_LIMIT = 30;

//=================
@interface SldGetCouponCacheCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *couponLabel;
@property (weak, nonatomic) IBOutlet UIButton *getRewardButton;
@end

@implementation SldGetCouponCacheCell
@end

//=================
@interface SldRewardCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIImageView *thumbView;
@property (weak, nonatomic) IBOutlet UILabel *reasonLabel;
@property (weak, nonatomic) IBOutlet UILabel *couponLabel;
@property (weak, nonatomic) IBOutlet UILabel *rankLabel;

@end

@implementation SldRewardCell
@end

//=================
@interface SldMoreRewardCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spin;
@property (weak, nonatomic) IBOutlet UIButton *moreButton;

@end

@implementation SldMoreRewardCell
@end

//=================
@interface SldRewardRecord : NSObject
@property (nonatomic) SInt64 selfId;
@property (nonatomic) SInt64 matchId;
@property (nonatomic) NSString *thumb;
@property (nonatomic) NSString *reason;
@property (nonatomic) float coupon;
@property (nonatomic) int rank;

- (instancetype)initWithDict:(NSDictionary*)dict;
@end

@implementation SldRewardRecord
- (instancetype)initWithDict:(NSDictionary*)dict {
    if (self = [super init]) {
        _selfId = [(NSNumber*)[dict objectForKey:@"Id"] longLongValue];
        _matchId = [(NSNumber*)[dict objectForKey:@"MatchId"] longLongValue];
        _thumb = [dict objectForKey:@"Thumb"];
        _reason = [dict objectForKey:@"Reason"];
        _coupon = [(NSNumber*)[dict objectForKey:@"Coupon"] floatValue];
        _rank = [(NSNumber*)[dict objectForKey:@"Rank"] intValue];
    }
    return self;
}
@end


//================================
static __weak SldRewardListController *_inst = nil;

@interface SldRewardListController ()

@property (nonatomic) NSMutableArray *rewardRecords;
@property (nonatomic) SldGameData *gd;
@property (nonatomic) SldMoreRewardCell *moreRewardCell;

@end

@implementation SldRewardListController

+ (instancetype)getInstence {
    return _inst;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _inst = self;
    
    _gd = [SldGameData getInstance];
    
    _rewardRecords = [NSMutableArray array];
    
    //refresh control
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    
    //
    [self refresh];
    
    //login notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onLogin) name:@"login" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshCouponUI) name:@"couponCacheChange" object:nil];
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)onLogin {
    [self refresh];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.refreshControl endRefreshing];
}

- (void)fetchWithStartId:(SInt64)startId {
    _moreRewardCell.moreButton.enabled = NO;
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"StartId":@(startId), @"Limit":@(REWARD_LIST_FETCH_LIMIT)};
    [session postToApi:@"player/listMyReward" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        _moreRewardCell.moreButton.enabled = YES;
        [self.refreshControl endRefreshing];
        [_moreRewardCell.spin stopAnimating];
        
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSArray *jsRewardRecords = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        if (jsRewardRecords.count < REWARD_LIST_FETCH_LIMIT) {
            [_moreRewardCell.moreButton setTitle:@"后面没有了" forState:UIControlStateNormal];
            _moreRewardCell.moreButton.enabled = NO;
        } else {
            [_moreRewardCell.moreButton setTitle:@"更多" forState:UIControlStateNormal];
            _moreRewardCell.moreButton.enabled = YES;
        }
        
        if (startId == 0) {
            [_rewardRecords removeAllObjects];
        }
        
        NSMutableArray *insetIndexPathes = [NSMutableArray array];
        
        for (NSDictionary *jsRecord in jsRewardRecords) {
            SldRewardRecord *record = [[SldRewardRecord alloc] initWithDict:jsRecord];
            
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:_rewardRecords.count inSection:1];
            
            [_rewardRecords addObject:record];
            [insetIndexPathes addObject:indexPath];
        }
        
        if (startId == 0) {
//            [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
            [self.tableView reloadData];
        } else {
            [self.tableView insertRowsAtIndexPaths:insetIndexPathes withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }];
}

- (void)refresh {
    [self fetchWithStartId:0];
}

- (IBAction)onMoreRewardButton:(id)sender {
    if (_rewardRecords.count) {
        [_moreRewardCell.spin startAnimating];
        _moreRewardCell.hidden = NO;
        SldRewardRecord *record = [_rewardRecords lastObject];
        [self fetchWithStartId:record.selfId];
    }
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return 1;
    } else if (section == 1) {
        return _rewardRecords.count;
    } else if (section == 2) {
        return 1;
    }
    return 0;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        SldGetCouponCacheCell *cell = [tableView dequeueReusableCellWithIdentifier:@"matchGetCouponCacheCell" forIndexPath:indexPath];
        float couponCache = _gd.playerInfo.couponCache;
        
        cell.couponLabel.text = [NSString stringWithFormat:@"现有奖金：%.2f", _gd.playerInfo.coupon];
        
        NSString *title = [NSString stringWithFormat:@"可领取奖金：%.2f", couponCache];
        [cell.getRewardButton setTitle:title forState:UIControlStateNormal];
        [cell.getRewardButton setTitle:title forState:UIControlStateDisabled];
        if (couponCache > 0) {
            cell.getRewardButton.enabled = YES;
            cell.getRewardButton.backgroundColor = makeUIColor(244, 75, 116, 255);
        } else {
            cell.getRewardButton.enabled = NO;
            cell.getRewardButton.backgroundColor = [UIColor grayColor];
        }
        return cell;
    } else if (indexPath.section == 1) {
        SldRewardCell *cell = [tableView dequeueReusableCellWithIdentifier:@"matchRewardCell" forIndexPath:indexPath];
        SldRewardRecord *record = _rewardRecords[indexPath.row];
        cell.reasonLabel.text = record.reason;
        cell.couponLabel.text = [NSString stringWithFormat:@"奖金：%.2f", record.coupon];
        if (record.rank != 0) {
            cell.rankLabel.text = [NSString stringWithFormat:@"排名：%d", record.rank];
            cell.rankLabel.hidden = NO;
        } else {
            cell.rankLabel.hidden = YES;
        }
        [cell.thumbView asyncLoadUploadedImageWithKey:record.thumb showIndicator:NO completion:nil];
        return cell;
    } else if (indexPath.section == 2) {
        SldMoreRewardCell *cell = [tableView dequeueReusableCellWithIdentifier:@"moreRewardCell" forIndexPath:indexPath];
        
        _moreRewardCell = cell;
        return cell;
    }
    
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return 85;
    } else if (indexPath.section == 1){
        return 60;
    } else  if (indexPath.section == 2){
        return 60;
    }
    return 0;
}

- (IBAction)onGetRewardButton:(id)sender {
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"player/addCouponFromCache" body:nil completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        _gd.playerInfo.coupon = [(NSNumber*)dict[@"Coupon"] floatValue];
        _gd.playerInfo.totalCoupon = [(NSNumber*)dict[@"TotalCoupon"] floatValue];
        _gd.playerInfo.couponCache = 0;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"couponCacheChange" object:nil];
    }];
}

- (void)refreshCouponUI {
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:0];
    [self.tableView reloadSections:indexSet withRowAnimation:UITableViewRowAnimationAutomatic];
    
    if (_gd.playerInfo.couponCache < 0.01) {
        [SldTradeController getInstance].navigationController.tabBarItem.badgeValue = nil;
    }
}

@end
