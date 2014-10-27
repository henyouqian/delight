//
//  SldUserInfoController.h
//  Sld
//
//  Created by Wei Li on 14-5-13.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SldUserInfoController : UITableViewController <UITextFieldDelegate, UIActionSheetDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
+ (void)createAndPresentFromController:(UIViewController*)srcController cancelable:(BOOL)cancelable;
- (void)setGravartarWithKey:(NSString*)key url:(NSString*)url;
@end

@interface SldAvatarSelectController : UIViewController<UICollectionViewDataSource, UICollectionViewDelegate>
@property (weak, nonatomic) SldUserInfoController *userInfoController;
@end