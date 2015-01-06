//
//  SldMatchPageController.m
//  pin
//
//  Created by 李炜 on 14/12/9.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldMatchPageController.h"
#import "SldUtil.h"
#import "DKScrollingTabController.h"
#import "SldGameData.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldHttpSession.h"
#import "SldUserPageController.h"
#import "SldGameController.h"
#import "SldConfig.h"

//=============================
@interface MatchActivity : NSObject

@property PlayerInfoLite *Player;
@property NSString *Text;

@end

@implementation MatchActivity

- (instancetype)initWithDict:(NSDictionary*)dict {
    if (self = [super init]) {
        _Text= [dict objectForKey:@"Text"];
        NSDictionary *playerDict = [dict objectForKey:@"Player"];
        _Player = [[PlayerInfoLite alloc] initWithDict:playerDict];
    }
    return self;
}

@end

//=============================
@interface SldMatchPageUserCell : UITableViewCell

@property (weak, nonatomic) IBOutlet SldAsyncImageView *avatarView;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;

@end

@implementation SldMatchPageUserCell
- (void)update:(SldMatchPageController*)controller {
    PlayerInfo *author = controller.packInfo.author;
    if (author) {
        [_avatarView.layer setMasksToBounds:YES];
        _avatarView.layer.cornerRadius = 5;
        [SldUtil loadAvatar:_avatarView gravatarKey:author.gravatarKey customAvatarKey:author.customAvatarKey];
        _nameLabel.text = author.nickName;
    } else {
        _nameLabel.text = @"";
    }
}
@end

//=============================
@interface MatchPagePhotoBrowserNavController : UINavigationController

@end

@implementation MatchPagePhotoBrowserNavController
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}
@end

//============================
@interface SldMatchPageThumbCell : UITableViewCell
@property UITapGestureRecognizer *gr;
@property (weak) SldMatchPageController *controller;
@property NSMutableArray *lockLabels;
@property NSMutableArray *thumbViews;
@end

@implementation SldMatchPageThumbCell

- (void)installThumbTap:(SldMatchPageController*)controller {
    if (_gr == nil) {
        _controller = controller;
        _gr = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(onThumbTap)];
        _gr.numberOfTapsRequired = 1;
        [self.contentView addGestureRecognizer:_gr];
    }
}

- (void)downloadAllImages:(void(^)(void))complete {
    NSArray *images = _controller.packInfo.images;
    __block int localNum = 0;
    NSUInteger totalNum = [images count];
    for (ImageInfo *image in images) {
        if (imageExist(image.Key)) {
            localNum++;
        }
    }
    
    if (totalNum == localNum) {
        if (complete) {
            complete();
        }
        return;
    }
    
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
    for (ImageInfo *image in images) {
        if (!imageExist(image.Key)) {
            [session downloadFromUrl:[image getUrl]
                              toPath:makeImagePath(image.Key)
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
                     if (complete) {
                         complete();
                     }
                 }
             }];
        }
    }
}

- (void)onThumbTap {
    if (_controller.packInfo == nil) {
        return;
    }
    CGPoint pt = [_gr locationInView:self];
//    SldGameData *gd = [SldGameData getInstance];
    
    int i = 0;
    for (UIView *view in _thumbViews) {
        CGPoint origin = view.frame.origin;
        CGSize size = view.frame.size;
        if (pt.x >= origin.x && pt.x < origin.x+size.width && pt.y >= origin.y && pt.y < origin.y+size.height)
        {
            if (_controller.matchPlay.played) {
//                [[[UIAlertView alloc] initWithTitle:@"我想要..."
//                                            message:nil
//                                   cancelButtonItem:nil
//                                   otherButtonItems:[RIButtonItem itemWithLabel:@"浏览" action:^{
//                    [self downloadAllImages:^{
//                        [_controller openPhotoBrowser:i];
//                        lwInfo(@"%d", i);
//                    }];
//                }],[RIButtonItem itemWithLabel:@"拼图" action:^{
//                    [self downloadAllImages:^{
//                        [_controller enterGame];
//                    }];
//                }],nil] show];
                
                [self downloadAllImages:^{
                    [_controller openPhotoBrowser:i];
                }];
            } else {
                [[[UIAlertView alloc] initWithTitle:@"完成拼图后即可查看大图，现在开始拼？"
                                            message:nil
                                   cancelButtonItem:[RIButtonItem itemWithLabel:@"稍后再说" action:^{
                    // Handle "Cancel"
                }]
                                   otherButtonItems:[RIButtonItem itemWithLabel:@"开拼！" action:^{
                    [self downloadAllImages:^{
                        [_controller enterGame];
                    }];
                }], nil] show];
            }
            
            return;
        }
        i++;
    }
}

