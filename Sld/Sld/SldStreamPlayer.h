//
//  SldStreamPlayer.h
//  Sld
//
//  Created by Wei Li on 14-4-29.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface Song : NSObject <DOUAudioFile>
@property (nonatomic, strong) NSString *artist;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, strong) NSURL *audioFileURL;
@property (nonatomic, strong) NSNumber *sid;
@end

@interface SldStreamPlayer : NSObject

+ (instancetype)defautPlayer;

- (void)setChannel:(int)channel;
- (void)play;
- (void)stop;
- (void)next;

@end
