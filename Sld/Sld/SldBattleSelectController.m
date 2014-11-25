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


@interface SldBattleCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet UILabel *prizeLabel;
@property (weak, nonatomic) IBOutlet UILabel *enterFeeLabel;
@property (weak, nonatomic) IBOutlet UILabel *playerNumLabel;
@property (weak, nonatomic) IBOutlet UIImageView *coinImage;

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

@end

@implementation SldBattleSelectController

static NSString * const reuseIdentifier = @"BattleCell";

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    
//    self.tabBarController.navigationItem.title = self.tabBarItem.title;
//    self.tabBarController.automaticallyAdjustsScrollViewInsets = NO;
//    
//    UIEdgeInsets insets = self.collectionView.contentInset;
//    insets.top = 64;
//    insets.bottom = 50;
//    
//    self.collectionView.contentInset = insets;
//    self.collectionView.scrollIndicatorInsets = insets;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#pragma mark <UICollectionViewDataSource>

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return 6;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    UICollectionViewCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:reuseIdentifier forIndexPath:indexPath];
    
    // Configure the cell
    
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