- (void)updateLockLabels {
    BOOL show = !_controller.matchPlay.played;
    for (UILabel *label in _lockLabels) {
        if (show) {
            label.text = @"点击解锁";
        } else {
            [UIView animateWithDuration:1.0 animations:^{
                label.alpha = 0.0;
            }];
        }
    }
}

- (void)update {
    PackInfo *packInfo = _controller.packInfo;
    if (!packInfo || self.contentView.subviews.count > 0) {
        return;
    }
    float gap = 3.0;
    float w = (self.frame.size.width - 4 * gap) / 3;
    
    for (UIView *view in self.contentView.subviews) {
        [view removeFromSuperview];
    }
    _lockLabels = [NSMutableArray arrayWithCapacity:16];
    
    int imgNum = (int)packInfo.images.count;
    if (packInfo == nil) {
        return;
    }
    _thumbViews = [NSMutableArray arrayWithCapacity:16];
    for (int i = 0; i < imgNum; ++i) {
        int row = i / 3;
        int col = i % 3;
        
        float x = (gap+w)*col + gap;
        float y = (gap+w)*row + gap;
        CGRect frame = CGRectMake(x, y, w, w);
        
        UILabel *loadingLabel = [[UILabel alloc] initWithFrame:frame];
        [self.contentView addSubview:loadingLabel];
        loadingLabel.text = @"载入中...";
        loadingLabel.textColor = [UIColor lightGrayColor];
        loadingLabel.font = [loadingLabel.font fontWithSize:10];
        loadingLabel.textAlignment = NSTextAlignmentCenter;
        
        SldAsyncImageView *imageView = [[SldAsyncImageView alloc] initWithFrame:frame];
//        imageView.backgroundColor = [UIColor clearColor];
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
        imageView.userInteractionEnabled = YES;
        [self.contentView addSubview:imageView];
        [_thumbViews addObject:imageView];
        
        //
        UILabel *label = [[UILabel alloc]initWithFrame:frame];
        label.textColor = [UIColor whiteColor];
        label.textAlignment = NSTextAlignmentCenter;
        label.font = [label.font fontWithSize:14];
        label.backgroundColor = [UIColor colorWithRed:0 green:0 blue:0 alpha:0.4];
        [self.contentView addSubview:label];
        [_lockLabels addObject:label];
        //            UIImageView *lockImageView = [[UIImageView alloc] initWithFrame:frame];
        //            lockImageView.image = [UIImage imageNamed:@"imageLock.png"];
        if (_controller.matchPlay && !_controller.matchPlay.played) {
            label.hidden = YES;
        }
        
        ImageInfo *image = packInfo.images[i];
        NSString *key = image.Key;
        if (packInfo.thumbs != nil && i < packInfo.thumbs.count) {
            key = packInfo.thumbs[i];
        }
        imageView.alpha = 0.0;
        [imageView asyncLoadUploadImageNoAnimWithKey:key thumbSize:200 showIndicator:NO completion:^{
            [UIView animateWithDuration:0.5 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                imageView.alpha = 1.0;
            } completion:nil];
            [loadingLabel removeFromSuperview];
        }];
        
        //gif?
        BOOL isGif = false;
        if (key.length > 3) {
            NSString *str = [key substringWithRange:NSMakeRange(key.length-3, 3)];
            isGif = [[str lowercaseString] compare:@"gif"] == 0;
        }
        if (isGif) {
            CGRect frame = imageView.frame;
            float gap = 3;
            float w = 26;
            float h = 16;
            frame = CGRectMake(frame.size.width-gap-w, frame.size.height-gap-h, w, h);
            UILabel *label = [[UILabel alloc] initWithFrame:frame];
            [imageView addSubview:label];
            label.backgroundColor = makeUIColor(63, 149, 240, 255);
            label.text = @"GIF";
            label.textAlignment = NSTextAlignmentCenter;
            label.font = [label.font fontWithSize:12];
            label.textColor = [UIColor whiteColor];
        }
    }
}

@end

