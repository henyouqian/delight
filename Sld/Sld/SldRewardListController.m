//
//  SldRewardListController.m
//  pin
//
//  Created by 李炜 on 14-9-26.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldRewardListController.h"

//=================
@interface SldGetCouponCacheCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UIButton *getRewardButton;
@end

@implementation SldGetCouponCacheCell
@end

//=================
@interface SldRewardCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *rankLabel;
@property (weak, nonatomic) IBOutlet UILabel *matchRewardLabel;
@property (weak, nonatomic) IBOutlet UILabel *betMoneyLabel;
@property (weak, nonatomic) IBOutlet UILabel *betRewardLabel;
@property (weak, nonatomic) IBOutlet UIImageView *packThumbView;

@end

@implementation SldRewardCell
@end


//=================
@interface SldRewardRecord : NSObject
@property (nonatomic) int matchId;
@property (nonatomic) NSString* thumbKey;
@property (nonatomic) int rank;
@property (nonatomic) int matchReward;
@property (nonatomic) int betMoneySum;
@property (nonatomic) int betReward;

- (instancetype)initWithDict:(NSDictionary*)dict;
@end

@implementation SldRewardRecord
- (instancetype)initWithDict:(NSDictionary*)dict {
    if (self = [super init]) {
        _matchId = [(NSNumber*)[dict objectForKey:@"MatchId"] intValue];
        _thumbKey = [dict objectForKey:@"PackThumbKey"];
        _rank = [(NSNumber*)[dict objectForKey:@"FinalRank"] intValue];
        _matchReward = [(NSNumber*)[dict objectForKey:@"MatchReward"] intValue];
        _betMoneySum = [(NSNumber*)[dict objectForKey:@"BetMoneySum"] intValue];
        _betReward = [(NSNumber*)[dict objectForKey:@"BetReward"] intValue];
    }
    return self;
}
@end


//================================
@interface SldRewardListController ()

@end

@implementation SldRewardListController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Uncomment the following line to preserve selection between presentations.
    // self.clearsSelectionOnViewWillAppear = NO;
    
    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
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
    if (section == 0) {
        return 1;
    } else if (section == 1) {
        return 10;
    }
    return 0;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;
    if (indexPath.section == 0) {
        cell = [tableView dequeueReusableCellWithIdentifier:@"matchGetCouponCacheCell" forIndexPath:indexPath];
    } else if (indexPath.section == 1) {
        cell = [tableView dequeueReusableCellWithIdentifier:@"matchRewardCell" forIndexPath:indexPath];
    }
    
    
    // Configure the cell...
    
    return cell;
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
