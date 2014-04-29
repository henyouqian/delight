//
//  SldStreamPlayer.m
//  Sld
//
//  Created by Wei Li on 14-4-29.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldStreamPlayer.h"
#import "SldHttpSession.h"

NSString *listSongUrl = @"http://www.douban.com/j/app/radio/people";
static void *kStatusKVOKey = &kStatusKVOKey;
static void *kDurationKVOKey = &kDurationKVOKey;
static void *kBufferingRatioKVOKey = &kBufferingRatioKVOKey;

@implementation Song

@end

@interface SldStreamPlayer()
@property (nonatomic) int channel;
@property (nonatomic) DOUAudioStreamer *streamer;
@property (nonatomic) BOOL playing;
@property (nonatomic) NSMutableArray *songs;
@property (nonatomic) int songIdx;
@property (nonatomic) NSURLSession *session;
@end

@implementation SldStreamPlayer

+ (instancetype)defautPlayer {
    static SldStreamPlayer *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        [DOUAudioStreamer setOptions:[DOUAudioStreamer options] | DOUAudioStreamerRequireSHA256];
        inst = [[self alloc] init];
    });
    return inst;
}

- (instancetype)init {
    if (self = [super init]) {
        _channel = -1;
        _playing = NO;
        _streamer = nil;
        _songs = [NSMutableArray arrayWithCapacity:10];
        _songIdx = -1;
        NSURLSessionConfiguration *conf = [NSURLSessionConfiguration defaultSessionConfiguration];
        _session = [NSURLSession sessionWithConfiguration:conf delegate:nil delegateQueue: [NSOperationQueue mainQueue]];
    }
    return self;
}

- (void)setChannel:(int)channel {
    if (channel == _channel) return;
    
    NSMutableString *urlString = [NSMutableString stringWithFormat:@"%@?version=100&app_name=radio_desktop_win&channel=%d&type=n", listSongUrl, channel];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSURLSessionDataTask * task = [_session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!error) {
            _channel = channel;
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            [_songs removeAllObjects];
            for (NSDictionary *songDict in [dict objectForKey:@"song"]) {
                Song *song = [[Song alloc] init];
                [song setArtist:[songDict objectForKey:@"artist"]];
                [song setTitle:[songDict objectForKey:@"title"]];
                [song setSid:[songDict objectForKey:@"sid"]];
                [song setAudioFileURL:[NSURL URLWithString:[songDict objectForKey:@"url"]]];
                [_songs addObject:song];
            }
            _songIdx = 0;
            [self resetStreamer];
        }
    }];
    [task resume];
}

- (void)play {
    if (_playing) return;
    _playing = YES;
    [_streamer play];
}

- (void)stop {
    if (!_playing) return;
    _playing = NO;
    [_streamer stop];
}

- (void)resetStreamer {
    if (_songIdx <= 0 && _songIdx >= [_songs count]) {
        return;
    }
    
    @try {
        [self stop];
        if (_streamer) {
            [_streamer removeObserver:self forKeyPath:@"status"];
        }
        _streamer = [DOUAudioStreamer streamerWithAudioFile:_songs[_songIdx]];
        [_streamer addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:kStatusKVOKey];
        [self play];
    }
    @catch(NSException* ex) {
        NSLog(@"Bug captured");
    }
    
}

- (void)next {
    [self stop];
    
    if (_songIdx < [_songs count]-1) {
        _songIdx++;
        [self resetStreamer];
        return;
    }
    
    //
    if ([_songs count] == 0) return;
    
    Song *lastSong = [_songs lastObject];
    NSMutableString *urlString = [NSMutableString stringWithFormat:@"%@?version=100&app_name=radio_desktop_win&channel=%d&type=p&sid=%d", listSongUrl, _channel, [lastSong.sid intValue]];
    NSURL *url = [NSURL URLWithString:urlString];
    
    NSURLSessionDataTask * task = [_session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (!error) {
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
            [_songs removeAllObjects];
            for (NSDictionary *songDict in [dict objectForKey:@"song"]) {
                Song *song = [[Song alloc] init];
                [song setArtist:[songDict objectForKey:@"artist"]];
                [song setTitle:[songDict objectForKey:@"title"]];
                [song setSid:[songDict objectForKey:@"sid"]];
                [song setAudioFileURL:[NSURL URLWithString:[songDict objectForKey:@"url"]]];
                [_songs addObject:song];
            }
            _songIdx = 0;
            [self resetStreamer];
        }
    }];
    [task resume];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == kStatusKVOKey) {
        [self performSelector:@selector(_updateStatus)
                     onThread:[NSThread mainThread]
                   withObject:nil
                waitUntilDone:NO];
    }
//    else if (context == kDurationKVOKey) {
//        [self performSelector:@selector(_timerAction:)
//                     onThread:[NSThread mainThread]
//                   withObject:nil
//                waitUntilDone:NO];
//    }
//    else if (context == kBufferingRatioKVOKey) {
//        [self performSelector:@selector(_updateBufferingStatus)
//                     onThread:[NSThread mainThread]
//                   withObject:nil
//                waitUntilDone:NO];
//    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void)_updateStatus
{
    switch ([_streamer status]) {
        case DOUAudioStreamerPlaying:
            break;
            
        case DOUAudioStreamerPaused:
            break;
            
        case DOUAudioStreamerIdle:
            break;
            
        case DOUAudioStreamerFinished:
            [self next];
            break;
            
        case DOUAudioStreamerBuffering:
            break;
            
        case DOUAudioStreamerError:
            break;
    }
}

@end
