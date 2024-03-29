//
//  SldMyMatchController.h
//  pin
//
//  Created by 李炜 on 14-8-16.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SldMyMatchListController : UICollectionViewController <QBImagePickerControllerDelegate>

+ (instancetype)getInst;
- (void)onTabSelect;
- (void)refresh;

@end


//================================
@interface SldMatchPromoWebController : UIViewController
@property (nonatomic) NSURL *url;
@property (weak, nonatomic) IBOutlet UIWebView *reviewView;
@end

//==========================
@interface SldMyMatchImagePickListController : UICollectionViewController

- (void)setAssets :(NSArray *)assets;

@end