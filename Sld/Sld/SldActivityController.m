//
//  SldActivityController.m
//  Sld
//
//  Created by Wei Li on 14-5-10.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldActivityController.h"
#import "SldNevigationController.h"
#import "SldHttpSession.h"
#import "SldGameData.h"
#import "UIImageView+sldAsyncLoad.h"

//CommentCell
@interface ActivityCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UIImageView *iconView;
@property (weak, nonatomic) IBOutlet UILabel *userNameLabel;
@end

@implementation ActivityCell

@end

//Comment
@interface ActivityData : NSObject
@property (nonatomic) UInt64 id;
@property (nonatomic) UInt64 userId;
@property (nonatomic) NSString *userName;
@property (nonatomic) NSString *userIcon;
@property (nonatomic) NSString *text;
@end

@implementation ActivityData
+ (instancetype)commentDataWithDictionary:(NSDictionary*)dict {
    ActivityData *data = [[ActivityData alloc] init];
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
@interface SldActivityController ()
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic) NSMutableArray *activityDatas;
@property (nonatomic) UITableViewController *tableViewController;
@end

@implementation SldActivityController

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
    [refreshControl addTarget:self action:@selector(updateActivitys) forControlEvents:UIControlEventValueChanged];
    refreshControl.tintColor = [UIColor whiteColor];
    
    _tableViewController = [[UITableViewController alloc] init];
    _tableViewController.tableView = _tableView;
    _tableViewController.refreshControl = refreshControl;
}

- (void)onViewShown {
    if (_activityDatas == nil) {
        [self updateActivitys];
    }
}

- (void)updateActivitys {
    SldGameData *gameData = [SldGameData getInstance];
    NSDictionary *body = @{@"EventId":@(gameData.eventInfo.id), @"Key": @0, @"Limit": @20};
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"event/getActivities" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
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
        
        _activityDatas = [NSMutableArray arrayWithCapacity:[array count]];
        for (NSDictionary *dict in array) {
            ActivityData *activityData = [ActivityData commentDataWithDictionary:dict];
            [_activityDatas addObject:activityData];
        }
        [_tableView reloadData];
    }];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_activityDatas count]+1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= [_activityDatas count]) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"moreActivityCell" forIndexPath:indexPath];
        return cell;
    }
    
    ActivityCell *cell = [tableView dequeueReusableCellWithIdentifier:@"activityCell" forIndexPath:indexPath];
    
    ActivityData* activityData = [_activityDatas objectAtIndex:indexPath.row];
    cell.textView.text = activityData.text;
    cell.iconView.image = nil;
    cell.userNameLabel.text = activityData.userName;
    
    cell.iconView.image = nil;
    NSString *avatarUrl = [NSString stringWithFormat:@"http://www.gravatar.com/avatar/%llu?d=identicon&s=96", activityData.userId];
    [cell.iconView asyncLoadImageWithUrl:avatarUrl showIndicator:NO completion:nil];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= [_activityDatas count]) {
        return 80;
    }
    ActivityData* activityData = [_activityDatas objectAtIndex:indexPath.row];
    float h = [self textHeightForText:activityData.text width:250 fontName:nil fontSize:14];
    return MAX(h+22+10, 68);
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

@end
