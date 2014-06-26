//
//  SldIapController.h
//  Sld
//
//  Created by 李炜 on 14-6-18.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <StoreKit/StoreKit.h>

@interface SldIapManager : NSObject<SKPaymentTransactionObserver>
+ (instancetype)getInstance;
@property (nonatomic) UIAlertView *alt;
@end

@interface SldIapController : UICollectionViewController <SKProductsRequestDelegate>

@end
