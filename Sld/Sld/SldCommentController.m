//
//  SldCommentController.m
//  Sld
//
//  Created by Wei Li on 14-5-9.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldCommentController.h"
#import "SldNevigationController.h"
#import "SldHttpSession.h"
#import "SldGameData.h"
#import "SldAddCommentController.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldUtil.h"

//CommentHeaderCell
@interface CommentHeaderCell : UITableViewCell
@property (strong, nonatomic) IBOutlet UIScrollView *scrollView;
@property (strong, nonatomic) IBOutlet UIPageControl *pageControl;
@end

@implementation CommentHeaderCell
- (void)dealloc {
    
}
@end


//CommentCell
@interface CommentCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UIImageView *iconView;
@property (weak, nonatomic) IBOutlet UILabel *userNameLabel;
@end

@implementation CommentCell

@end


//Comment
@interface CommentData : NSObject
@property (nonatomic) UInt64 id;
@property (nonatomic) UInt64 userId;
@property (nonatomic) NSString *userName;
@property (nonatomic) NSString *gravatarKey;
@property (nonatomic) NSString *customAvatarKey;
@property (nonatomic) NSString *team;
@property (nonatomic) NSString *text;
@end

@implementation CommentData
+ (instancetype)commentDataWithDictionary:(NSDictionary*)dict {
    CommentData *data = [[CommentData alloc] init];
    NSNumber *nId = [dict objectForKey:@"Id"];
    if (nId) {
        data.id = [nId unsignedLongLongValue];
    }
    NSNumber *nUserId = [dict objectForKey:@"UserId"];
    if (nUserId) {
        data.userId = [nUserId unsignedLongLongValue];
    }
    data.userName = [dict objectForKey:@"UserName"];
    data.gravatarKey = [dict objectForKey:@"GravatarKey"];
    data.customAvatarKey = [dict objectForKey:@"CustomAvatarKey"];
    data.team = [dict objectForKey:@"Team"];
    data.text = [dict objectForKey:@"Text"];
    
    
    return data;
}
@end

//
@interface PhotoBrowserNavController : UINavigationController

@end

@implementation PhotoBrowserNavController
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}
@end

//SldCommentController
@interface SldCommentController ()
@property (nonatomic) NSMutableArray *commentDatas;
@property (nonatomic) UITableViewController *tableViewController;
@property (nonatomic) BOOL ready;
@property (nonatomic) NSMutableDictionary *photos;
@property (weak, nonatomic) SldGameData *gameData;
@property (nonatomic) int currPage;
@property (nonatomic) CommentHeaderCell *imageSlideCell;
@property (nonatomic) NSString *commentText;
@property (weak, nonatomic) IBOutlet UIImageView *bgImageView;
@property (nonatomic) NSMutableArray *imageViews;
@end

@implementation SldCommentController

- (void)dealloc {
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _gameData = [SldGameData getInstance];
    _ready = NO;
    _photos = [NSMutableDictionary dictionary];
    _currPage = 1;
    
    _tableView.delegate = self;
    _tableView.dataSource = self;
    
    //set tableView inset
    int navBottomY = [SldNevigationController getBottomY];
    _tableView.contentInset = UIEdgeInsetsMake(navBottomY, 0, 100, 0);
    _tableView.scrollIndicatorInsets = UIEdgeInsetsMake(navBottomY, 0, 100, 0);
    _tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    
    //refreshControl
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(updateComments) forControlEvents:UIControlEventValueChanged];
    refreshControl.tintColor = [UIColor whiteColor];
    
    _tableViewController = [[UITableViewController alloc] init];
    _tableViewController.tableView = _tableView;
    _tableViewController.refreshControl = refreshControl;
    
    //
    [self loadBackground];
    
    //
    if (_commentDatas == nil) {
        [self updateComments];
    }
    
    _ready = YES;
}

- (void)onViewShown {
    if (_commentDatas == nil) {
        [self updateComments];
    }
    
    _ready = YES;
}

- (void)updateComments {
    SldGameData *gameData = [SldGameData getInstance];
    NSDictionary *body = @{@"PackId":@(gameData.packInfo.id), @"Key": @0, @"Limit": @20};
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"pack/getComments" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [_tableViewController.refreshControl endRefreshing];
        if (error) {
            lwError("Http error:%@", [error localizedDescription]);
            return;
        }
        NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        _commentDatas = [NSMutableArray arrayWithCapacity:[array count]];
        for (NSDictionary *dict in array) {
            CommentData *commentData = [CommentData commentDataWithDictionary:dict];
            [_commentDatas addObject:commentData];
        }
        [_tableView reloadData];
    }];
}

