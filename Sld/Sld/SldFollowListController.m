//
//  SldFollowListController.m
//  pin
//
//  Created by 李炜 on 14/12/15.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldFollowListController.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldHttpSession.h"
#import "SldGameData.h"
#import "SldUtil.h"
#import "SldUserPageController.h"

static const int FOLLOW_FETCH_LIMIT = 30;

//========================
@interface SldFollowListCell : UITableViewCell
@property (weak, nonatomic) IBOutlet SldAsyncImageView *avatarView;
@property (weak, nonatomic) IBOutlet UILabel *userNameLabel;
@property (weak, nonatomic) IBOutlet UILabel *userTextLabel;
@property SInt64 userId;
@end

@implementation SldFollowListCell

@end

//========================
@interface SldFollowListController ()

@property SInt64 lastKey;
@property SInt64 lastScore;

@property NSMutableArray *playerInfoLites;

@property SldLoadMoreCell *loadMoreCell;

@end

@implementation SldFollowListController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _playerInfoLites = [NSMutableArray arrayWithCapacity:20];
                        
    if (_follow) {
        self.title = [NSString stringWithFormat:@"%@的关注", _playerInfo.nickName];
    } else {
        self.title = [NSString stringWithFormat:@"%@的粉丝", _playerInfo.nickName];
    }
    
    [self refresh];
}

- (void)refresh {
    NSString *api = nil;
    if (_follow) {
        api = @"player/followList";
    } else {
        api = @"player/fanList";
    }
    
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"UserId":@(_playerInfo.userId), @"StartId":@(0), @"LastScore":@(0), @"Limit":@(FOLLOW_FETCH_LIMIT)};
    [session postToApi:api body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        NSArray *playerInfoLitesJs = [dict objectForKey:@"PlayerInfoLites"];
        _lastKey = [(NSNumber*)[dict objectForKey:@"LastKey"] longLongValue];
        _lastScore = [(NSNumber*)[dict objectForKey:@"LastScore"] longLongValue];
        
        [_playerInfoLites removeAllObjects];
        if (playerInfoLitesJs) {
            for (NSDictionary *liteDict in playerInfoLitesJs) {
                PlayerInfoLite *infoLite = [[PlayerInfoLite alloc] initWithDict:liteDict];
                [_playerInfoLites addObject:infoLite];
            }
        }
        [self.tableView reloadData];
    }];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onLoadMoreButton:(id)sender {
    [_loadMoreCell startSpin];
    
    NSString *api = nil;
    if (_follow) {
        api = @"player/followList";
    } else {
        api = @"player/fanList";
    }
    
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"UserId":@(_playerInfo.userId), @"StartId":@(_lastKey), @"LastScore":@(_lastScore), @"Limit":@(FOLLOW_FETCH_LIMIT)};
    [session postToApi:api body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [_loadMoreCell stopSpin];
        
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        NSArray *playerInfoLitesJs = [dict objectForKey:@"PlayerInfoLites"];
        _lastKey = [(NSNumber*)[dict objectForKey:@"LastKey"] longLongValue];
        _lastScore = [(NSNumber*)[dict objectForKey:@"LastScore"] longLongValue];
        
        if (playerInfoLitesJs) {
            if (playerInfoLitesJs.count < FOLLOW_FETCH_LIMIT) {
                [_loadMoreCell noMore];
                return;
            }
            
            NSMutableArray *inserts = [NSMutableArray array];
            for (NSDictionary *liteDict in playerInfoLitesJs) {
                PlayerInfoLite *infoLite = [[PlayerInfoLite alloc] initWithDict:liteDict];
                
                [inserts addObject:[NSIndexPath indexPathForRow:_playerInfoLites.count inSection:0]];
                [_playerInfoLites addObject:infoLite];
            }
            [self.tableView insertRowsAtIndexPaths:inserts withRowAnimation:UITableViewRowAnimationAutomatic];
        }
    }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return _playerInfoLites.count;
    } else if (section == 1) {
        return 1;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        SldFollowListCell *cell = [tableView dequeueReusableCellWithIdentifier:@"userCell" forIndexPath:indexPath];
        
        if (indexPath.row < _playerInfoLites.count) {
            PlayerInfoLite *info = _playerInfoLites[indexPath.row];
            [SldUtil loadAvatar:cell.avatarView gravatarKey:info.GravatarKey customAvatarKey:info.CustomAvatarKey];
            [cell.avatarView.layer setMasksToBounds:YES];
            cell.avatarView.layer.cornerRadius = 5;
            
            cell.userNameLabel.text = info.NickName;
            cell.userId = info.UserId;
            if (info.Text && info.Text.length > 0) {
                cell.userTextLabel.text = info.Text;
            } else {
                cell.userTextLabel.text = @"无简介";
            }
        }
        return cell;
    } else if (indexPath.section == 1) {
        _loadMoreCell = [tableView dequeueReusableCellWithIdentifier:@"loadMoreCell" forIndexPath:indexPath];
        
        return _loadMoreCell;
    }
    return nil;
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    if ([identifier compare:@"segueUserPage"] == 0) {
        //get playerInfo
        SldHttpSession *session = [SldHttpSession defaultSession];
        SldFollowListCell *cell = sender;
        NSDictionary *body = @{@"UserId":@(cell.userId)};
        [session postToApi:@"player/getInfo" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                alertHTTPError(error, data);
                return;
            }
            
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error) {
                lwError("Json error:%@", [error localizedDescription]);
                return;
            }
            PlayerInfo *playerInfo = [PlayerInfo playerWithDictionary:dict];
            
            SldUserPageController* vc = [getStoryboard() instantiateViewControllerWithIdentifier:@"userPageController"];
            vc.playerInfo = playerInfo;
            [self.navigationController pushViewController:vc animated:YES];
        }];
    }
    return NO;
}

//- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
//    
//}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
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
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/


@end
