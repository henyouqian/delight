//
//  SldCommentController.h
//  Sld
//
//  Created by Wei Li on 14-5-9.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SldAdviceController : UITableViewController<UIScrollViewDelegate>
- (void)onSendAdvice;
@end

@interface SldAddAdviceController : UIViewController
@property (weak, nonatomic) IBOutlet UITextView *textView;
@end