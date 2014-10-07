//
//  SldCouponCardController.m
//  pin
//
//  Created by 李炜 on 14-9-27.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldCouponCardController.h"
#import "SldHttpSession.h"

//============================
@implementation SldEcard

- (instancetype)initWithDict:(NSDictionary*)dict {
    if (self = [super init]) {
        _Id = [(NSNumber*)dict[@"Id"] longLongValue];
        _TypeKey = dict[@"TypeKey"];
        _CouponCode = dict[@"CouponCode"];
        _ExpireDate = dict[@"ExpireDate"];
        _GenDate = dict[@"GenDate"];
        _UserGetDate = dict[@"UserGetDate"];
        _Title = dict[@"Title"];
        _RechargeUrl = dict[@"RechargeUrl"];
        _HelpText = dict[@"HelpText"];
    }
    
    return self;
}

@end

static SldEcard *_selectedEcard = nil;

//============================
@interface SldEcardCell: UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *idLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;

@end

@implementation SldEcardCell

@end

//============================
static __weak SldCouponCardController *_inst = nil;
static int _fetchLimit = 30;

@interface SldCouponCardController ()
@property (nonatomic) NSMutableArray *ecards;
@property (nonatomic) SldLoadMoreCell *loadMoreCell;
@property (nonatomic) SInt64 lastScore;
@end

@implementation SldCouponCardController

+ (instancetype)getInstance {
    return _inst;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _inst = self;
    _ecards = [NSMutableArray array];
    
    //refresh control
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    
    [self refresh];
    
    //login notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onLogin) name:@"login" object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)onLogin {
    [self refresh];
}

- (void)refresh {
    [_ecards removeAllObjects];
    
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"StartId":@0, @"LastScore":@(_lastScore), @"Limit":@(_fetchLimit)};
    [session postToApi:@"player/listMyEcard" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [self.refreshControl endRefreshing];
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        NSArray *ecards = dict[@"Ecards"];
        for (NSDictionary *ecardDict in ecards) {
            SldEcard *ecard = [[SldEcard alloc] initWithDict:ecardDict];
            [_ecards addObject:ecard];
        }
        
        _lastScore = [(NSNumber*)dict[@"LastScore"] longLongValue];
        
        [self.tableView reloadData];
        
        if (ecards.count < _fetchLimit) {
            [_loadMoreCell noMore];
        }
    }];

}

- (void)addEcard:(SldEcard*)ecard {
    [_ecards insertObject:ecard atIndex:0];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:0 inSection:0];
    [self.tableView insertRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return _ecards.count;
    } else {
        return 1;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        SldEcardCell *cell = [tableView dequeueReusableCellWithIdentifier:@"ecardCell" forIndexPath:indexPath];
        
        SldEcard *ecard = _ecards[indexPath.row];
        cell.titleLabel.text = ecard.Title;
        cell.idLabel.text = [NSString stringWithFormat:@"No.%lld", ecard.Id];
        cell.timeLabel.text = ecard.UserGetDate;
        
        return cell;
    } else {
        _loadMoreCell = [tableView dequeueReusableCellWithIdentifier:@"loadMoreCell" forIndexPath:indexPath];
        return _loadMoreCell;
    }
    
    return nil;
}

- (IBAction)onLoadMore:(id)sender {
    [_loadMoreCell startSpin];
    
    SldHttpSession *session = [SldHttpSession defaultSession];
    SInt64 lastId = 0;
    if (_ecards.count > 0) {
        SldEcard *ecard = _ecards.lastObject;
        lastId = ecard.Id;
    }
    NSDictionary *body = @{@"StartId":@(lastId), @"LastScore":@(_lastScore), @"Limit":@(_fetchLimit)};
    [session postToApi:@"player/listMyEcard" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [_loadMoreCell stopSpin];
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        NSArray *ecards = dict[@"Ecards"];
        NSMutableArray *ips = [NSMutableArray array];
        for (NSDictionary *ecardDict in ecards) {
            SldEcard *ecard = [[SldEcard alloc] initWithDict:ecardDict];
            NSIndexPath *ip = [NSIndexPath indexPathForRow:_ecards.count inSection:0];
            [ips addObject:ip];
            [_ecards addObject:ecard];
        }
        
        [self.tableView insertRowsAtIndexPaths:ips withRowAnimation:UITableViewRowAnimationAutomatic];
        
        _lastScore = [(NSNumber*)dict[@"LastScore"] longLongValue];
        
        if (ecards.count < _fetchLimit) {
            [_loadMoreCell noMore];
        }
    }];
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    SldEcardCell *cell = sender;
    NSIndexPath *indexPath = [self.tableView indexPathForCell:cell];
    _selectedEcard = _ecards[indexPath.row];
}

@end

//===============================
@interface SldRechargeController : UIViewController
@property (weak, nonatomic) IBOutlet UITextView *helpTextView;

@end

@implementation SldRechargeController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
    pasteboard.string = _selectedEcard.CouponCode;
    
    [_helpTextView setText:_selectedEcard.HelpText];
}

@end

//===============================
@interface SldRechargeWebController : UIViewController
@property (weak, nonatomic) IBOutlet UIWebView *webView;

@end

@implementation SldRechargeWebController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSURL *url = [NSURL URLWithString:_selectedEcard.RechargeUrl];
    
    NSURLRequest* request = [NSURLRequest requestWithURL:url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:30];
    
    [_webView loadRequest:request];
}

@end

