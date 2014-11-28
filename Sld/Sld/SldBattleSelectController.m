//
//  SldBattleController.m
//  pin
//
//  Created by 李炜 on 14/11/10.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldBattleSelectController.h"
#import "SldGameData.h"
#import "SldUtil.h"
#import "SldHttpSession.h"
#import "SldBattleLinkController.h"
#import "SldIapController.h"

@interface SldBattleRoom : UICollectionViewCell
@property (nonatomic) NSString *Name;
@property (nonatomic) int BetCoin;
@property (nonatomic) int PlayerNum;
- (instancetype)initWithDict:(NSDictionary*)dict;
@end

@implementation SldBattleRoom
- (instancetype)initWithDict:(NSDictionary*)dict {
    if (self = [super init]) {
        _Name = dict[@"Name"];
        _BetCoin = [(NSNumber*)dict[@"BetCoin"] intValue];
        _PlayerNum = [(NSNumber*)dict[@"PlayerNum"] intValue];
    }
    return self;
}
@end

//===============================
@interface SldBattleCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet UILabel *prizeLabel;
@property (weak, nonatomic) IBOutlet UILabel *playerNumLabel;
//@property (weak, nonatomic) IBOutlet UIImageView *coinImage;
@property (nonatomic) SldBattleRoom *room;
@end

@implementation SldBattleCell

- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes {
    return layoutAttributes;
}

@end

//===============================
@interface SldBattleSelectHeader : UICollectionReusableView
@property (weak, nonatomic) IBOutlet UIImageView *userAvatarView;
@property (weak, nonatomic) IBOutlet UILabel *heartLabel;
@property (weak, nonatomic) IBOutlet UILabel *coinLabel;
@property (weak, nonatomic) IBOutlet UILabel *winNumLabel;
@property (weak, nonatomic) IBOutlet UILabel *totalPrizeLabel;

@end

@implementation SldBattleSelectHeader

@end


//==================================
@interface SldBattleSelectController ()

@property (nonatomic) NSMutableArray *rooms;
@property (nonatomic) NSDate *lastUpdateTime;

@end

@implementation SldBattleSelectController

static NSString * const reuseIdentifier = @"BattleCell";


- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    
    BOOL needUpdate = YES;
    if (_lastUpdateTime) {
        NSTimeInterval dt = -[_lastUpdateTime timeIntervalSinceNow];
        if (dt < 60) {
            needUpdate = NO;
        }
    }
    if (needUpdate) {
        SldHttpSession *session = [SldHttpSession defaultSession];
        [session postToApi:@"battle/roomList" body:nil completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                alertHTTPError(error, data);
                return;
            }
            
            NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error) {
                lwError("Json error:%@", [error localizedDescription]);
                return;
            }
            
            _rooms = [NSMutableArray array];
            for (NSDictionary *dict in array) {
                SldBattleRoom *room = [[SldBattleRoom alloc] initWithDict:dict];
                [_rooms addObject:room];
            }
            [self.collectionView reloadData];
            _lastUpdateTime = [NSDate dateWithTimeIntervalSinceNow:0];
        }];
    }
    [self.collectionView reloadData];
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    SldBattleCell *cell = sender;
    SldGameData *gd = [SldGameData getInstance];
    if (cell.room.BetCoin > gd.playerInfo.goldCoin ) {
        [[[UIAlertView alloc] initWithTitle:@"金币不足"
                                    message:@"去商店购买更多金币吗？"
                           cancelButtonItem:[RIButtonItem itemWithLabel:@"取消" action:^{
            // Handle "Cancel"
        }]
                           otherButtonItems:[RIButtonItem itemWithLabel:@"去商店" action:^{
            SldIapController* vc = (SldIapController*)[getStoryboard() instantiateViewControllerWithIdentifier:@"iapController"];
            [self.navigationController pushViewController:vc animated:YES];
        }], nil] show];
        return NO;
    }
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if ([segue.identifier compare:@"cellSegue"] == 0) {
        SldBattleLinkController *vc = [segue destinationViewController];
        SldBattleCell *cell = sender;
        vc.roomName = cell.room.Name;
    }
}

#pragma mark <UICollectionViewDataSource>

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _rooms.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    SldBattleCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];
    
    SldBattleRoom *room = [_rooms objectAtIndex:indexPath.row];
    if (room) {
        if (room.BetCoin == 0) {
            cell.prizeLabel.text = [NSString stringWithFormat:@"练习场"];
        } else {
            cell.prizeLabel.text = [NSString stringWithFormat:@"%d金币", room.BetCoin];
        }
        
        cell.playerNumLabel.text = [NSString stringWithFormat:@"正在玩：%d", room.PlayerNum];
        cell.room = room;
        
        float hue = 200.0/360.0 - 0.16 * indexPath.row;
        while (hue < 0) {
            hue += 1.0;
        }
        cell.backgroundColor = [UIColor colorWithHue:hue saturation:0.22f brightness:0.83f alpha:1.0f];
    }
    
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    if (kind == UICollectionElementKindSectionHeader) {
        SldBattleSelectHeader *header = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"battelHeader" forIndexPath:indexPath];
        
        SldGameData *gd = [SldGameData getInstance];
        PlayerInfo *playerInfo = gd.playerInfo;
        [SldUtil loadAvatar:header.userAvatarView gravatarKey:playerInfo.gravatarKey customAvatarKey:playerInfo.customAvatarKey];
        
        header.coinLabel.text = [NSString stringWithFormat:@"%d", gd.playerInfo.goldCoin];
        
        return header;
    }
    return nil;
}

#pragma mark <UICollectionViewDelegate>

/*
// Uncomment this method to specify if the specified item should be highlighted during tracking
- (BOOL)collectionView:(UICollectionView *)collectionView shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath {
	return YES;
}
*/

/*
// Uncomment this method to specify if the specified item should be selected
- (BOOL)collectionView:(UICollectionView *)collectionView shouldSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}
*/

/*
// Uncomment these methods to specify if an action menu should be displayed for the specified item, and react to actions performed on the item
- (BOOL)collectionView:(UICollectionView *)collectionView shouldShowMenuForItemAtIndexPath:(NSIndexPath *)indexPath {
	return NO;
}

- (BOOL)collectionView:(UICollectionView *)collectionView canPerformAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
	return NO;
}

- (void)collectionView:(UICollectionView *)collectionView performAction:(SEL)action forItemAtIndexPath:(NSIndexPath *)indexPath withSender:(id)sender {
	
}
*/

@end
