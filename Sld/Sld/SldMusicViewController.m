//
//  SldMusicViewController.m
//  Sld
//
//  Created by Wei Li on 14-4-30.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldMusicViewController.h"
#import "SldHttpSession.h"
#import "config.h"
#import "SldUtil.h"
#import "MarqueeLabel.h"

NSString *listChannelUrl = @"http://douban.fm/j/explore/hot_channels";
NSArray *_channels = nil;

//SldMusicHeaderView
@interface SldMusicHeaderView : UICollectionReusableView
@property (weak, nonatomic) IBOutlet MarqueeLabel *label;
@end

@implementation SldMusicHeaderView
@end


//#pragma mark - ChannelCell

@interface ChannelCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIImageView *coverView;
@property (weak, nonatomic) IBOutlet UILabel *label;
@end

@implementation ChannelCell
@end


//#pragma mark - SldMusicViewController

@interface SldMusicViewController ()
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@property (weak, nonatomic) ChannelCell *currentChannelCell;

@property (nonatomic) MarqueeLabel *headerLabel;
@end

@implementation SldMusicViewController

- (IBAction)onNextButton:(id)sender {
    SldStreamPlayer *player = [SldStreamPlayer defautPlayer];
    if (player.channelId < 0 || [player.songs count] == 0) {
        return;
    }
    [player next];
    int row = 0;
    for (NSDictionary *channel in _channels) {
        if ([[channel objectForKey:@"id"] intValue] == player.channelId) {
            [self.collectionView reloadItemsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:row inSection:0]]];
            break;
        }
        row++;
    }
}

- (void)dealloc {
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _currentChannelCell = nil;
    
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
    //_collectionView.contentOffset = CGPointMake(0.f, 40.f);
    //_collectionView.contentInset = UIEdgeInsetsMake(20, 0, 0, 0);
    
    //get channel list
    if (_channels == nil) {
        NSURLSessionConfiguration *conf = [NSURLSessionConfiguration defaultSessionConfiguration];
        NSURLSession *session = [NSURLSession sessionWithConfiguration:conf delegate:nil delegateQueue: [NSOperationQueue mainQueue]];
        
        NSURL *url = [NSURL URLWithString:listChannelUrl];
        NSURLSessionDataTask * task = [session dataTaskWithURL:url completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (!error) {
                NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
                _channels = dict[@"data"][@"channels"];
                [_collectionView reloadData];
            }
        }];
        [task resume];
    }
    
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(didBecomeActiveNotification)
                                                name:UIApplicationDidBecomeActiveNotification
                                              object:nil];
    
    [SldStreamPlayer defautPlayer].delegate = self;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

#pragma mark - UICollectionView DataSource

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
    return [_channels count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    ChannelCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"channelCell" forIndexPath:indexPath];
    
    //download or load icon
    NSDictionary *channel = [_channels objectAtIndex:[indexPath row]];
    if (!channel) return cell;
    
    int channelId = [[channel objectForKey:@"id"] intValue];
    SldStreamPlayer *player = [SldStreamPlayer defautPlayer];
    if (channelId == player.channelId && (player.playing || player.paused) ) {
        if (player.paused) {
            cell.coverView.hidden = YES;
            _currentChannelCell = cell;
        } else if (player.playing) {
            [self startRotateCell:cell];
        }
    }
    
    Config *conf = [Config sharedConf];
    NSString *thumbRemote = [channel objectForKey:@"banner"];
    
    //local file name
    NSData *plainData = [thumbRemote dataUsingEncoding:NSUTF8StringEncoding];
    NSString *localFileName = [plainData base64EncodedStringWithOptions:0];
    
//    if (cell.imageView.image) {
//        return cell;
//    }
    //
    NSString *thumbLocal = makeDocPath([NSString stringWithFormat:@"%@/%@", conf.IMG_CACHE_DIR, localFileName]);
    if ([[NSFileManager defaultManager] fileExistsAtPath:thumbLocal]) { //local
        UIImage *image = [UIImage imageWithContentsOfFile:thumbLocal];
        //image = [image imageWithGradientTintColor:[UIColor colorWithRed:0.3 green:0.3 blue:0 alpha:.5]];
        //image = [image imageWithTintColor:[UIColor colorWithRed:0.3 green:0.3 blue:0.2 alpha:.5] blendMode:kCGBlendModeMultiply];
        //image = [self setImage:image alpha:.5f];
        cell.imageView.image = image;
        
        CALayer* maskLayer = [CALayer layer];
        float d = cell.imageView.frame.size.width*0.94;
        float offset = (cell.imageView.frame.size.width - d)*0.5;
        maskLayer.frame = CGRectMake(offset, offset, d, d);
        maskLayer.contents = (__bridge id)[[UIImage imageNamed:@"btnBgWhite90.png"] CGImage];
        cell.imageView.layer.mask = maskLayer;
        
        //cell.coverView.frame = CGRectMake(3, 3, 74, 74);
        cell.label.text = [channel objectForKey:@"name"];
        
        
        //fade in
        cell.imageView.alpha = 0.0;
        cell.label.alpha = 0.0;
        [UIView beginAnimations:@"fade in" context:nil];
        [UIView setAnimationDuration:0.8];
        cell.imageView.alpha = 1.0;
        cell.label.alpha = 1.0;
        [UIView commitAnimations];
    } else { //server
        //            UIImage *image = [UIImage imageNamed:@"img/loading.png"];
        //            cell.imageView.image = image;
        
        //download
        SldHttpSession *session = [SldHttpSession defaultSession];
        [session downloadFromUrl:thumbRemote
                          toPath:thumbLocal
                        withData:nil completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error, id data)
         {
             [self.collectionView reloadItemsAtIndexPaths:[NSArray arrayWithObjects:indexPath, nil]];
         }];
    }
    
    return cell;
}