- (void)loadBackground{
    NSString *bgKey = [SldGameData getInstance].packInfo.coverBlur;
    
    BOOL imageExistLocal = imageExist(bgKey);
    NSString* localPath = makeImagePath(bgKey);
    if (imageExistLocal) {
        _bgImageView.image = [UIImage imageWithContentsOfFile:localPath];
    } else {
        [_bgImageView asyncLoadImageWithKey:bgKey showIndicator:NO completion:^{
            _bgImageView.alpha = 0.0;
            [UIView animateWithDuration:1.f animations:^{
                _bgImageView.alpha = 1.0;
            }];
        }];
    }
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 1;
    } else if (section == 1) {
        return [_commentDatas count]+1;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        SldGameData *gameData = [SldGameData getInstance];
        
        CommentHeaderCell *cell = [tableView dequeueReusableCellWithIdentifier:@"commentImageCell" forIndexPath:indexPath];
        cell.scrollView.scrollsToTop = NO;
        if (!_ready) {
            return cell;
        }
        if (_imageSlideCell) {
            for ( UIView *view in _imageSlideCell.scrollView.subviews) {
                if ([view isKindOfClass:[UIImageView class]]) {
                    UIImageView *imageView = (UIImageView *)view;
                    [imageView startAnimating];
                }
            }
            return _imageSlideCell;
        }
        _imageSlideCell = cell;
        cell.scrollView.delegate = self;
        cell.pageControl.currentPage = 0;
        NSMutableArray *images = gameData.packInfo.images;
        cell.pageControl.numberOfPages = [images count]+1;
        
        //desc
        CGRect frame;
        frame.origin.x = 0;
        frame.origin.y = 0;
        frame.size = cell.frame.size;
        //frame.size.height = frame.size.height - 40;
        UITextView *textView = [[UITextView alloc] initWithFrame:frame];
        textView.text = gameData.packInfo.text;
        textView.textColor = [UIColor whiteColor];
        textView.font = [UIFont fontWithName:@"HelveticaNeue" size:14];
        textView.backgroundColor = [UIColor clearColor];
        textView.editable = false;
        [cell.scrollView addSubview:textView];
        
        //image
        int imageIndex = 0;
        _imageViews = [NSMutableArray array];
        for(NSString *imageKey in images) {
            CGRect frame;
            frame.origin.x = (cell.scrollView.frame.size.width) * (imageIndex+1);
            frame.origin.y = 0;
            frame.size = cell.frame.size;
            //frame = CGRectInset(frame, 5.0, 0.0);
            
            SldAsyncImageView *imageView = [[SldAsyncImageView alloc] initWithImage:nil];
            imageView.contentMode = UIViewContentModeScaleAspectFit;
            imageView.frame = frame;
            [cell.scrollView addSubview:imageView];
            if (imageIndex <= 1) {
                [imageView asyncLoadImageWithKey:imageKey showIndicator:YES completion:nil];
            }
            [_imageViews addObject:imageView];
            
            imageIndex++;
        }
        CGSize pageScrollViewSize = cell.scrollView.frame.size;
        cell.scrollView.contentSize = CGSizeMake(pageScrollViewSize.width * (images.count+1), pageScrollViewSize.height);
        
        //set second page present
        [cell.pageControl setCurrentPage:1];
        
        frame = cell.scrollView.frame;
        frame.origin.x = frame.size.width;
        frame.origin.y = 0;
        [cell.scrollView scrollRectToVisible:frame animated:NO];
        
        //tap gesture
        UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singleTapGestureCaptured:)];
        singleTap.cancelsTouchesInView = NO;
        [cell.scrollView addGestureRecognizer:singleTap];
        
        return cell;
    } else if (indexPath.section == 1) {
        if (indexPath.row >= [_commentDatas count]) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"moreCommentCell" forIndexPath:indexPath];
            return cell;
        }
        
        CommentCell *cell = [tableView dequeueReusableCellWithIdentifier:@"commentCell" forIndexPath:indexPath];
        cell.textView.scrollsToTop = NO;
        
        CommentData* commentData = [_commentDatas objectAtIndex:indexPath.row];
        cell.textView.text = commentData.text;
        cell.userNameLabel.text = commentData.userName;
        
        
        [SldUtil loadAvatar:cell.iconView gravatarKey:commentData.gravatarKey customAvatarKey:commentData.customAvatarKey];
        
        return cell;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return 280;
    } else if (indexPath.section == 1) {
        if (indexPath.row >= [_commentDatas count]) {
            return 60;
        }
        CommentData* commentData = [_commentDatas objectAtIndex:indexPath.row];
        float h = [self textHeightForText:commentData.text width:250 fontName:@"HelveticaNeue" fontSize:14];
        return MAX(h+22+10, 68);
    }
    return 0;
}