//============================
@interface SldMatchPageMatchCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIView *bgView;
@property (weak, nonatomic) IBOutlet UILabel *midLabel;
@property (weak, nonatomic) IBOutlet UILabel *bottomLabel;
@property (weak, nonatomic) IBOutlet UILabel *activityLabel;
@property (weak, nonatomic) IBOutlet UIButton *likeButton;
@property (weak, nonatomic) IBOutlet UILabel *likeNumLabel;
@property (weak, nonatomic) IBOutlet UILabel *playNumLabel;
@property (weak, nonatomic) IBOutlet UIButton *editButton;
@property (weak, nonatomic) IBOutlet UIButton *deleteButton;
@end

@implementation SldMatchPageMatchCell

@end

//============================
@interface SldMatchPageActivityCell : UITableViewCell
@property SInt64 userId;
@property (weak, nonatomic) IBOutlet SldAsyncImageView *avatarView;
@property (weak, nonatomic) IBOutlet UILabel *userNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *activityLabel;
@end

@implementation SldMatchPageActivityCell

@end

//============================
@interface SldMatchPageController () <MWPhotoBrowserDelegate>

@property SldMatchPageThumbCell *thumbCell;
@property float section2Offset;

@property float rewardOffsetY;
@property float commentOffsetY;
@property float rankOffsetY;

@property SldGameData *gd;

@property (weak) SldMatchPageMatchCell *matchCell;
@property (nonatomic) MSWeakTimer *secTimer;
@property NSMutableArray *matchLikers;
@property NSMutableArray *activities;

@property (nonatomic) CBStoreHouseRefreshControl *storeHouseRefreshControl;

@end

@implementation SldMatchPageController

- (void)dealloc {
    [_secTimer invalidate];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.tableView.backgroundColor = [UIColor whiteColor];
    
    _gd = [SldGameData getInstance];
    //load pack
    _gd.matchPlay = nil;
    _gd.packInfo = nil;
    _match = _gd.match;
    [_gd loadPack:_match.packId completion:^(PackInfo *packInfo) {
        _packInfo = packInfo;
        _gd.packInfo = packInfo;
        [self refreshDynamicData];
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:1 inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
    }];
    
    self.title = _match.title;
    
    _secTimer = [MSWeakTimer scheduledTimerWithTimeInterval:1.f target:self selector:@selector(onSecTimer) userInfo:nil repeats:YES dispatchQueue:dispatch_get_main_queue()];
    
    //
    CGRect frame = self.tableView.frame;
    frame = CGRectMake(0, 0, frame.size.width, 44);
    UILabel *footer = [[UILabel alloc] initWithFrame:frame];
    self.tableView.tableFooterView = footer;
    footer.font = [footer.font fontWithSize:12];
    footer.textAlignment = NSTextAlignmentCenter;
    footer.textColor = [UIColor grayColor];
    footer.text = @"后面没有了";
    
    //
    _storeHouseRefreshControl = [CBStoreHouseRefreshControl attachToScrollView:self.tableView
                                                                            target:self
                                                                     refreshAction:@selector(refresh) plist:@"storehouse"
                                                                             color:[UIColor orangeColor]
                                                                         lineWidth:4
                                                                        dropHeight:80
                                                                             scale:1
                                                              horizontalRandomness:150
                                                           reverseLoadingAnimation:NO
                                                           internalAnimationFactor:0.7];
}


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (_gd.needRefreshMatchPage) {
        _gd.needRefreshMatchPage = NO;
        [self refresh];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)refresh {
    [self refreshDynamicData];
//    [self refreshActivities];
}

- (void)refreshActivities {
    _activities = [NSMutableArray arrayWithCapacity:20];
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"MatchId":@(_match.id)};
    [session postToApi:@"match/listActivity" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [_storeHouseRefreshControl finishingLoading];
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        for (NSDictionary *recDict in array) {
            MatchActivity *activity = [[MatchActivity alloc] initWithDict:recDict];
            [_activities addObject:activity];
        }
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationAutomatic];
    }];
}

- (void)onSecTimer {
    [self updateMatchCell];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self calcSection1Height];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 3;
    } else if (section == 1) {
        return _activities.count;
    }
    return 0;
}

