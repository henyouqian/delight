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
}

- (void)refresh {
    [_ecards removeAllObjects];
    
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"StartId":@0, @"Limit":@(_fetchLimit)};
    [session postToApi:@"player/listMyEcard" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [self.refreshControl endRefreshing];
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        for (NSDictionary *dict in array) {
            SldEcard *ecard = [[SldEcard alloc] initWithDict:dict];
            [_ecards addObject:ecard];
        }
        
        [self.tableView reloadData];
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
    [_loadMoreCell.spin startAnimating];
    _loadMoreCell.spin.hidden = NO;
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

