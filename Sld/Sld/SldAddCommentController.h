//
//  SldAddCommentController.h
//  Sld
//
//  Created by Wei Li on 14-5-10.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SldCommentController.h"

@interface SldAddCommentController : UIViewController
@property (weak, nonatomic) SldCommentController *commentController;
@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (nonatomic) NSString *restoreText;
@end