- (float)textHeightForText:(NSString*)text width:(float)width fontName:(NSString*)fontName fontSize:(float)fontSize {
    UIFont *font = nil;
    if (fontName == nil) {
        font = [UIFont systemFontOfSize:fontSize];
    } else {
        font = [UIFont fontWithName:fontName size:fontSize];
    }
    NSDictionary *attributes = [NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName];
    NSAttributedString *string = [[NSAttributedString alloc] initWithString:text attributes:attributes];
    return [self textViewHeightForAttributedText:string andWidth:width];
}

- (CGFloat)textViewHeightForAttributedText: (NSAttributedString*)text andWidth: (CGFloat)width {
    UITextView *calculationView = [[UITextView alloc] init];
    [calculationView setAttributedText:text];
    CGSize size = [calculationView sizeThatFits:CGSizeMake(width, FLT_MAX)];
    return size.height;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString *sectionName;
    switch (section) {
        case 0:
            sectionName = NSLocalizedString(@"图集", @"图集");
            break;
        case 1:
            sectionName = NSLocalizedString(@"评论", @"评论");
            break;
        default:
            sectionName = @"";
            break;
    }
    return sectionName;
}

-(void) scrollViewDidScroll:(UIScrollView *)scrollView
{
    CommentHeaderCell *cell = (CommentHeaderCell*)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    if (cell == nil) {
        return;
    }
    CGFloat pageWidth = cell.frame.size.width;
    _currPage = floor((cell.scrollView.contentOffset.x + pageWidth/2)/pageWidth);
    if (cell.pageControl.currentPage != _currPage) {
        cell.pageControl.currentPage = _currPage;
        
        //load image
        int currImageIdx = _currPage - 1;
        for (int i = 0; i < _imageViews.count; i++) {
            SldAsyncImageView *imageView = _imageViews[i];
            if (i >= currImageIdx-1 && i <= currImageIdx+1) {
                NSMutableArray *imageKeys = _gameData.packInfo.images;
                if (!imageView.image) {
                    [imageView asyncLoadImageWithKey:imageKeys[i] showIndicator:YES completion:^{
                        lwInfo("%d", i);
                    }];
                }
            } else {
                [imageView releaseImage];
            }
        }
    }
}

- (void)singleTapGestureCaptured:(UITapGestureRecognizer *)gesture {
    if (_currPage == 0) {
        return;
    }
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
    [browser setCurrentPhotoIndex:_currPage-1];
    
    // Present
    //[self.navigationController pushViewController:browser animated:YES];
    PhotoBrowserNavController *nc = [[PhotoBrowserNavController alloc] initWithRootViewController:browser];
    nc.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
    [self presentViewController:nc animated:YES completion:nil];}

- (void)onSendComment {
    _commentText = nil;
    [self updateComments];
}

- (IBAction)cancelComment:(UIStoryboardSegue *)segue {
    SldAddCommentController* vc = (SldAddCommentController*)segue.sourceViewController;
    _commentText = vc.textView.text;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier compare:@"addComment"] == 0) {
        SldAddCommentController* vc = (SldAddCommentController*)segue.destinationViewController;
        vc.restoreText = _commentText;
        vc.commentController = self;
    }
}

- (NSUInteger)numberOfPhotosInPhotoBrowser:(MWPhotoBrowser *)photoBrowser {
    return _gameData.packInfo.images.count;
}

- (id <MWPhoto>)photoBrowser:(MWPhotoBrowser *)photoBrowser photoAtIndex:(NSUInteger)index {
//    id obj = [_photos objectForKey:@(index)];
//    if (obj == [NSNull null]) {
//        return nil;
//    }
//    return obj;
    
    NSString *imageKey = [_gameData.packInfo.images objectAtIndex:index];
    if (!imageKey) {
        return nil;
    }
    NSString *localPath = makeImagePath(imageKey);
    MWPhoto *photo = [MWPhoto photoWithURL:[NSURL fileURLWithPath:localPath]];
    return photo;
}

- (void)photoBrowser:(MWPhotoBrowser *)photoBrowser didDisplayPhotoAtIndex:(NSUInteger)index {
    CommentHeaderCell *cell = (CommentHeaderCell*)[_tableView cellForRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
    _currPage = (int)index + 1;
//    if (cell) {
//        [cell.pageControl setCurrentPage:_currPage];
//    }
    
    CGRect frame = cell.scrollView.frame;
    frame.origin.x = cell.scrollView.frame.size.width * _currPage;
    frame.origin.y = 0;
    [cell.scrollView scrollRectToVisible:frame animated:NO];
    
    [self scrollViewDidScroll:cell.scrollView];
}

//- (MWCaptionView *)photoBrowser:(MWPhotoBrowser *)photoBrowser captionViewForPhotoAtIndex:(NSUInteger)index {
//    
//}

@end
