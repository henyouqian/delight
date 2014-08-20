//
//  SldMyUserPackMenuController.m
//  pin
//
//  Created by 李炜 on 14-8-21.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldMyUserPackMenuController.h"
#import "SldGameData.h"

@interface SldMyUserPackMenuController ()
@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic) UITableViewController *tvc;
@property (nonatomic) UIRefreshControl *refreshControl;
@end

@implementation SldMyUserPackMenuController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _playButton.enabled = NO;
    [_playButton setTitle:@"读取中..." forState:UIControlStateDisabled];
    
    _tableView.delegate = self;
    _tableView.dataSource = self;
    
    UIEdgeInsets insets = _tableView.contentInset;
    insets.top = 64;
    
    _tableView.contentInset = insets;
    _tableView.scrollIndicatorInsets = insets;
    _tvc = [[UITableViewController alloc]initWithStyle:UITableViewStylePlain];
    [self addChildViewController:_tvc];
    _tvc.tableView = _tableView;
    
    _refreshControl = [[UIRefreshControl alloc] init];
    [_refreshControl addTarget:self action:@selector(updateRanks) forControlEvents:UIControlEventValueChanged];
    _refreshControl.tintColor = [UIColor grayColor];
    _tvc.refreshControl = _refreshControl;
    
    //load pack
    SldGameData *gd = [SldGameData getInstance];
    [gd loadPack:_packId completion:^(PackInfo *packInfo) {
        
    }];
}

- (void)updateRanks {
    
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 10;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"myUserPackMenuCell"];
    return cell;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