- (void)calcSection1Height {
    float a = [self tableView:self.tableView heightForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    float b = [self tableView:self.tableView heightForRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]];
    float c = [self tableView:self.tableView heightForRowAtIndexPath:[NSIndexPath indexPathForRow:2 inSection:0]];
    _section2Offset = a + b + c;
    
    CGFloat top = self.navigationController.navigationBar.frame.size.height;
    top += [[UIApplication sharedApplication] statusBarFrame].size.height;
    
    _section2Offset -= top;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            return 48;
        } else if (indexPath.row == 1) { //thumb
            if (_match.imageNum > 0) {
                return 108 * ((_match.imageNum-1)/3+1);
            } else {
                if (_packInfo) {
                    return 108 * ((_packInfo.images.count-1)/3+1);
                } else {
                    return 108 * ((8-1)/3+1);
                }
            }
            
            return 0;
        } else if (indexPath.row == 2) { //match result
            return 154;
        }
    } else if (indexPath.section == 1) {
        return 48;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            SldMatchPageUserCell *cell = [tableView dequeueReusableCellWithIdentifier:@"userCell" forIndexPath:indexPath];
            [cell update:self];
            return cell;
        } else if (indexPath.row == 1) {
            SldMatchPageThumbCell *cell = [tableView dequeueReusableCellWithIdentifier:@"thumbCell" forIndexPath:indexPath];
            _thumbCell = cell;
            [_thumbCell installThumbTap:self];
            [cell update];
            return cell;
        } else if (indexPath.row == 2) {
            _matchCell = [tableView dequeueReusableCellWithIdentifier:@"matchCell" forIndexPath:indexPath];
            if (_activities.count == 0) {
                _matchCell.activityLabel.hidden = YES;
            } else {
                _matchCell.activityLabel.hidden = NO;
            }
            if (_matchPlay) {
                [self setLikeButtonHighlight:_matchPlay.like button:_matchCell.likeButton];
            }
            if (_match.ownerId == _gd.playerInfo.userId) {
                _matchPlay.like = YES;
                [self setLikeButtonHighlight:YES button:_matchCell.likeButton];
                _matchCell.editButton.hidden = NO;
                _matchCell.deleteButton.hidden = NO;
            } else {
                _matchCell.editButton.hidden = YES;
                _matchCell.deleteButton.hidden = YES;
            }
            _matchCell.likeNumLabel.text = [NSString stringWithFormat:@"%d喜欢", _match.likeNum];
            _matchCell.playNumLabel.text = [NSString stringWithFormat:@"%d已玩", _match.playTimes];
            [self updateMatchCell];
            return _matchCell;
        }
    } else if (indexPath.section == 1){
        SldMatchPageActivityCell *cell = [tableView dequeueReusableCellWithIdentifier:@"activityCell" forIndexPath:indexPath];
        if (indexPath.row < _activities.count) {
            MatchActivity *activity = [_activities objectAtIndex:indexPath.row];
            [SldUtil loadAvatar:cell.avatarView gravatarKey:activity.Player.GravatarKey customAvatarKey:activity.Player.CustomAvatarKey];
            cell.userNameLabel.text = activity.Player.NickName;
            cell.activityLabel.text = activity.Text;
            [cell.avatarView.layer setMasksToBounds:YES];
            cell.avatarView.layer.cornerRadius = 5;
            cell.userId = activity.Player.UserId;
        }

        return cell;
    }
    return nil;
}

