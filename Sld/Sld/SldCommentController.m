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
@property (nonatomic) NSString *userIcon;
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
    data.userIcon = [dict objectForKey:@"UserIcon"];
    data.text = [dict objectForKey:@"Text"];
    
    return data;
}
@end

//SldCommentController
@interface SldCommentController ()
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic) NSMutableArray *commentDatas;
@property (nonatomic) UITableViewController *tableViewController;
@end

@implementation SldCommentController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
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
}

- (void)viewDidAppear:(BOOL)animated {
    [self updateComments];
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
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"descCell" forIndexPath:indexPath];
        return cell;
    } else if (indexPath.section == 1) {
        if (indexPath.row >= [_commentDatas count]) {
            UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"moreCommentCell" forIndexPath:indexPath];
            return cell;
        }
        
        CommentCell *cell = [tableView dequeueReusableCellWithIdentifier:@"commentCell" forIndexPath:indexPath];
        
        CommentData* commentData = [_commentDatas objectAtIndex:indexPath.row];
        cell.textView.text = commentData.text;
        cell.iconView.image = nil;
        cell.userNameLabel.text = commentData.userName;
        
        
        SldHttpSession *session = [SldHttpSession defaultSession];
        //NSString *imgPath = makeImagePath([NSString stringWithFormat:@"icon%d.png", indexPath.row]);
        [session loadImageFromUrl:[NSString stringWithFormat:@"http://www.gravatar.com/avatar/%llu?d=identicon&s=96", commentData.userId] completionHandler:^(NSString *localPath, NSError *error)
         {
             if (error == nil) {
                 CommentCell *cell = (CommentCell*)[tableView cellForRowAtIndexPath:indexPath];
                 if (cell) {
                     UIImage *image = [UIImage imageWithContentsOfFile:localPath];
                     cell.iconView.image = image;
                 }
             }
         }];
        
        return cell;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return 280;
    } else if (indexPath.section == 1) {
        if (indexPath.row >= [_commentDatas count]) {
            return 80;
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
            sectionName = NSLocalizedString(@"Description", @"Description");
            break;
        case 1:
            sectionName = NSLocalizedString(@"Talks", @"Talks");
            break;
        default:
            sectionName = @"";
            break;
    }
    return sectionName;
}

@end
