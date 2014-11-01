//
//  SldAppDelegate.h
//  Sld
//
//  Created by Wei Li on 14-4-5.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SldAppDelegate : UIResponder <UIApplicationDelegate, SRWebSocketDelegate>

@property (strong, nonatomic) UIWindow *window;
@property (nonatomic) SRWebSocket *webSocket;

@end
