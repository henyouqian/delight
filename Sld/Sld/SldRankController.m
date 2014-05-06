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
#import "config.h"
#import "util.h"
#import "UIImage+animatedGIF.h"

@interface RankCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *rankLabel;
@property (weak, nonatomic) IBOutlet UILabel *userNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *scoreLabel;

@end

@implementation RankCell
@end

@interface RankInfo : NSObject
@property (nonatomic) NSNumber *rank;
@property (nonatomic) NSString *userName;
@property (nonatomic) NSString *score;
@end

@implementation RankInfo
@end


@interface SldRankController ()
@property (nonatomic) NSMutableArray *rankInfos;
@end

@implementation SldRankController

- (void)dealloc {
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    [self.refreshControl addTarget:self action:@selector(updateRanks) forControlEvents:UIControlEventValueChanged];
    self.refreshControl.tintColor = [UIColor whiteColor];
}

- (void)updateRanks {
    SldGameData *gameData = [SldGameData getInstance];
    self.tableView.tableFooterView = [[UIView alloc] init];
    
    //get ranks
    _rankInfos = [NSMutableArray array];
    
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"EventId":@(gameData.eventInfo.id), @"Offset":@0, @"Limit":@25};
    [session postToApi:@"event/getRanks" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [self.refreshControl endRefreshing];
        if (error) {
            alertServerError(error, data);
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
    return [_rankInfos count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    RankCell *cell = [tableView dequeueReusableCellWithIdentifier:@"rankCell" forIndexPath:indexPath];
    cell.backgroundColor = [UIColor clearColor];
    
    SldEventDetailViewController *detailVc = [SldEventDetailViewController getInstance];
    UIColor *meColor = makeUIColor(255, 197, 131, 255);
    cell.rankLabel.text = [NSString stringWithFormat:@"%d", (int)(indexPath.row)];
    if (indexPath.section == 0) {
        cell.userNameLabel.text = @"我";
        cell.rankLabel.text = detailVc.rankStr;
        cell.scoreLabel.text = detailVc.highScoreStr;
        
        [cell.rankLabel setTextColor:meColor];
        [cell.userNameLabel setTextColor:meColor];
        [cell.scoreLabel setTextColor:meColor];
    } else {
        RankInfo *rankInfo = [_rankInfos objectAtIndex:indexPath.row];
        if (rankInfo) {
            cell.rankLabel.text = [NSString stringWithFormat:@"%d", [rankInfo.rank intValue]];
            cell.userNameLabel.text = rankInfo.userName;
            cell.scoreLabel.text = rankInfo.score;
            if (detailVc.rankStr && [detailVc.rankStr compare:cell.rankLabel.text] == 0) {
                cell.userNameLabel.text = @"我";
                [cell.rankLabel setTextColor:meColor];
                [cell.userNameLabel setTextColor:meColor];
                [cell.scoreLabel setTextColor:meColor];
            }
        }
    }
    // Configure the cell...
    
    return cell;
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
