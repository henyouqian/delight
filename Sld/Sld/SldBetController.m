//
//  SldBetController.m
//  Sld
//
//  Created by 李炜 on 14-7-12.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldBetController.h"
#import "SldGameData.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldNevigationController.h"
#import "SldUtil.h"
#import "SldHttpSession.h"

@interface TeamBetData : NSObject
@property (nonatomic) NSString *teamName;
@property (nonatomic) int score;
@property (nonatomic) float winMul;
@property (nonatomic) int myBet;
@property (nonatomic) SInt64 betMoney;
@end

@implementation TeamBetData

@end


@interface SldBetContainerController ()
@property (weak, nonatomic) IBOutlet UIImageView *bgImageView;
@end

@implementation SldBetContainerController

- (void)viewDidLoad {
    [super viewDidLoad];
    [self loadBackground];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    //[self loadBackground];
}

- (void)loadBackground{
    NSString *bgKey = [SldGameData getInstance].packInfo.coverBlur;
   
    [_bgImageView asyncLoadImageWithKey:bgKey showIndicator:NO completion:^{
        _bgImageView.alpha = 0.0;
        [UIView animateWithDuration:1.f delay:0 options:UIViewAnimationOptionCurveEaseInOut
            animations:^{
                _bgImageView.alpha = 1.0;
            } completion:nil
        ];
    }];
}

@end

//=============================
@interface SldBetCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *rankLabel;
@property (weak, nonatomic) IBOutlet UILabel *teamLabel;
    
@end

@implementation SldBetCell

@end


//=============================
@interface SldBetController ()
@property (weak, nonatomic) IBOutlet UIView *headerView;
@property (weak, nonatomic) IBOutlet UILabel *myCoinLabel;
@property (weak, nonatomic) IBOutlet UILabel *betSumLabel;
@property (nonatomic) SldGameData *gd;
@property (nonatomic) NSMutableArray *teamBetDatas;
@end

@implementation SldBetController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _gd = [SldGameData getInstance];
    
    //set tableView inset
    int navBottomY = [SldNevigationController getBottomY];
    self.tableView.contentInset = UIEdgeInsetsMake(navBottomY, 0, 0, 0);
    self.tableView.scrollIndicatorInsets = UIEdgeInsetsMake(navBottomY, 0, 0, 0);
    
    self.tableView.tableHeaderView = _headerView;
    
    _myCoinLabel.text = [NSString stringWithFormat:@"我的金币：%lld", _gd.money];
    
    //
    _teamBetDatas = [NSMutableArray array];
    for (NSString *teamName in _gd.TEAM_NAMES) {
        TeamBetData *data = [[TeamBetData alloc] init];
        data.teamName = teamName;
        [_teamBetDatas addObject:data];
    }
    
    //
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"EventId":@(_gd.eventInfo.id)};
    [session postToApi:@"event/getBettingPool" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        NSDictionary *bettingPoolDict = [dict objectForKey:@"BettingPool"];
        
        SInt64 totleBetMoney = 0;
        for (TeamBetData *data in _teamBetDatas) {
            NSNumber *betMoney = [bettingPoolDict objectForKey:data.teamName];
            if (betMoney) {
                data.betMoney = [betMoney longLongValue];
                totleBetMoney += data.betMoney;
            }
            
            
        }
        
        
        
    }];

}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _teamBetDatas.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    SldBetCell *cell = [tableView dequeueReusableCellWithIdentifier:@"betCell" forIndexPath:indexPath];
    cell.backgroundColor = [UIColor clearColor];
    TeamBetData *data = [_teamBetDatas objectAtIndex:indexPath.row];
    cell.teamLabel.text = data.teamName;
    cell.rankLabel.text = [NSString stringWithFormat:@"%d", indexPath.row+1];
    return cell;
}

//- (UITableViewHeaderFooterView *)headerViewForSection:(NSInteger)section {
//    if (section == 0) {
//        return _headerView;
//    }
//    return nil;
//}

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
