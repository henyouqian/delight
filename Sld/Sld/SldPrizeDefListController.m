//
//  SldPrizeDefListController.m
//  pin
//
//  Created by 李炜 on 14-9-7.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldPrizeDefListController.h"
#import "SldGameData.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldMyMatchController.h"

static const int MIN_PRICE = 100;

//===========================
@interface SldPrizeDefListImgCell : UITableViewCell

@property (weak, nonatomic) IBOutlet UIImageView *promoImageView;
@property (weak, nonatomic) IBOutlet UIImageView *maskImageView;
@property (weak, nonatomic) IBOutlet UILabel *maskLabel;

@end

@implementation SldPrizeDefListImgCell

@end

//===========================
@interface SldPrizeDefListRankCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *rankLabel;
@property (weak, nonatomic) IBOutlet UILabel *prizeLabel;

@end

@implementation SldPrizeDefListRankCell

@end

//===========================
@interface SldPrizeDefListController ()
@property (nonatomic) SldGameData* gd;
@end

@implementation SldPrizeDefListController

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
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    if (section == 0) {
        return 1;
    } else if (section == 1) {
        return 1;
    } else if (section == 2) {
        return _gd.match.rankPrizeProportions.count+1;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == 0) {
        SldPrizeDefListImgCell *cell = [tableView dequeueReusableCellWithIdentifier:@"prizeDefListImgCell" forIndexPath:indexPath];
        NSString *imgKey = _gd.match.promoImage;
        if (imgKey.length) {
            [cell.promoImageView asyncLoadUploadedImageWithKey:_gd.match.promoImage showIndicator:NO completion:nil];
//            cell.hidden = NO;
        } else {
//            cell.hidden = YES;
        }
        
        if (_gd.match.promoUrl.length == 0) {
            cell.maskImageView.hidden = YES;
            cell.maskLabel.hidden = YES;
        } else {
            cell.maskImageView.hidden = NO;
            cell.maskLabel.hidden = NO;
        }
        
        return cell;
    } else if (indexPath.section == 1) {
        SldPrizeDefListRankCell *cell = (SldPrizeDefListRankCell*)[tableView dequeueReusableCellWithIdentifier:@"prizeDefListDescCell" forIndexPath:indexPath];
        return cell;
    } else if (indexPath.section == 2) {
        SldPrizeDefListRankCell *cell = (SldPrizeDefListRankCell*)[tableView dequeueReusableCellWithIdentifier:@"prizeDefListRankCell" forIndexPath:indexPath];
        
        int prizeSum = _gd.match.prize + _gd.match.extraPrize;
        
        float lastRankPrize = [(NSNumber*)[_gd.match.rankPrizeProportions lastObject] floatValue] * prizeSum;
        
        if (indexPath.row == _gd.match.rankPrizeProportions.count) {
            int minPrizeNum = (int)(_gd.match.minPrizeProportion * prizeSum)/MIN_PRICE;
            if (minPrizeNum > 1 && (int)lastRankPrize >= MIN_PRICE) {
                cell.rankLabel.text = [NSString stringWithFormat:@"第%d名-第%d名", indexPath.row+1, indexPath.row+minPrizeNum];
                cell.prizeLabel.text = [NSString stringWithFormat:@"%d奖金", MIN_PRICE];
            } else {
                cell.rankLabel.text = @"暂无";
                cell.prizeLabel.text = [NSString stringWithFormat:@"%d奖金", MIN_PRICE];
            }
        } else {
            cell.rankLabel.text = [NSString stringWithFormat:@"第%d名", indexPath.row+1];
            float prop = [(NSNumber*)_gd.match.rankPrizeProportions[indexPath.row] floatValue];
            int prize = (int)(prop * prizeSum);
            cell.prizeLabel.text = [NSString stringWithFormat:@"%.d奖金", prize];
        }
        
        return cell;
    }
    
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        if (_gd.match.promoImage.length > 0) {
            return 320;
        }
        return 0;
    } else if (indexPath.section == 1) {
        return 74;
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

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    if (_gd.match.promoUrl.length == 0) {
        return NO;
    }
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if (segue.identifier && [segue.identifier compare:@"segToPromoWeb"] == 0) {
        NSString *urlStr = _gd.match.promoUrl;
        
        NSRange range = [urlStr rangeOfString:@"://"];
        if (range.location == NSNotFound) {
            urlStr = [NSString stringWithFormat:@"http://%@", urlStr];
        }
        
        SldMatchPromoWebController *vc = segue.destinationViewController;
        vc.url = [NSURL URLWithString:urlStr];
    }
}

@end
