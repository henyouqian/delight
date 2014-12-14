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

static const float COMMENT_HEADER_HEIGHT = 36;

@interface SldMatchPageUserCell : UITableViewCell

@property (weak, nonatomic) IBOutlet SldAsyncImageView *avatarView;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;
@property (weak, nonatomic) IBOutlet UIButton *likeButton;

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
@property SldMatchPageController *controller;
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

- (void)onThumbTap {
    if (_controller.packInfo == nil) {
        return;
    }
    CGPoint pt = [_gr locationInView:self];
    
    int i = 0;
    for (UIView *view in self.contentView.subviews) {
        CGPoint origin = view.frame.origin;
        CGSize size = view.frame.size;
        if (pt.x >= origin.x && pt.x < origin.x+size.width && pt.y >= origin.y && pt.y < origin.y+size.height) {
            //[self openPhotoBrowser:i];
            [_controller openPhotoBrowser:i];
            break;
        }
        i++;
    }
}

- (void)update {
    float gap = 3.0;
    float w = (self.frame.size.width - 4 * gap) / 3;
    
    for (UIView *view in self.contentView.subviews) {
        [view removeFromSuperview];
    }
    
    PackInfo *packInfo = _controller.packInfo;
    int imgNum = packInfo.images.count;
    if (packInfo == nil) {
        return;
    }
    for (int i = 0; i < imgNum; ++i) {
        int row = i / 3;
        int col = i % 3;
        
        float x = (gap+w)*col + gap;
        float y = (gap+w)*row + gap;
        CGRect frame = CGRectMake(x, y, w, w);
        
        UILabel *loadingLabel = [[UILabel alloc] initWithFrame:frame];
        [self.contentView addSubview:loadingLabel];
        loadingLabel.text = @"Loading...";
        loadingLabel.textColor = [UIColor lightGrayColor];
        loadingLabel.font = [loadingLabel.font fontWithSize:10];
        loadingLabel.textAlignment = NSTextAlignmentCenter;
        
        SldAsyncImageView *imageView = [[SldAsyncImageView alloc] initWithFrame:frame];
//        imageView.backgroundColor = [UIColor clearColor];
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
        imageView.userInteractionEnabled = YES;
        [self.contentView addSubview:imageView];
        
        NSString *imgKey = packInfo.images[i];
        imageView.alpha = 0.0;
        [imageView asyncLoadUploadImageNoAnimWithKey:imgKey thumbSize:200 showIndicator:NO completion:^{
            [UIView animateWithDuration:0.5 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                imageView.alpha = 1.0;
            } completion:nil];
            [loadingLabel removeFromSuperview];
        }];
        
        //gif?
        BOOL isGif = false;
        if (imgKey.length > 3) {
            NSString *str = [imgKey substringWithRange:NSMakeRange(imgKey.length-3, 3)];
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
enum MatchPageListType {
    LT_REWARD = 0,
    LT_RANK,
    LT_COMMENT
};

@interface SldMatchPageController () <DKScrollingTabControllerDelegate, MWPhotoBrowserDelegate>

@property SldMatchPageThumbCell *thumbCell;
@property int listType;
@property float section2Offset;

@property float rewardOffsetY;
@property float commentOffsetY;
@property float rankOffsetY;

@property SldGameData *gd;

@end

@implementation SldMatchPageController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _listType = LT_COMMENT;
    
    UIBarButtonItem *btnShare = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:nil action:nil];
//    UIBarButtonItem *btnShare = [[UIBarButtonItem alloc] initWithTitle:@"♥︎" style:UIBarButtonItemStylePlain target:nil action:nil];
//    UIImage *likeImage = [UIImage imageNamed:@"heart48.png"];
//    UIBarButtonItem *btnLike = [[UIBarButtonItem alloc] initWithImage:likeImage style:UIBarButtonItemStylePlain target:nil action:nil];
    [self.navigationItem setRightBarButtonItems:[NSArray arrayWithObjects:btnShare, nil]];
    
    _gd = [SldGameData getInstance];
    //load pack
    _gd.matchPlay = nil;
    _gd.packInfo = nil;
    _match = _gd.match;
    [_gd loadPack:_match.packId completion:^(PackInfo *packInfo) {
        _packInfo = packInfo;
        [self refreshDynamicData];
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:1 inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
        if (_listType == LT_REWARD) {
            return 10;
        } else if (_listType == LT_COMMENT) {
            return 15;
        } else if (_listType == LT_RANK) {
            return 20;
        }
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
            return 64;
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
            return 80;
        }
    } else if (indexPath.section == 1) {
        return 84;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *cellId = @"";
    if (indexPath.section == 0) {
        if (indexPath.row == 0) {
            SldMatchPageUserCell *cell = [tableView dequeueReusableCellWithIdentifier:@"userCell" forIndexPath:indexPath];
            [cell update:self];
            if (_matchPlay) {
                [self setLikeButtonHighlight:_matchPlay.like button:cell.likeButton];
            }
            return cell;
        } else if (indexPath.row == 1) {
            SldMatchPageThumbCell *cell = [tableView dequeueReusableCellWithIdentifier:@"thumbCell" forIndexPath:indexPath];
            _thumbCell = cell;
            [_thumbCell installThumbTap:self];
            [cell update];
            return cell;
        } else if (indexPath.row == 2) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"resultCell" forIndexPath:indexPath];
            return cell;
        }
    } else if (indexPath.section == 1){
        if (_listType == LT_COMMENT) {
            cellId = @"commentCell";
        } else if (_listType == LT_REWARD) {
            cellId = @"rewardCell";
        }else {
            cellId = @"rankCell";
        }
    }
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellId forIndexPath:indexPath];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if (section == 1) {
        return COMMENT_HEADER_HEIGHT;
    }
    return 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 1) {
        NSString *reuseId = @"headerView";
        UITableViewHeaderFooterView *headerView = [tableView dequeueReusableHeaderFooterViewWithIdentifier:reuseId];
        if (headerView) {
            return headerView;
        }
        
        CGRect frame = tableView.frame;
        
        headerView = [[UITableViewHeaderFooterView alloc] initWithReuseIdentifier:reuseId];
        headerView.frame = CGRectMake(0, 0, frame.size.width, COMMENT_HEADER_HEIGHT);
//        headerView.contentView.backgroundColor = [UIColor lightGrayColor];
        
        //
        DKScrollingTabController *tabController = [[DKScrollingTabController alloc] init];
        tabController.delegate = self;
        
        [self addChildViewController:tabController];
        [tabController didMoveToParentViewController:self];
        [headerView addSubview:tabController.view];
        tabController.view.backgroundColor = [UIColor whiteColor];
        tabController.view.frame = CGRectMake(0, 0, frame.size.width, COMMENT_HEADER_HEIGHT);
        
        // controller customization
        tabController.selectionFont = [UIFont boldSystemFontOfSize:12];
        tabController.buttonInset = 30;
        tabController.buttonPadding = 4;
        tabController.firstButtonInset = 30;
        
        tabController.translucent = YES; // experimental, this overrides background colors
        //[tabController addTopBorder:[UIColor grayColor]]; // this might be needed depending on the background view
        
        frame = tabController.toolbar.frame;
        frame.size.width = 12000;
        tabController.toolbar.frame = frame;
        
        //remove scroll bar
        tabController.buttonsScrollView.showsHorizontalScrollIndicator = NO;
        
        //add indicator
        tabController.selectedTextColor = [UIColor orangeColor];
        tabController.underlineIndicator = YES; // the color is from selectedTextColor property
        
        //this has to be done after customization
        tabController.selection = @[@"奖励", @"排行榜", @"评论"];
        
        [tabController selectButtonWithIndex:_listType];
        
        return headerView;
    }
    return nil;
}

