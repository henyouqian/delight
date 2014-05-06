//
//  util.h
//  Sld
//
//  Created by Wei Li on 14-4-7.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

NSString* getResFullPath(NSString* fileName);
NSString* makeDocPath(NSString* path);
UIAlertView* alert(NSString *title, NSString *message);

BOOL imageExist(NSString *imageKey);
NSString* makeImagePath(NSString *imageKey);
NSString* makeImageServerUrl(NSString *imageKey);

UIColor* makeUIColor(int r, int g, int b, int a);

UIStoryboard* getStoryboard();

void setServerNow(SInt64 now);
NSDate* getServerNow();