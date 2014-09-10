//
//  SldRewardDefListController.m
//  pin
//
//  Created by 李炜 on 14-9-7.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldRewardDefListController.h"
#import "SldGameData.h"

//===========================
@interface SldRewardDefListImgCell : UITableViewCell

@end

@implementation SldRewardDefListImgCell

@end

//===========================
@interface SldRewardDefListRankCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *rankLabel;
@property (weak, nonatomic) IBOutlet UILabel *rewardLabel;

@end

@implementation SldRewardDefListRankCell

@end

//===========================
@interface SldRewardDefListController ()
@property (nonatomic) SldGameData* gd;
@end

@implementation SldRewardDefListController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _gd = [SldGameData getInstance];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return 1;
    } else if (section == 1) {
        return _gd.match.rankRewardProportions.count+2;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    if (indexPath.section == 0) {
        cell = [tableView dequeueReusableCellWithIdentifier:@"rewardDefListImgCell" forIndexPath:indexPath];
        return cell;
    } else if (indexPath.section == 1) {
        SldRewardDefListRankCell *cell = (SldRewardDefListRankCell*)[tableView dequeueReusableCellWithIdentifier:@"rewardDefListRankCell" forIndexPath:indexPath];
        
        float couponSum = (float)(_gd.match.couponReward + _gd.match.extraReward);
        
        if (indexPath.row == 0) {
            cell.rankLabel.text = @"幸运奖";
            float coupon = _gd.match.luckyRewardProportion * couponSum;
            cell.rewardLabel.text = [NSString stringWithFormat:@"%d奖金", (int)coupon];
        } else if (indexPath.row == _gd.match.rankRewardProportions.count+1) {
            float coupon = _gd.match.oneCoinRewardProportion * couponSum;
            if (coupon > 0.01f) {
                cell.rankLabel.text = [NSString stringWithFormat:@"第%d名-第%d名", indexPath.row, indexPath.row+(int)coupon-1];
                cell.rewardLabel.text = @"1奖金";
            } else {
                cell.rankLabel.text = @"";
                cell.rewardLabel.text = @"";
            }
        } else{
            cell.rankLabel.text = [NSString stringWithFormat:@"第%d名", indexPath.row];
            float prop = [(NSNumber*)_gd.match.rankRewardProportions[indexPath.row-1] floatValue];
            float coupon = prop * couponSum;
            cell.rewardLabel.text = [NSString stringWithFormat:@"%d奖金", (int)coupon];
        }
        
        return cell;
    }
    
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return 300;
    } else if (indexPath.section == 1) {
        return 48;
    }
    return 48;
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
