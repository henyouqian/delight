//
//  SldMatchListViewController.h
//  Sld
//
//  Created by Wei Li on 14-4-18.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SldMatchListViewController : UICollectionViewController

@end


@interface Cell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet UIImageView *image;
@property (weak, nonatomic) IBOutlet UIView *highlight;
@end

//@interface CollectionLayout : UICollectionViewFlowLayout

//@end