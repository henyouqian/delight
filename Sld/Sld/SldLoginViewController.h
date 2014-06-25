//
//  SldLoginViewController.h
//  Sld
//
//  Created by Wei Li on 14-4-20.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SldLoginViewController : UIViewController<UITextFieldDelegate>
@property (nonatomic) BOOL shouldDismiss;
+ (void)createAndPresentWithCurrentController:(UIViewController*)currController animated:(BOOL)animated;
@end