- (void)updateMatchCell {
    if (_matchCell == nil) {
        return;
    }
    UInt64 now = getServerNowSec();
    BOOL matchEnd = NO;
    if (_match.deleted) {
        _matchCell.bgView.backgroundColor = makeUIColor(150, 150, 150, 255);
        _matchCell.midLabel.text = @"比赛已删除";
        _matchCell.bottomLabel.text = @"";
        return;
    }
    
    if (_match.hasResult || now > _match.endTime) { //closed
        [UIView animateWithDuration:0.8 animations:^{
            _matchCell.bgView.backgroundColor = makeUIColor(121, 135, 136, 255);
        }];
        _matchCell.midLabel.text = @"比赛已结束，点击查看";
        matchEnd = YES;
    } else {
        SInt64 endIntv = _match.endTime - now;
        NSString *timeStr = formatInterval((int)endIntv);
        [UIView animateWithDuration:0.8 animations:^{
            _matchCell.bgView.backgroundColor = makeUIColor(80, 146, 155, 255);
        }];
        _matchCell.midLabel.text = [NSString stringWithFormat:@"比赛进行中，点击进入(%@)", timeStr];
    }
    if (_matchPlay) {
        if (matchEnd) {
            if (_matchPlay.myRank == 0) {
                _matchCell.bottomLabel.text = [NSString stringWithFormat:@"奖金：%d 名次：无", _matchPlay.extraPrize+_match.prize];
            } else {
                _matchCell.bottomLabel.text = [NSString stringWithFormat:@"奖金：%d 名次：%d", _matchPlay.extraPrize+_match.prize, _matchPlay.myRank];
            }
        } else {
            if (_matchPlay.myRank == 0) {
                _matchCell.bottomLabel.text = [NSString stringWithFormat:@"实时奖金：%d 实时名次：无", _matchPlay.extraPrize+_match.prize];
            } else {
                _matchCell.bottomLabel.text = [NSString stringWithFormat:@"实时奖金：%d 实时名次：%d", _matchPlay.extraPrize+_match.prize, _matchPlay.myRank];
            }
        }
    } else {
        _matchCell.midLabel.text = @"";
    }
}
//- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
//    if (section == 1) {
//        NSString *reuseId = @"headerView";
//        UITableViewHeaderFooterView *headerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:reuseId];
//        if (headerView) {
//            return headerView;
//        }
//        
//        CGRect frame = tableView.frame;
//        
//        headerView = [[UITableViewHeaderFooterView alloc] initWithReuseIdentifier:reuseId];
//        headerView.frame = CGRectMake(0, 0, frame.size.width, COMMENT_HEADER_HEIGHT);
//        
//        //
//        DKScrollingTabController *tabController = [[DKScrollingTabController alloc] init];
//        tabController.delegate = self;
//        
//        [self addChildViewController:tabController];
//        [tabController didMoveToParentViewController:self];
//        [headerView addSubview:tabController.view];
//        tabController.view.backgroundColor = [UIColor whiteColor];
//        tabController.view.frame = CGRectMake(0, 0, frame.size.width, COMMENT_HEADER_HEIGHT);
//        
//        // controller customization
//        tabController.selectionFont = [UIFont boldSystemFontOfSize:12];
//        tabController.buttonInset = 30;
//        tabController.buttonPadding = 4;
//        tabController.firstButtonInset = 30;
//        
//        tabController.translucent = YES; // experimental, this overrides background colors
//        //[tabController addTopBorder:[UIColor grayColor]]; // this might be needed depending on the background view
//        
//        frame = tabController.toolbar.frame;
//        frame.size.width = 12000;
//        tabController.toolbar.frame = frame;
//        
//        //remove scroll bar
//        tabController.buttonsScrollView.showsHorizontalScrollIndicator = NO;
//        
//        //add indicator
//        tabController.selectedTextColor = [UIColor orangeColor];
//        tabController.underlineIndicator = YES; // the color is from selectedTextColor property
//        
//        //this has to be done after customization
//        tabController.selection = @[@"奖励", @"排行榜", @"喜欢"];
//        
//        [tabController selectButtonWithIndex:_listType];
//        
//        return headerView;
//    }
//    return nil;
//}

//- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
//    if (scrollView.contentOffset.y < _section2Offset) {
//        _rewardOffsetY = 0;
//        _commentOffsetY = 0;
//        _rankOffsetY = 0;
//    } else {
//        if (_listType == LT_REWARD) {
//            _rewardOffsetY = scrollView.contentOffset.y;
//        } else if (_listType == LT_LIKE) {
//            _commentOffsetY = scrollView.contentOffset.y;
//        } else if (_listType == LT_RANK) {
//            _rankOffsetY = scrollView.contentOffset.y;
//        }
//    }
//}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self.storeHouseRefreshControl scrollViewDidScroll];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    [self.storeHouseRefreshControl scrollViewDidEndDragging];
}