static NSString *animKey = @"cellRotationAnimation";

#pragma mark - UICollectionViewDelegate
-(void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *channel = [_channels objectAtIndex:indexPath.row];
    if (!channel) return;
    int channelId = [[channel objectForKey:@"id"] intValue];
    
    SldStreamPlayer *player = [SldStreamPlayer defautPlayer];
    
    //
    ChannelCell *cell = (ChannelCell*)[collectionView cellForItemAtIndexPath:indexPath];
    
    //pause
    if (channelId == player.channelId && player.playing && !player.paused) {
        [player pause];
        [self stopRotateCell:cell];
    }
    //begin chanel
    else {
        if (_currentChannelCell) {
            _currentChannelCell.coverView.hidden = NO;
            [self stopRotateCell:_currentChannelCell];
        }
        [player setChannel:channelId];
        [player play];
        [self startRotateCell:cell];
    }
    
//    CALayer *layer = cell.imageView.layer;
//    CABasicAnimation* anim = (CABasicAnimation*)[cell.imageView.layer animationForKey:animKey];
//    if (!anim) {
//        anim = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
//        anim.toValue = [NSNumber numberWithFloat: M_PI * 2.0];
//        anim.duration = 2.f;
//        anim.cumulative = NO;
//        anim.repeatCount = 10000000;
//        
//        [layer addAnimation:anim forKey:animKey];
//        [player setChannel:channelId];
//        [player play];
//    } else if (layer.speed == 0) {
//        //start
//        CFTimeInterval pausedTime = [layer timeOffset];
//        layer.speed = 1.0;
//        layer.timeOffset = 0.0;
//        layer.beginTime = 0.0;
//        CFTimeInterval timeSincePause = [layer convertTime:CACurrentMediaTime() fromLayer:nil] - pausedTime;
//        layer.beginTime = timeSincePause;
//        [player setChannel:channelId];
//        [player play];
//    } else {
//        //stop
//        CFTimeInterval pausedTime = [layer convertTime:CACurrentMediaTime() fromLayer:nil];
//        layer.speed = 0.0;
//        layer.timeOffset = pausedTime;
//        [player stop];
//    }
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    if (kind == UICollectionElementKindSectionHeader) {
        SldMusicHeaderView *headerView = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"musicHeaderView" forIndexPath:indexPath];
        
        _headerLabel = headerView.label;
        _headerLabel.text = @"请选择电台";
        _headerLabel.textColor = [UIColor whiteColor];
        _headerLabel.marqueeType = MLContinuous;
        _headerLabel.continuousMarqueeExtraBuffer = 100;
        _headerLabel.fadeLength = 20;
        
        //
        SldStreamPlayer *player = [SldStreamPlayer defautPlayer];
        if (player.songs.count) {
            Song *song = [player.songs objectAtIndex:player.songIdx];
            if (song) {
                [self onSongChangeWithTitle:song.title artist:song.artist];
            }
        }
        
        return headerView;
    }
    
    
    return nil;
}

- (void)collectionView:(UICollectionView *)collectionView didDeselectItemAtIndexPath:(NSIndexPath *)indexPath {
//    NSDictionary *channel = [_channels objectAtIndex:indexPath.row];
//    if (channel && [[channel objectForKey:@"id"] intValue] == [SldStreamPlayer defautPlayer].channelId) {
//        ChannelCell *cell = (ChannelCell*)[collectionView cellForItemAtIndexPath:indexPath];
//        [self stopRotateCell:cell];
//        //[[SldStreamPlayer defautPlayer] stop];
//    }
}

- (void)startRotateCell:(ChannelCell*)cell {
    CALayer *layer = cell.imageView.layer;
    CABasicAnimation* anim = (CABasicAnimation*)[cell.imageView.layer animationForKey:animKey];
    
    if (!anim) {
        anim = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        anim.toValue = [NSNumber numberWithFloat: M_PI * 2.0];
        anim.duration = 60.f/33.33f;
        anim.cumulative = NO;
        anim.repeatCount = 10000000;
        
        [layer addAnimation:anim forKey:animKey];
    }
    if (layer.speed == 0) {
        //start
        CFTimeInterval pausedTime = [layer timeOffset];
        layer.speed = 1.0;
        layer.timeOffset = 0.0;
        layer.beginTime = 0.0;
        CFTimeInterval timeSincePause = [layer convertTime:CACurrentMediaTime() fromLayer:nil] - pausedTime;
        layer.beginTime = timeSincePause;
    }
    
    _currentChannelCell = cell;
    
    cell.coverView.hidden = YES;
}

- (void)stopRotateCell:(ChannelCell*)cell {
    CALayer *layer = cell.imageView.layer;
    
    CFTimeInterval pausedTime = [layer convertTime:CACurrentMediaTime() fromLayer:nil];
    layer.speed = 0.0;
    layer.timeOffset = pausedTime;
    
    //_rotatingCell = nil;
    //cell.coverView.hidden = NO;
}

- (void)didBecomeActiveNotification {
    SldStreamPlayer *player = [SldStreamPlayer defautPlayer];
    int row = 0;
    for (NSDictionary *channel in _channels) {
        if ([[channel objectForKey:@"id"] intValue] == player.channelId) {
            [self.collectionView reloadItemsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:row inSection:0]]];
            break;
        }
        row++;
    }
}

- (void)onSongChangeWithTitle:(NSString*)title artist:(NSString*)artist {
    if (_headerLabel) {
        _headerLabel.text = [NSString stringWithFormat:@"%@【%@】", title, artist];
        [_headerLabel restartLabel];
    }
}

@end