- (void)DKScrollingTabController:(DKScrollingTabController *)controller selection:(NSUInteger)selection {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        _listType = selection;
//        [self.tableView reloadData];
        [UIView setAnimationsEnabled:NO];
        [self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1] withRowAnimation:UITableViewRowAnimationNone];
        [UIView setAnimationsEnabled:YES];
        
        lwInfo("%f", self.tableView.contentOffset.y);
        if (self.tableView.contentOffset.y >= _section2Offset) {
            if (_listType == LT_REWARD) {
                if (_rewardOffsetY > _section2Offset) {
                    [self.tableView setContentOffset:CGPointMake(0, _rewardOffsetY)];
                } else {
                    [self.tableView setContentOffset:CGPointMake(0, _section2Offset)];
                }
            } else if (_listType == LT_COMMENT) {
                if (_commentOffsetY > _section2Offset) {
                    [self.tableView setContentOffset:CGPointMake(0, _commentOffsetY)];
                } else {
                    [self.tableView setContentOffset:CGPointMake(0, _section2Offset)];
                }
            } else if (_listType == LT_RANK) {
                if (_rankOffsetY > _section2Offset) {
                    [self.tableView setContentOffset:CGPointMake(0, _rankOffsetY)];
                } else {
                    [self.tableView setContentOffset:CGPointMake(0, _section2Offset)];
                }
            }
        }
    });
}


- (IBAction)onPracticeButton:(id)sender {

}

- (IBAction)onMatchButton:(id)sender {
    
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (scrollView.contentOffset.y < _section2Offset) {
        _rewardOffsetY = 0;
        _commentOffsetY = 0;
        _rankOffsetY = 0;
    } else {
        if (_listType == LT_REWARD) {
            _rewardOffsetY = scrollView.contentOffset.y;
        } else if (_listType == LT_COMMENT) {
            _commentOffsetY = scrollView.contentOffset.y;
        } else if (_listType == LT_RANK) {
            _rankOffsetY = scrollView.contentOffset.y;
        }
    }
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

- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser {
    return _packInfo.images.count;
}

- (id <MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index {
    NSString *imageKey = [_packInfo.images objectAtIndex:index];
    if (!imageKey) {
        return nil;
    }
    NSString *localPath = makeImagePath(imageKey);
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
    }];
}

- (void)refreshDynamicData {
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"MatchId":@(_match.id)};
    [session postToApi:@"match/getDynamicData" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
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
        
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:0 inSection:0]] withRowAnimation:UITableViewRowAnimationNone];
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

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