#pragma mark - MWPhotoBrowser
- (void)openPhotoBrowser:(int)imageIndex {
    MWPhotoBrowser *browser = [[MWPhotoBrowser alloc] initWithDelegate:self];
    
    // Set options
    browser.displayActionButton = YES; // Show action button to allow sharing, copying, etc (defaults to YES)
    browser.displayNavArrows = NO; // Whether to display left and right nav arrows on toolbar (defaults to NO)
    browser.displaySelectionButtons = NO; // Whether selection buttons are shown on each image (defaults to NO)
    browser.zoomPhotosToFill = NO; // Images that almost fill the screen will be initially zoomed to fill (defaults to YES)
    browser.alwaysShowControls = NO; // Allows to control whether the bars and controls are always visible or whether they fade away to show the photo full (defaults to NO)
    browser.enableGrid = NO; // Whether to allow the viewing of all the photo thumbnails on a grid (defaults to YES)
    browser.startOnGrid = NO; // Whether to start on the grid of thumbnails instead of the first photo (defaults to NO)
    
    // Optionally set the current visible photo before displaying
    [browser setCurrentPhotoIndex:imageIndex];
    
    // Present
    //[self.navigationController pushViewController:browser animated:YES];
    MatchPagePhotoBrowserNavController *nc = [[MatchPagePhotoBrowserNavController alloc] initWithRootViewController:browser];
    nc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:nc animated:YES completion:nil];
}

- (void)enterGame {
    _gd.gameMode = M_PRACTICE;
    SldGameController *controller = [self.storyboard instantiateViewControllerWithIdentifier:@"game"];
    
    [self.navigationController pushViewController:controller animated:YES];
}

- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser {
    return _packInfo.images.count;
}

- (id <MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index {
    ImageInfo *imageInfo = [_packInfo.images objectAtIndex:index];
    if (!imageInfo) {
        return nil;
    }
    
    NSString *localPath = makeImagePath(imageInfo.Key);
    MWPhoto *photo = [MWPhoto photoWithURL:[NSURL fileURLWithPath:localPath]];
    return photo;
}

- (void)setLikeButtonHighlight:(BOOL)highlight button:(UIButton*)button {
    UIImage *image = nil;
    if (highlight) {
        image = [UIImage imageNamed:@"heart48.png"];
    } else {
        image = [UIImage imageNamed:@"heartEmpty48.png"];
    }
    [button setImage:image forState:UIControlStateNormal];
}

- (IBAction)onLikeButton:(id)sender {
    UIButton *btn = sender;
    btn.userInteractionEnabled = NO;
    NSString *postUrl = nil;
    if (_matchPlay.like) {
        postUrl = @"match/unlike";
        if (_match.ownerId == _gd.playerInfo.userId) {
            alert(@"自己的没有办法不喜欢啊😂", nil);
            btn.userInteractionEnabled = YES;
            return;
        }
        [self setLikeButtonHighlight:NO button:btn];
    } else {
        [self setLikeButtonHighlight:YES button:btn];
        postUrl = @"match/like";
    }
    
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"MatchId":@(_match.id)};
    [session postToApi:postUrl body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        btn.userInteractionEnabled = YES;
        if (error) {
            [self setLikeButtonHighlight:_matchPlay.like button:btn];
            alertHTTPError(error, data);
            return;
        }
        _matchPlay.like = !_matchPlay.like;
        
        //
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.mode = MBProgressHUDModeText;
        if (_matchPlay.like) {
            hud.labelText = @"❤️喜欢了这组拼图";
        } else {
            hud.labelText = @"💔";
        }
        
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                [MBProgressHUD hideHUDForView:self.view animated:YES];
        });
    }];
}

- (void)refreshDynamicData {
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"MatchId":@(_match.id)};
    [session postToApi:@"match/getDynamicData" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [_storeHouseRefreshControl finishingLoading];
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        _matchPlay = [[MatchPlay alloc] initWithDict:dict];
        
        _gd.matchPlay = _matchPlay;
        _match.extraPrize = _matchPlay.extraPrize;
        _match.playTimes = _matchPlay.playTimes;
        _match.likeNum = _matchPlay.likeNum;
        
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0], [NSIndexPath indexPathForRow:2 inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
        
        [_thumbCell updateLockLabels];
        
        [self refreshActivities];
    }];
}

//- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser didDisplayPhotoAtIndex:(NSUInteger)index {
//    CommentHeaderCell *cell = (CommentHeaderCell*)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
//    _currPage = (int)index + 1;
//    //    if (cell) {
//    //        [cell.pageControl setCurrentPage:_currPage];
//    //    }
//    
//    CGRect frame = cell.scrollView.frame;
//    frame.origin.x = cell.scrollView.frame.size.width * _currPage;
//    frame.origin.y = 0;
//    [cell.scrollView scrollRectToVisible:frame animated:NO];
//    
//    [self scrollViewDidScroll:cell.scrollView];
//}



/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

