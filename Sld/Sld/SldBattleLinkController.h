//
//  SldBattleLinkController.h
//  pin
//
//  Created by 李炜 on 14/11/12.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SldEmojiController.h"

@interface SldBattleLinkController : UIViewController <SRWebSocketDelegate>
@property (nonatomic) NSString *roomName;
@end
