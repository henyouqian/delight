//
//  SldCouponCardController.h
//  pin
//
//  Created by 李炜 on 14-9-27.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <UIKit/UIKit.h>

//============================
@interface SldEcard : NSObject
@property (nonatomic) SInt64 Id;
@property (nonatomic) NSString *TypeKey;
@property (nonatomic) NSString *CouponCode;
@property (nonatomic) NSString *ExpireDate;
@property (nonatomic) NSString *GenDate;
@property (nonatomic) NSString *UserGetDate;
@property (nonatomic) NSString *Title;
@property (nonatomic) NSString *RechargeUrl;
@property (nonatomic) NSString *HelpText;

- (instancetype)initWithDict:(NSDictionary*)dict;
@end

//============================
@interface SldCouponCardController : UITableViewController

+ (instancetype)getInstance;
- (void)addEcard:(SldEcard*)ecard;

@end
