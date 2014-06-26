//
//  SldEventListViewController.h
//  Sld
//
//  Created by Wei Li on 14-4-18.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface EventCell : UICollectionViewCell
@end

@interface SldEventListViewController : UIViewController <UICollectionViewDelegate, UICollectionViewDataSource>
@end

@interface EventListFooterView : UICollectionReusableView

@end

//@interface CollectionLayout : UICollectionViewFlowLayout

//@end