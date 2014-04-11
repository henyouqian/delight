//
//  util.m
//  Sld
//
//  Created by Wei Li on 14-4-7.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "util.h"

NSString* getResFullPath(NSString* fileName) {
    return [[NSBundle mainBundle] pathForResource:fileName ofType:nil];
}
