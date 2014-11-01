//
//  SldBattleController.h
//  pin
//
//  Created by 李炜 on 14/11/1.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SldBattleController : UITableViewController <SRWebSocketDelegate>

@property (nonatomic) SRWebSocket *webSocket;

@end
