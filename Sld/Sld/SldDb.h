//
//  SldDb.h
//  Sld
//
//  Created by Wei Li on 14-4-24.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

@interface SldDb : NSObject

@property (nonatomic) FMDatabase *fmdb;

+ (instancetype)defaultDb;

@end
