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
@property (nonatomic) NSString *Title;
@property (nonatomic) int BetCoin;
@property (nonatomic) int PlayerNum;
- (instancetype)initWithDict:(NSDictionary*)dict;
@end

@implementation SldBattleRoom
- (instancetype)initWithDict:(NSDictionary*)dict {
    if (self = [super init]) {
        _Name = dict[@"Name"];
        _Title = dict[@"Title"];
        _BetCoin = [(NSNumber*)dict[@"BetCoin"] intValue];
        _PlayerNum = [(NSNumber*)dict[@"PlayerNum"] intValue];
    }
    return self;
}
@end

//===============================
@interface SldBattleCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *prizeLabel;
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
@property (weak, nonatomic) IBOutlet UILabel *levelLabel;
@property (weak, nonatomic) IBOutlet UILabel *pointLabel;
@property (weak, nonatomic) IBOutlet UILabel *levelupLabel;
@property (weak, nonatomic) IBOutlet UILabel *winStreakLabel;
@property (weak, nonatomic) IBOutlet UILabel *winStreakMaxLabel;
@property (weak, nonatomic) IBOutlet UILabel *heartTimeLabel;

@end

@implementation SldBattleSelectHeader

@end


//==================================
@interface SldBattleSelectController ()

@property (nonatomic) NSMutableArray *rooms;
@property (nonatomic) NSDate *lastUpdateTime;
@property (nonatomic) SldBattleSelectHeader *header;
@property (nonatomic) MSWeakTimer *secTimer;


@end

@implementation SldBattleSelectController

static NSString * const reuseIdentifier = @"BattleCell";

- (void)viewDidLoad {
    _secTimer = [MSWeakTimer scheduledTimerWithTimeInterval:1.f target:self selector:@selector(updateHeart) userInfo:nil repeats:YES dispatchQueue:dispatch_get_main_queue()];
}

- (void)dealloc {
    [_secTimer invalidate];
}

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
    if (identifier && [identifier compare:@"cellSegue"] == 0) {
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
        if (cell.room.BetCoin == 0 && [gd.playerInfo getHeartNum]==0) {
            alert(@"♥︎不足，请等待", nil);
        }
        return YES;
    }
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if (segue.identifier && [segue.identifier compare:@"cellSegue"] == 0) {
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
        cell.titleLabel.text = room.Title;
        if (room.BetCoin == 0) {
            cell.prizeLabel.text = [NSString stringWithFormat:@"消耗1♥︎"];
        } else {
            cell.prizeLabel.text = [NSString stringWithFormat:@"输赢%d金币", room.BetCoin];
        }
        
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
        _header = [collectionView dequeueReusableSupplementaryViewOfKind:kind withReuseIdentifier:@"battelHeader" forIndexPath:indexPath];
        
        SldGameData *gd = [SldGameData getInstance];
        PlayerInfo *playerInfo = gd.playerInfo;
        [SldUtil loadAvatar:_header.userAvatarView gravatarKey:playerInfo.gravatarKey customAvatarKey:playerInfo.customAvatarKey];
        
        _header.coinLabel.text = [NSString stringWithFormat:@"%d", gd.playerInfo.goldCoin];
        
        NSString *levelTitle = [gd getPlayerBattleLevelTitle];
        _header.levelLabel.text = [NSString stringWithFormat:@"等级：%@", levelTitle];
        
        _header.pointLabel.text = [NSString stringWithFormat:@"积分：%d", gd.playerInfo.BattlePoint];
        
        _header.winStreakLabel.text = [NSString stringWithFormat:@"连胜：%d", gd.playerInfo.BattleWinStreak];
        
        _header.winStreakMaxLabel.text = [NSString stringWithFormat:@"最长连胜：%d", gd.playerInfo.BattleWinStreakMax];
        
        //heart
        [self updateHeart];
        
        //
        int battlePoint = gd.playerInfo.BattlePoint;
        int levelupPoint = 0;
        for (PlayerBattleLevel *lvData in gd.PLAYER_BATTLE_LEVELS) {
            if (lvData.StartPoint > battlePoint) {
                levelupPoint = lvData.StartPoint - battlePoint;
                break;
            }
        }
        _header.levelupLabel.text = [NSString stringWithFormat:@"升级还需：%d", levelupPoint];
        
        return _header;
    }
    return nil;
}

- (void)updateHeart {
    if (!_header) {
        return;
    }
    SldGameData *gd = [SldGameData getInstance];
    NSArray *heartArray = @[
                            @"♡♡♡♡♡♡♡♡♡♡",
                            @"♥︎♡♡♡♡♡♡♡♡♡",
                            @"♥︎♥︎♡♡♡♡♡♡♡♡",
                            @"♥︎♥︎♥︎♡♡♡♡♡♡♡",
                            @"♥︎♥︎♥︎♥︎♡♡♡♡♡♡",
                            @"♥︎♥︎♥︎♥︎♥︎♡♡♡♡♡",
                            @"♥︎♥︎♥︎♥︎♥︎♥︎♡♡♡♡",
                            @"♥︎♥︎♥︎♥︎♥︎♥︎♥︎♡♡♡",
                            @"♥︎♥︎♥︎♥︎♥︎♥︎♥︎♥︎♡♡",
                            @"♥︎♥︎♥︎♥︎♥︎♥︎♥︎♥︎♥︎♡",
                            @"♥︎♥︎♥︎♥︎♥︎♥︎♥︎♥︎♥︎♥︎",
                            ];
    int heartNum = [gd.playerInfo getHeartNum];
    if (heartNum >= heartArray.count || heartNum < 0) {
        _header.heartLabel.text = @"???";
        _header.heartTimeLabel.text = @"";
        return;
    }
    
    _header.heartLabel.text = heartArray[heartNum];
    if (heartNum == 10) {
        _header.heartTimeLabel.text = @"";
    } else {
        _header.heartTimeLabel.text = [gd.playerInfo getHeartTime];
    }
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

//==================================
@interface SldBattleSelectHelpController : UIViewController

@property (weak, nonatomic) IBOutlet UITextView *textView;

@end

@implementation SldBattleSelectHelpController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    SldGameData *gd = [SldGameData getInstance];
    NSMutableString *text = [NSMutableString string];
    
    [text appendString:gd.BATTLE_HELP_TEXT];
    for (PlayerBattleLevel *lvData in gd.PLAYER_BATTLE_LEVELS) {
        [text appendFormat:@"     积分%d －> %@\n", lvData.StartPoint, lvData.Title];
    }
    _textView.text = text;
    
    [_textView layoutIfNeeded];
    [_textView setContentOffset:CGPointZero];
}

@end
