//
//  SldPrizeListController.m
//  pin
//
//  Created by 李炜 on 14-9-26.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldPrizeListController.h"
#import "SldHttpSession.h"
#import "SldGameData.h"
#import "SldTradeController.h"
#import "UIImageView+sldAsyncLoad.h"

static const int PRIZE_LIST_FETCH_LIMIT = 30;

//=================
@interface SldGetPrizeCacheCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *prizeLabel;
@property (weak, nonatomic) IBOutlet UIButton *getPrizeButton;
@end

@implementation SldGetPrizeCacheCell
@end

//=================
@interface SldPrizeCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIImageView *thumbView;
@property (weak, nonatomic) IBOutlet UILabel *reasonLabel;
@property (weak, nonatomic) IBOutlet UILabel *prizeLabel;
@property (weak, nonatomic) IBOutlet UILabel *rankLabel;

@end

@implementation SldPrizeCell
@end

//=================
@interface SldMorePrizeCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spin;
@property (weak, nonatomic) IBOutlet UIButton *moreButton;

@end

@implementation SldMorePrizeCell
@end

//=================
@interface SldPrizeRecord : NSObject
@property (nonatomic) SInt64 selfId;
@property (nonatomic) SInt64 matchId;
@property (nonatomic) NSString *thumb;
@property (nonatomic) NSString *reason;
@property (nonatomic) int prize;
@property (nonatomic) int rank;

- (instancetype)initWithDict:(NSDictionary*)dict;
@end

@implementation SldPrizeRecord
- (instancetype)initWithDict:(NSDictionary*)dict {
    if (self = [super init]) {
        _selfId = [(NSNumber*)[dict objectForKey:@"Id"] longLongValue];
        _matchId = [(NSNumber*)[dict objectForKey:@"MatchId"] longLongValue];
        _thumb = [dict objectForKey:@"Thumb"];
        _reason = [dict objectForKey:@"Reason"];
        _prize = [(NSNumber*)[dict objectForKey:@"Prize"] floatValue];
        _rank = [(NSNumber*)[dict objectForKey:@"Rank"] intValue];
    }
    return self;
}
@end


//================================
static __weak SldPrizeListController *_inst = nil;

@interface SldPrizeListController ()

@property (nonatomic) NSMutableArray *prizeRecords;
@property (nonatomic) SldGameData *gd;
@property (nonatomic) SldMorePrizeCell *morePrizeCell;

@end

@implementation SldPrizeListController

+ (instancetype)getInstence {
    return _inst;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _inst = self;
    
    _gd = [SldGameData getInstance];
    
    _prizeRecords = [NSMutableArray array];
    
    //refresh control
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    
    //
    [self refresh];
    
    //login notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onLogin) name:@"login" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshPrizeUI) name:@"prizeCacheChange" object:nil];
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
    _morePrizeCell.moreButton.enabled = NO;
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"StartId":@(startId), @"Limit":@(PRIZE_LIST_FETCH_LIMIT)};
    [session postToApi:@"player/listMyPrize" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        _morePrizeCell.moreButton.enabled = YES;
        [self.refreshControl endRefreshing];
        [_morePrizeCell.spin stopAnimating];
        
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSArray *jsPrizeRecords = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        if (jsPrizeRecords.count < PRIZE_LIST_FETCH_LIMIT) {
            [_morePrizeCell.moreButton setTitle:@"后面没有了" forState:UIControlStateNormal];
            _morePrizeCell.moreButton.enabled = NO;
        } else {
            [_morePrizeCell.moreButton setTitle:@"更多" forState:UIControlStateNormal];
            _morePrizeCell.moreButton.enabled = YES;
        }
        
        if (startId == 0) {
            [_prizeRecords removeAllObjects];
        }
        
        NSMutableArray *insetIndexPathes = [NSMutableArray array];
        
        for (NSDictionary *jsRecord in jsPrizeRecords) {
            SldPrizeRecord *record = [[SldPrizeRecord alloc] initWithDict:jsRecord];
            
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:_prizeRecords.count inSection:1];
            
            [_prizeRecords addObject:record];
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

- (IBAction)onMorePrizeButton:(id)sender {
    if (_prizeRecords.count) {
        [_morePrizeCell.spin startAnimating];
        _morePrizeCell.hidden = NO;
        SldPrizeRecord *record = [_prizeRecords lastObject];
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
        return _prizeRecords.count;
    } else if (section == 2) {
        return 1;
    }
    return 0;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        SldGetPrizeCacheCell *cell = [tableView dequeueReusableCellWithIdentifier:@"matchGetPrizeCacheCell" forIndexPath:indexPath];
        int prizeCache = _gd.playerInfo.prizeCache;
        
        cell.prizeLabel.text = [NSString stringWithFormat:@"现有奖金：%d", _gd.playerInfo.prize];
        
        NSString *title = [NSString stringWithFormat:@"可领取奖金：%d", prizeCache];
        [cell.getPrizeButton setTitle:title forState:UIControlStateNormal];
        [cell.getPrizeButton setTitle:title forState:UIControlStateDisabled];
        if (prizeCache > 0) {
            cell.getPrizeButton.enabled = YES;
            cell.getPrizeButton.backgroundColor = makeUIColor(244, 75, 116, 255);
        } else {
            cell.getPrizeButton.enabled = NO;
            cell.getPrizeButton.backgroundColor = [UIColor grayColor];
        }
        return cell;
    } else if (indexPath.section == 1) {
        SldPrizeCell *cell = [tableView dequeueReusableCellWithIdentifier:@"matchPrizeCell" forIndexPath:indexPath];
        SldPrizeRecord *record = _prizeRecords[indexPath.row];
        cell.reasonLabel.text = record.reason;
        cell.prizeLabel.text = [NSString stringWithFormat:@"奖金：%d", record.prize];
        if (record.rank != 0) {
            cell.rankLabel.text = [NSString stringWithFormat:@"排名：%d", record.rank];
            cell.rankLabel.hidden = NO;
        } else {
            cell.rankLabel.hidden = YES;
        }
        [cell.thumbView asyncLoadUploadedImageWithKey:record.thumb showIndicator:NO completion:nil];
        return cell;
    } else if (indexPath.section == 2) {
        SldMorePrizeCell *cell = [tableView dequeueReusableCellWithIdentifier:@"morePrizeCell" forIndexPath:indexPath];
        
        _morePrizeCell = cell;
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

- (IBAction)onGetPrizeButton:(id)sender {
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"player/addPrizeFromCache" body:nil completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        _gd.playerInfo.prize = [(NSNumber*)dict[@"Prize"] floatValue];
        _gd.playerInfo.totalPrize = [(NSNumber*)dict[@"TotalPrize"] floatValue];
        _gd.playerInfo.prizeCache = 0;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"prizeCacheChange" object:nil];
    }];
}

- (void)refreshPrizeUI {
    NSIndexSet *indexSet = [NSIndexSet indexSetWithIndex:0];
    [self.tableView reloadSections:indexSet withRowAnimation:UITableViewRowAnimationAutomatic];
    
    if (_gd.playerInfo.prizeCache == 0) {
        [SldTradeController getInstance].navigationController.tabBarItem.badgeValue = nil;
    }
}

@end
