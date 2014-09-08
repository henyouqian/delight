//
//  SldMyUserPackMenuController.m
//  pin
//
//  Created by 李炜 on 14-8-21.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldMyUserPackMenuController.h"
#import "SldGameData.h"
#import "SldUtil.h"
#import "SldHttpSession.h"
#import "SldGameController.h"
#import "SldConfig.h"

@interface SldMyUserPackMenuController ()
@property (weak, nonatomic) IBOutlet UIButton *playButton;
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic) UITableViewController *tvc;
@property (nonatomic) UIRefreshControl *refreshControl;
@property (nonatomic) SldGameData *gd;
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
    _gd = [SldGameData getInstance];
    [_gd loadPack:_gd.match.packId completion:^(PackInfo *packInfo) {
        _playButton.enabled = YES;
        [_playButton setTitle:@"开始游戏" forState:UIControlStateNormal];
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

- (IBAction)onStartButton:(id)sender {
    NSArray *imageKeys = _gd.packInfo.images;
    __block int localNum = 0;
    NSUInteger totalNum = [imageKeys count];
    if (totalNum == 0) {
        alert(@"Not downloaded", nil);
        return;
    }
    for (NSString *imageKey in imageKeys) {
        if (imageExist(imageKey)) {
            localNum++;
        }
    }
    if (localNum == totalNum) {
        [self enterGame];
        return;
    } else if (localNum < totalNum) {
        NSString *msg = [NSString stringWithFormat:@"%d%%", (int)(100.f*(float)localNum/(float)totalNum)];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"图集下载中..."
                                                        message:msg
                                                       delegate:self
                                              cancelButtonTitle:@"取消"
                                              otherButtonTitles:nil];
        [alert show];
        
        //download
        SldHttpSession *session = [SldHttpSession defaultSession];
        [session cancelAllTask];
        SldConfig *conf = [SldConfig getInstance];
        for (NSString *imageKey in imageKeys) {
            if (!imageExist(imageKey)) {
                [session downloadFromUrl:makeImageServerUrl2(imageKey, conf.UPLOAD_HOST)
                                  toPath:makeImagePath(imageKey)
                                withData:nil completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error, id data)
                 {
                     if (error) {
                         lwError("Download error: %@", error.localizedDescription);
                         [alert dismissWithClickedButtonIndex:0 animated:YES];
                         return;
                     }
                     localNum++;
                     [alert setMessage:[NSString stringWithFormat:@"%d%%", (int)(100.f*(float)localNum/(float)totalNum)]];
                     
                     //download complete
                     if (localNum == totalNum) {
                         [alert dismissWithClickedButtonIndex:0 animated:YES];
                         [self enterGame];
                     }
                 }];
            }
        }
    }
}

- (void)enterGame {
    _gd.gameMode = USERPACK;
    
    SldGameController *controller = [self.storyboard instantiateViewControllerWithIdentifier:@"game"];
    controller.matchSecret = nil;
    
    [self.navigationController pushViewController:controller animated:YES];
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
