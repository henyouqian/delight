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

@protocol SldStreamPlayerDelegate <NSObject>
@required
- (void)onSongChangeWithTitle:(NSString*)title artist:(NSString*)artist;
@end

typedef void (^FadeoutBlock) ();

@interface SldStreamPlayer : NSObject

@property (nonatomic) int channelId;
@property (nonatomic) BOOL playing;
@property (nonatomic) BOOL paused;
@property (nonatomic) NSMutableArray *songs;
@property (nonatomic) int songIdx;
@property (weak, nonatomic) id <SldStreamPlayerDelegate> delegate;

+ (instancetype)defautPlayer;

- (void)setChannel:(int)channel;
- (void)play;
- (void)stop;
- (void)pause;
- (void)next;
- (void)fadeoutAndStop;
- (void)fadeoutWithCompletionBlock:(FadeoutBlock)block;

- (void)save;
- (void)load;

@end
