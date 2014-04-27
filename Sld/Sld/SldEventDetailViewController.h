//
//  SldEventDetailViewController.h
//  Sld
//
//  Created by Wei Li on 14-4-24.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "SldEventListViewController.h"

@interface PackInfo : NSObject
@property (nonatomic) UInt64 id;
@property (nonatomic) NSString *title;
@property (nonatomic) NSString *thumb;
@property (nonatomic) NSString *cover;
@property (nonatomic) NSString *coverBlur;
@property (nonatomic) NSArray *images;

+ (instancetype)packWithDictionary:(NSDictionary*)dict;
@end

@interface SldEventDetailViewController : UIViewController
@property (nonatomic, weak) Event* event;
@property (nonatomic) PackInfo* packInfo;
@end


