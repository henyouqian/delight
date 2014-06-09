//
//  SldUserController.m
//  Sld
//
//  Created by Wei Li on 14-5-11.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldUserController.h"
#import "SldLoginViewController.h"
#import "SldHttpSession.h"
#import "config.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldGameData.h"
#import "util.h"

@interface SldUserController ()
@property (weak, nonatomic) IBOutlet UITableViewCell *logoutCell;
@property (weak, nonatomic) IBOutlet UIImageView *avatarView;
@property (weak, nonatomic) IBOutlet UILabel *nickNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *teamLabel;
@property (weak, nonatomic) IBOutlet UILabel *genderLabel;
@property (weak, nonatomic) IBOutlet UILabel *moneyLabel;
@property (weak, nonatomic) IBOutlet UILabel *assertsLabel;

@end

@implementation SldUserController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.clearsSelectionOnViewWillAppear = YES;
    SldGameData *gamedata = [SldGameData getInstance];
    
    //
    if (!gamedata.online) {
        [SldLoginViewController createAndPresentWithCurrentController:self animated:YES];
        return;
    }
    
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    SldGameData *gamedata = [SldGameData getInstance];

    //avatar
    _avatarView.image = nil;
    NSString *url = [SldUtil makeGravatarUrlWithKey:gamedata.gravatarKey width:_avatarView.frame.size.width];
    [_avatarView asyncLoadImageWithUrl:url showIndicator:NO completion:nil];
    
    //nickname
    _nickNameLabel.text = gamedata.nickName;
    
    //team
    _teamLabel.text = gamedata.teamName;
    
    //gender
    if (gamedata.gender == 1) {
        _genderLabel.text = @"🚹";
        _genderLabel.textColor = makeUIColor(0, 122, 255, 255);
    } else if (gamedata.gender == 0) {
        _genderLabel.text = @"🚺";
        _genderLabel.textColor = makeUIColor(244, 75, 116, 255);
    } else {
        _genderLabel.text = @"㊙";
        _genderLabel.textColor = makeUIColor(128, 128, 128, 255);
    }
    
    //money
    _moneyLabel.text = [NSString stringWithFormat:@"%d", gamedata.money];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
//    UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
//    if (cell == _logoutCell) {
//        [SldLoginViewController createAndPresentWithCurrentController:self animated:YES];
//    }
}

- (IBAction)onLogoutButton:(id)sender {
    RIButtonItem *cancelItem = [RIButtonItem itemWithLabel:@"No" action:nil];
    
	RIButtonItem *logoutItem = [RIButtonItem itemWithLabel:@"Yes" action:^{
		[[SldHttpSession defaultSession] logoutWithComplete:^{
            dispatch_async(dispatch_get_main_queue(), ^{
                Config *conf = [Config sharedConf];
                NSArray *accounts = [SSKeychain accountsForService:conf.KEYCHAIN_SERVICE];
                NSString *username = [accounts lastObject][@"acct"];
                [SSKeychain setPassword:@"" forService:conf.KEYCHAIN_SERVICE account:username];
                [SldLoginViewController createAndPresentWithCurrentController:self animated:YES];
                
                SldGameData *gd = [SldGameData getInstance];
                [gd reset];
            });
        }];
	}];
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Log out?"
	                                                    message:nil
											   cancelButtonItem:cancelItem
											   otherButtonItems:logoutItem, nil];
	[alertView show];
}


#pragma mark - Table view data source

//- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
//{
//    return 0;
//}
//
//- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
//{
//    return 0;
//}

/*
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:<#@"reuseIdentifier"#> forIndexPath:indexPath];
    
    // Configure the cell...
    
    return cell;
}
*/

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
