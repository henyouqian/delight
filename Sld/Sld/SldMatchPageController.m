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

static const float COMMENT_HEADER_HEIGHT = 36;

@interface SldMatchPageUserCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UIImageView *avatarView;
@property (weak, nonatomic) IBOutlet UILabel *nameLabel;

@end

@implementation SldMatchPageUserCell
- (void)update {
    [_avatarView.layer setMasksToBounds:YES];
    _avatarView.layer.cornerRadius = 5;
    
    SldGameData *gd = [SldGameData getInstance];
    [SldUtil loadAvatar:_avatarView gravatarKey:gd.playerInfo.gravatarKey customAvatarKey:gd.playerInfo.customAvatarKey];
    
    _nameLabel.text = gd.playerInfo.nickName;
}
@end

//============================
@interface SldMatchPageThumbCell : UITableViewCell

@end

@implementation SldMatchPageThumbCell

- (void)update {
    float gap = 3.0;
    float w = (self.frame.size.width - 4 * gap) / 3;
    
    for (UIView *view in self.contentView.subviews) {
        [view removeFromSuperview];
    }
    
    SldGameData *gd = [SldGameData getInstance];
    PackInfo *packInfo = gd.packInfo;
    int imgNum = packInfo.images.count;
    for (int i = 0; i < imgNum; ++i) {
        int row = i / 3;
        int col = i % 3;
        
        float x = (gap+w)*col + gap;
        float y = (gap+w)*row + gap;
        CGRect frame = CGRectMake(x, y, w, w);
        SldAsyncImageView *imageView = [[SldAsyncImageView alloc] initWithFrame:frame];
        imageView.backgroundColor = [UIColor clearColor];
        imageView.contentMode = UIViewContentModeScaleAspectFill;
        imageView.clipsToBounds = YES;
        [self.contentView addSubview:imageView];
        
        NSString *str = packInfo.images[i];
        imageView.alpha = 0.0;
        [imageView asyncLoadUploadImageNoAnimWithKey:str thumbSize:200  showIndicator:NO completion:^{
            [UIView animateWithDuration:0.5 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                imageView.alpha = 1.0;
            } completion:nil];
        }];
    }
}

@end

//============================
enum MatchPageListType {
    LT_REWARD = 0,
    LT_RANK,
    LT_COMMENT
};

@interface SldMatchPageController () <DKScrollingTabControllerDelegate>

@property SldMatchPageThumbCell *thumbCell;
@property int listType;
@property float section2Offset;

@property float rewardOffsetY;
@property float commentOffsetY;
@property float rankOffsetY;

@end

@implementation SldMatchPageController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _listType = LT_COMMENT;
    
    UIBarButtonItem *btnShare = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:nil action:nil];
//    UIBarButtonItem *btnShare = [[UIBarButtonItem alloc] initWithTitle:@"♥︎" style:UIBarButtonItemStylePlain target:nil action:nil];
    UIBarButtonItem *btnRefresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemBookmarks target:nil action:nil];
    [self.navigationItem setRightBarButtonItems:[NSArray arrayWithObjects:btnShare, btnRefresh, nil]];
    
    SldGameData *gd = [SldGameData getInstance];
    //load pack
    [gd loadPack:gd.match.packId completion:^(PackInfo *packInfo) {
        [self.tableView reloadRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:1 inSection:0]] withRowAnimation:UITableViewRowAnimationAutomatic];
        
        [self loadBackground];
    }];
}

- (void)dealloc {
    SldGameData *gd = [SldGameData getInstance];
    gd.packInfo = nil;
}

- (void)loadBackground{
    NSString *bgKey = [SldGameData getInstance].packInfo.coverBlur;
    
    SldAsyncImageView *imageView = [[SldAsyncImageView alloc] initWithFrame:self.tableView.frame];
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    self.tableView.backgroundView = imageView;
    
    [imageView asyncLoadUploadedImageWithKey:bgKey showIndicator:NO completion:^{
        imageView.alpha = 0.0;
        [UIView animateWithDuration:1.f animations:^{
            imageView.alpha = 1.0;
        }];
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.navigationController setToolbarHidden:NO animated:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.navigationController setToolbarHidden:YES animated:YES];
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
            SldGameData *gd = [SldGameData getInstance];
            if (gd.match.imageNum > 0) {
                return 108 * ((gd.match.imageNum-1)/3+1);
            } else {
                if (gd.packInfo) {
                    return 108 * ((gd.packInfo.images.count-1)/3+1);
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
            [cell update];
            return cell;
        } else if (indexPath.row == 1) {
            SldMatchPageThumbCell *cell = [tableView dequeueReusableCellWithIdentifier:@"thumbCell" forIndexPath:indexPath];
            
            [cell update];
            _thumbCell = cell;
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
        CGRect frame = tableView.frame;
        
        UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, frame.size.width, COMMENT_HEADER_HEIGHT)];
        headerView.backgroundColor = [UIColor lightGrayColor];
        
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
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.3 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
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
