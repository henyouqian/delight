//
//  SldCommentController.h
//  Sld
//
//  Created by Wei Li on 14-5-9.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SldCommentController : UIViewController<UITableViewDataSource, UITableViewDelegate, UIScrollViewDelegate, MWPhotoBrowserDelegate>
@property (weak, nonatomic) IBOutlet UITableView *tableView;
- (void)onViewShown;
- (void)onSendComment;
@end
