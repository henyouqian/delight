//
//  SldGameController.h
//  Sld
//

//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldEventDetailViewController.h"
#import "SldGamePlay.h"

@interface SldGameController : UIViewController<SldGamePlayDelegate>
@property (nonatomic, weak) PackInfo* packInfo;
@end
