//
//  SldRankController.m
//  Sld
//
//  Created by Wei Li on 14-5-4.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldRankController.h"
#import "SldEventDetailViewController.h"
#import "SldGameData.h"
#import "SldHttpSession.h"
#import "SldNevigationController.h"
#import "config.h"
#import "util.h"
#import "UIImage+animatedGIF.h"
#import "UIImageView+sldAsyncLoad.h"

@interface RankCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *rankLabel;
@property (weak, nonatomic) IBOutlet UILabel *userNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *scoreLabel;
@property (weak, nonatomic) IBOutlet UIImageView *avatarImageView;
@property (weak, nonatomic) IBOutlet UILabel *teamLabel;
@end

@implementation RankCell
- (void)reset {
    self.backgroundColor = [UIColor clearColor];
    self.selectionStyle = UITableViewCellSelectionStyleNone;
}
@end

@interface BottomCell : UITableViewCell
@end

@implementation BottomCell

@end

@interface RankInfo : NSObject
@property (nonatomic) NSNumber *rank;
@property (nonatomic) UInt64 userId;
@property (nonatomic) NSString *userName;
@property (nonatomic) NSString *score;
@property (nonatomic) NSString *teamName;
@property (nonatomic) NSString *gravatarKey;
@end

@implementation RankInfo
@end


@interface SldRankController ()
@property (weak, nonatomic) IBOutlet UITableView *tableView;
@property (nonatomic) UITableViewController *tableViewController;
@property (nonatomic) NSMutableArray *rankInfos;
@property (nonatomic) BOOL loadingRank;
@end

@implementation SldRankController

- (void)dealloc {
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _loadingRank = NO;
    _tableView.delegate = self;
    _tableView.dataSource = self;
    
    //refreshControl
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(updateRanks) forControlEvents:UIControlEventValueChanged];
    refreshControl.tintColor = [UIColor whiteColor];
    
    _tableViewController = [[UITableViewController alloc] init];
    _tableViewController.tableView = _tableView;
    _tableViewController.refreshControl = refreshControl;
    
    _tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];
    _tableView.scrollIndicatorInsets = UIEdgeInsetsMake([SldNevigationController getBottomY], 0, 0, 0);
    
    //set tableView inset
    int navBottomY = [SldNevigationController getBottomY];
    _tableView.contentInset = UIEdgeInsetsMake(navBottomY, 0, 100, 0);
    _tableView.scrollIndicatorInsets = UIEdgeInsetsMake(navBottomY, 0, 100, 0);
}

//- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
////    NSInteger currentOffset = scrollView.contentOffset.y;
////    NSInteger maximumOffset = scrollView.contentSize.height - scrollView.frame.size.height;
////    
////    if (maximumOffset - currentOffset <= -20) {
////        //[self appendRanks];
////        lwInfo("%d, %d", currentOffset, maximumOffset);
////    }
//    
//    CGPoint offset = scrollView.contentOffset;
//    CGRect bounds = scrollView.bounds;
//    CGSize size = scrollView.contentSize;
//    UIEdgeInsets inset = scrollView.contentInset;
//    float y = offset.y + bounds.size.height - inset.bottom;
//    float h = size.height;
//    // NSLog(@"offset: %f", offset.y);
//    // NSLog(@"content.height: %f", size.height);
//    // NSLog(@"bounds.height: %f", bounds.size.height);
//    // NSLog(@"inset.top: %f", inset.top);
//    // NSLog(@"inset.bottom: %f", inset.bottom);
//    // NSLog(@"pos: %f of %f", y, h);
//    
//    float reload_distance = 10;
//    if(y > h + reload_distance) {
//        NSLog(@"%f, %f", y, h);
//    }
//}

- (void)onViewShown {
    if (_rankInfos == nil) {
        [self updateRanks];
    }
}

- (void)updateRanks {
    if (_loadingRank) {
        return;
    }
    
    SldGameData *gameData = [SldGameData getInstance];
    
    //get ranks
    _rankInfos = [NSMutableArray array];
    
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"EventId":@(gameData.eventInfo.id), @"Offset":@0, @"Limit":@25};
    
    _loadingRank = YES;
    [session postToApi:@"event/getRanks" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [_tableViewController.refreshControl endRefreshing];
        _loadingRank = NO;
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        NSArray *rankArray = [dict objectForKey:@"Ranks"];
        if (!rankArray) {
            lwError("http format error");
            return;
        }
        
        for (NSDictionary *rankDict in rankArray) {
            RankInfo *rankInfo = [[RankInfo alloc] init];
            rankInfo.rank = [rankDict objectForKey:@"Rank"];
            rankInfo.userName = [rankDict objectForKey:@"UserName"];
            NSNumber *score = [rankDict objectForKey:@"Score"];
            rankInfo.score = @"0";
            if (score) {
                int msec = -[score intValue];
                int sec = msec/1000;
                int min = sec / 60;
                sec = sec % 60;
                msec = msec % 1000;
                rankInfo.score = [NSString stringWithFormat:@"%01d:%02d.%03d", min, sec, msec];
            }
            [_rankInfos addObject:rankInfo];
        }
        //[self.tableView reloadSections:[NSIndexSet indexSetWithIndex:1]  withRowAnimation:UITableViewRowAnimationFade];
        [self.tableView reloadData];
    }];
}

- (IBAction)onAppendRanksButton:(id)sender {
    [self appendRanks];
}

