//
//  SldLikeMatchListController.h
//  pin
//
//  Created by 李炜 on 14-8-16.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SldLikeMatchListController : UICollectionViewController
+ (instancetype)getInst;
- (void)onTabSelect;
@end

extern BOOL g_needRefreshHotList;
