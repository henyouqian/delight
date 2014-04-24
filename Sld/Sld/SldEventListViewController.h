//
//  SldEventListViewController.h
//  Sld
//
//  Created by Wei Li on 14-4-18.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SldEventListViewController : UICollectionViewController

@end

@interface Event : NSObject
@property (nonatomic) UInt64 id;
@property (nonatomic) UInt64 packId;
@property (nonatomic) NSString *thumb;
@end


@interface Cell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet UIImageView *image;
@property (weak, nonatomic) IBOutlet UIView *highlight;
@end

//@interface CollectionLayout : UICollectionViewFlowLayout

//@end