- (void)appendRanks {
    if (_loadingRank) {
        return;
    }
    SldGameData *gameData = [SldGameData getInstance];
    int offset = [_rankInfos count];
    if (offset == 0) {
        return;
    }
    
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"EventId":@(gameData.eventInfo.id), @"Offset":[NSNumber numberWithInt:offset], @"Limit":@25};
    _loadingRank = YES;
    [session postToApi:@"event/getRanks" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        _loadingRank = NO;
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        NSArray *rankArray = [dict objectForKey:@"Ranks"];
        if (!rankArray) {
            lwError("http format error");
            return;
        }
        int num = [rankArray count];
        if (num == 0) {
            return;
        }
        
        NSMutableArray *insertIndexPaths = [NSMutableArray arrayWithCapacity:num];
        for (NSDictionary *rankDict in rankArray) {
            RankInfo *rankInfo = [[RankInfo alloc] init];
            rankInfo.rank = [rankDict objectForKey:@"Rank"];
            rankInfo.userName = [rankDict objectForKey:@"UserName"];
            NSNumber *score = [rankDict objectForKey:@"Score"];
            rankInfo.score = @"0";
            if (score) {
                int msec = -[score intValue];
                int sec = msec/1000;
                int min = sec / 60;
                sec = sec % 60;
                msec = msec % 1000;
                rankInfo.score = [NSString stringWithFormat:@"%01d:%02d.%03d", min, sec, msec];
            }
            [insertIndexPaths addObject: [NSIndexPath indexPathForRow:[_rankInfos count] inSection:1]];
            [_rankInfos addObject:rankInfo];
        }
        [self.tableView insertRowsAtIndexPaths:insertIndexPaths withRowAnimation:UITableViewRowAnimationFade];
    }];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) return 1;
    return [_rankInfos count] + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SldEventDetailViewController *detailVc = [SldEventDetailViewController getInstance];
    UIColor *meColor = makeUIColor(255, 197, 131, 255);
    UIColor *normalColor = [UIColor whiteColor];
    
    void (^setLabelColor)(RankCell*, UIColor*) = ^(RankCell *cell, UIColor *color){
        [cell.rankLabel setTextColor:color];
        [cell.userNameLabel setTextColor:color];
        [cell.scoreLabel setTextColor:color];
        [cell.teamLabel setTextColor:color];
    };
    
    SldGameData *gamedata = [SldGameData getInstance];
    
    if (indexPath.section == 0) {
        RankCell *cell = [tableView dequeueReusableCellWithIdentifier:@"rankCell" forIndexPath:indexPath];
        [cell reset];
        cell.rankLabel.text = [NSString stringWithFormat:@"%d", (int)(indexPath.row)];
        cell.userNameLabel.text = gamedata.nickName;
        cell.teamLabel.text = gamedata.teamName;
        cell.rankLabel.text = detailVc.rankStr;
        cell.scoreLabel.text = detailVc.highScoreStr;
        
        setLabelColor(cell, meColor);
        
        //avatar
        cell.avatarImageView.image = nil;
        NSString *url = [SldUtil makeGravatarUrlWithKey:gamedata.gravatarKey width:cell.avatarImageView.frame.size.width];
        [cell.avatarImageView asyncLoadImageWithUrl:url showIndicator:NO completion:nil];
        
        return cell;
    } else if (indexPath.section == 1) {
        if (indexPath.row < [_rankInfos count]) {
            RankInfo *rankInfo = [_rankInfos objectAtIndex:indexPath.row];
            if (rankInfo) {
                RankCell *cell = [tableView dequeueReusableCellWithIdentifier:@"rankCell" forIndexPath:indexPath];
                [cell reset];
                cell.rankLabel.text = [NSString stringWithFormat:@"%d", [rankInfo.rank intValue]];
                cell.userNameLabel.text = rankInfo.userName;
                cell.scoreLabel.text = rankInfo.score;
                cell.teamLabel.text = rankInfo.teamName;
                
                if (detailVc.rankStr && [detailVc.rankStr compare:cell.rankLabel.text] == 0) {
                    setLabelColor(cell, meColor);
                } else {
                    setLabelColor(cell, normalColor);
                }
                
                //avatar
                cell.avatarImageView.image = nil;
                NSString *url = [SldUtil makeGravatarUrlWithKey:rankInfo.gravatarKey width:cell.avatarImageView.frame.size.width];
                [cell.avatarImageView asyncLoadImageWithUrl:url showIndicator:NO completion:nil];
                
                return cell;
            }
        } else if (indexPath.row == [_rankInfos count]) {
            BottomCell *bottomCell = [tableView dequeueReusableCellWithIdentifier:@"bottomCell" forIndexPath:indexPath];
            return bottomCell;
        }
    }
    return [tableView dequeueReusableCellWithIdentifier:@"rankCell" forIndexPath:indexPath];
}

-(UIView*)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section
{
    return [[UIView alloc] initWithFrame:CGRectZero];
}

-(CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section
{
    return 0.01f;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
    NSString *sectionName;
    switch (section)
    {
        case 0:
            sectionName = NSLocalizedString(@"My rank", @"My rank");
            break;
        case 1:
            sectionName = NSLocalizedString(@"Top ranks", @"Top ranks");
            break;
            // ...
        default:
            sectionName = @"";
            break;
    }
    return sectionName;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return 62;
    } else if (indexPath.section == 1) {
        return 62;
    }
    return 0;
}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
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
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

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