#pragma mark - Navigation

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    if ([identifier compare:@"segueMatch"] == 0) {
        if (_gd.packInfo == nil || _matchPlay == nil) {
            return NO;
        }
        if (_match.deleted) {
            return NO;
        }
    } else if ([identifier compare:@"segueActivity"] == 0) {
        //get playerInfo
        SldHttpSession *session = [SldHttpSession defaultSession];
        SldMatchPageActivityCell *cell = sender;
        NSDictionary *body = @{@"UserId":@(cell.userId)};
        [session postToApi:@"player/getInfo" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                alertHTTPError(error, data);
                return;
            }
            
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error) {
                lwError("Json error:%@", [error localizedDescription]);
                return;
            }
            PlayerInfo *playerInfo = [PlayerInfo playerWithDictionary:dict];
            
            SldUserPageController* vc = [getStoryboard() instantiateViewControllerWithIdentifier:@"userPageController"];
            vc.playerInfo = playerInfo;
            [self.navigationController pushViewController:vc animated:YES];
        }];
        return NO;
    }
    return YES;
}

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if (segue.identifier == nil) {
        return;
    }
    
    if ([segue.identifier compare:@"segueUser"] == 0) {
        SldUserPageController *vc = segue.destinationViewController;
        vc.playerInfo = _packInfo.author;
    } else if ([segue.identifier compare:@"segueMatch"] == 0) {
        _gd.match = _match;
    } else if ([segue.identifier compare:@"segueMatchEdit"] == 0) {
        
    }
}

- (IBAction)onShareButton:(id)sender {
    SldHttpSession *session = [SldHttpSession defaultSession];
    int msec = 0;
    if (_gd.matchPlay) {
        msec = -_gd.matchPlay.highScore;
    }
    
    UIAlertView* alt = alertNoButton(@"生成中...");
    NSDictionary *body = @{@"PackId":@(_gd.match.packId), @"SliderNum":@(_gd.match.sliderNum), @"Msec":@(msec)};
    [session postToApi:@"social/newPack" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [alt dismissWithClickedButtonIndex:0 animated:YES];
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        NSString *key = [dict objectForKey:@"Key"];
        
        //
        NSString *path = makeImagePath(_gd.match.thumb);
        UIImage *image = [UIImage imageWithContentsOfFile:path];
        NSString *url = [NSString stringWithFormat:@"%@?key=%@", [SldConfig getInstance].HTML5_URL, key];
        
        [[[UIAlertView alloc] initWithTitle:@"分享这组拼图给朋友，朋友可以点开链接直接玩。"
                                    message:nil
                           cancelButtonItem:[RIButtonItem itemWithLabel:@"好的" action:^{
            NSString *weixinText = [NSString stringWithFormat:@"看看你的手有多快。"];
            if (_gd.matchPlay && _gd.matchPlay.highScore != 0) {
                weixinText = [NSString stringWithFormat:@"我只用了%@就拼好了这些图，敢来挑战么？", formatScore(_gd.matchPlay.highScore)];
            }
            UMSocialData *umData = [UMSocialData defaultData];
            umData.extConfig.title = @"";
            umData.extConfig.wechatSessionData.url = url;
            umData.extConfig.wechatSessionData.shareText = weixinText;
            NSString *text = [NSString stringWithFormat:@"%@\n%@", weixinText, url];
            [UMSocialSnsService presentSnsIconSheetView:self
                                                 appKey:nil
                                              shareText:text
                                             shareImage:image
                                        shareToSnsNames:@[UMShareToWechatSession,UMShareToWechatTimeline,UMShareToSina,UMShareToTencent, UMShareToDouban, UMShareToQzone]
                                               delegate:nil];
        }]
                           otherButtonItems:nil] show];
    }];
}

- (IBAction)onDeleteButton:(id)sender {
    [[[UIAlertView alloc] initWithTitle:@"删除这组拼图吗？"
                                message:@"注意，如比赛未结束，提供的奖金不退还，并在结束后正常分发奖金。"
                       cancelButtonItem:[RIButtonItem itemWithLabel:@"取消" action:^{
        // Handle "Cancel"
    }]
                       otherButtonItems:[RIButtonItem itemWithLabel:@"删除！" action:^{
        SldHttpSession *session = [SldHttpSession defaultSession];
        NSDictionary *body = @{@"MatchId":@(_match.id)};
        [session postToApi:@"match/del" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                alertHTTPError(error, data);
                return;
            }
            _match.deleted = YES;
        }];

    }], nil] show];
}

@end
