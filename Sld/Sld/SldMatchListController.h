//
//  SldMatchListController.h
//  pin
//
//  Created by 李炜 on 14-8-16.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "UIImageView+sldAsyncLoad.h"
#import "SldGameData.h"

@interface SldMatchListController : UICollectionViewController
+ (instancetype)getInst;
- (void)onTabSelect;
@end

//============================
@interface SldMatchListCell : UICollectionViewCell

@property (weak, nonatomic) IBOutlet SldAsyncImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *prizeLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeLebel;
@property (nonatomic) Match* match;

@end

//============================
@interface SldMatchListFooter : UICollectionReusableView

@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spin;
@property (weak, nonatomic) IBOutlet UIButton *loadMoreButton;

@end
