//
//  SldStreamPlayer.m
//  Sld
//
//  Created by Wei Li on 14-4-29.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldStreamPlayer.h"
#import "SldHttpSession.h"

//NSString *listSongUrl = @"http://www.douban.com/j/app/radio/people";
NSString *listSongUrl = @"http://douban.fm/j/mine/playlist";
static void *kStatusKVOKey = &kStatusKVOKey;
static void *kDurationKVOKey = &kDurationKVOKey;
static void *kBufferingRatioKVOKey = &kBufferingRatioKVOKey;


@implementation Song

@end

@interface SldStreamPlayer()
@property (nonatomic) DOUAudioStreamer *streamer;
@property (nonatomic) NSURLSession *session;
@property (weak, nonatomic) NSTimer *timer;
@property (nonatomic) BOOL fadeout;
@property (strong, nonatomic) FadeoutBlock fadeoutBlock;
@property (nonatomic) BOOL inFadeoutBlock;

@property (nonatomic) int savedChannelId;
@property (nonatomic) NSMutableArray *savedSongs;
@property (nonatomic) int savedSongIdx;

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
        _channelId = -1;
        _playing = NO;
        _paused = NO;
        _streamer = nil;
        _songs = [NSMutableArray arrayWithCapacity:10];
        _savedSongs = nil;
        _songIdx = -1;
        NSURLSessionConfiguration *conf = [NSURLSessionConfiguration defaultSessionConfiguration];
        _session = [NSURLSession sessionWithConfiguration:conf delegate:nil delegateQueue: [NSOperationQueue mainQueue]];
        _timer = nil;
        _fadeout = NO;
        _fadeoutBlock = nil;
        _inFadeoutBlock = NO;
    }
    return self;
}

- (void)dealloc {
    
}

- (void)onTimer {
    if (_fadeout && _streamer && _streamer.volume > 0.01f) {
        _streamer.volume -= .05f;
        if ( _streamer.volume <= 0.f) {
            _streamer.volume = 0.f;
            [self stop];
            [_timer invalidate];
            _timer = nil;
        }
    }
}

- (void)setChannel:(int)channel {
    if (channel == _channelId) return;
    _channelId = channel;
    [self stop];
    
//    NSMutableString *urlString = [NSMutableString stringWithFormat:@"%@?version=100&app_name=radio_desktop_win&channel=%d&type=n", listSongUrl, channel];
    NSMutableString *urlString = [NSMutableString stringWithFormat:@"%@?from=mainsite&kbps=128&channel=%d&type=n", listSongUrl, channel];
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

- (void)play {
    if (_playing) {
        return;
    }
    _playing = YES;
    _paused = NO;
    _fadeout = NO;
    [_streamer setVolume:1.0f];
    [_streamer play];
    
    [self cancelTimer];
}

- (void)stop {
    if (!_playing) return;
    _streamer.volume = 0.f;
    _playing = NO;
    _paused = NO;
    [_streamer stop];
    
    [self cancelTimer];
}

- (void)pause {
    if (!_playing || _paused) return;
    _playing = NO;
    _paused = YES;
    [_streamer pause];
    
    [self cancelTimer];
}

- (void)cancelTimer {
    if (_timer) {
        [_timer invalidate];
        _timer = nil;
        if (!_inFadeoutBlock) {
            _fadeoutBlock = nil;
        }
    }
}

- (void)fadeoutAndStop {
    if (_timer == nil) {
        _timer = [NSTimer scheduledTimerWithTimeInterval:.05f target:self selector:@selector(onTimer) userInfo:nil repeats:YES];
    }
    _fadeout = YES;
}

- (void)fadeoutWithCompletionBlock:(FadeoutBlock)block {
    //if (_fadoutBlock) return;
    if (!_playing) {
        _inFadeoutBlock = YES;
        block();
        _inFadeoutBlock = NO;
        _fadeoutBlock = nil;
        return;
    }
    
    _fadeoutBlock = block;
    if (_timer == nil) {
        _timer = [NSTimer scheduledTimerWithTimeInterval:.05f target:self selector:@selector(onFadeoutBlock) userInfo:nil repeats:YES];
    }
    _fadeout = YES;
}

- (void)onFadeoutBlock {
    if (_fadeout && _streamer && _streamer.volume > 0.01f) {
        _streamer.volume -= .03f;
        if ( _streamer.volume <= 0.f) {
            _streamer.volume = 0.f;
            _inFadeoutBlock = YES;
            _fadeoutBlock();
            _inFadeoutBlock = NO;
            [_timer invalidate];
            _timer = nil;
            _fadeoutBlock = nil;
        }
    }
}

- (void)resetStreamer {
    if (_songIdx <= 0 && _songIdx >= [_songs count]) {
        return;
    }
    
    [self stop];
    if (_streamer) {
        [_streamer removeObserver:self forKeyPath:@"status"];
    }
    Song *song = _songs[_songIdx];
    _streamer = [DOUAudioStreamer streamerWithAudioFile:song];
    if (_delegate) {
        [_delegate onSongChangeWithTitle:song.title artist:song.artist];
    }
    [_streamer addObserver:self forKeyPath:@"status" options:NSKeyValueObservingOptionNew context:kStatusKVOKey];
    [self play];
}

- (void)next {
    if ([_songs count] == 0) return;
    
    [self stop];
    
    if (_songIdx < [_songs count]-1) {
        _songIdx++;
        [self resetStreamer];
        return;
    }
    
    Song *lastSong = [_songs lastObject];
//    NSMutableString *urlString = [NSMutableString stringWithFormat:@"%@?version=100&app_name=radio_desktop_win&channel=%d&type=p&sid=%d", listSongUrl, _channel, [lastSong.sid intValue]];
    NSMutableString *urlString = [NSMutableString stringWithFormat:@"%@?from=mainsite&kbps=128&channel=%d&sid=%d&type=n", listSongUrl, _channelId, [lastSong.sid intValue]];
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

- (void)save {
    _savedSongs = [NSMutableArray arrayWithArray:_songs];
    _savedChannelId = _channelId;
    _savedSongIdx = _songIdx;
}

- (void)load {
    if (_savedSongs) {
        _songs = [NSMutableArray arrayWithArray:_savedSongs];
        _channelId = _savedChannelId;
        _songIdx = _savedSongIdx;
        [self resetStreamer];
    }
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
