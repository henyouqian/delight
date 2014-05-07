//
//  SldEventListViewController.m
//  Sld
//
//  Created by Wei Li on 14-4-18.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldEventListViewController.h"
#import "SldHttpSession.h"
#import "SldEventDetailViewController.h"
#import "SldGameData.h"
#import "util.h"
#import "config.h"
#import "SldStreamPlayer.h"
#import "UIImage+animatedGIF.h"

NSString *CELL_ID = @"cellID";

@interface EventCell()
@property (weak, nonatomic) IBOutlet UIImageView *image;
@property (weak, nonatomic) IBOutlet UIView *highlight;
@property (weak, nonatomic) IBOutlet UILabel *statusLabel;
@property (weak, nonatomic) IBOutlet UILabel *dateLabel;

@end

@implementation EventCell

- (id)initWithCoder:(NSCoder *)aDecoder {
    self = [super initWithCoder:aDecoder];
    if (self) {
    }
    return self;
}

- (void)setHighlighted:(BOOL)highlighted {
    [self.highlight setHidden:!highlighted];
}

@end


@interface SldEventListViewController ()
@property (weak, nonatomic) IBOutlet UIBarButtonItem *musicButton;
@property (nonatomic) UIRefreshControl *refreshControl;
@property (nonatomic) UIImage *loadingImage;
@property (nonatomic) SldGameData *gameData;
@end

static __weak SldEventListViewController *g_inst = nil;


@implementation SldEventListViewController

+ (instancetype)getInstance {
    return g_inst;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [_gameData.eventInfos count];
}


// The cell that is returned must be retrieved from a call to -dequeueReusableCellWithReuseIdentifier:forIndexPath:
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    EventCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:CELL_ID forIndexPath:indexPath];
    
    //
    NSInteger idx = indexPath.row;
    if (idx >= [_gameData.eventInfos count]) {
        lwError("Out of range.");
        return cell;
    }
    EventInfo *event = [_gameData.eventInfos objectAtIndex:idx];
    
    //
    Config *conf = [Config sharedConf];
    NSString *thumbPath = makeDocPath([NSString stringWithFormat:@"%@/%@", conf.IMG_CACHE_DIR, event.thumb]);
    
    //from local
    if ([[NSFileManager defaultManager] fileExistsAtPath:thumbPath]) {
        UIImage *image = [UIImage imageWithContentsOfFile:thumbPath];
//        UIImage *image = nil;
//        if ([[[thumbPath pathExtension] lowercaseString] compare:@"gif"] == 0) {
//            NSURL *url = [NSURL fileURLWithPath:thumbPath];
//            image = [UIImage animatedImageWithAnimatedGIFURL:url];
//        } else {
//            image = [UIImage imageWithContentsOfFile:thumbPath];
//        }
        cell.image.image = image;
    }
    //from server
    else {
        cell.image.image = _loadingImage;
        
        //download
        SldHttpSession *session = [SldHttpSession defaultSession];
        [session downloadFromUrl:[NSString stringWithFormat:@"%@/%@", conf.DATA_HOST, event.thumb]
                          toPath:thumbPath
                        withData:nil completionHandler:^(NSURL *location, NSError *error, id data)
        {
            [self.collectionView reloadItemsAtIndexPaths:[NSArray arrayWithObjects:indexPath, nil]];
        }];
    }
    
    //check finished
    NSDate *now = getServerNow();
    if ([event.beginTime compare:now] == NSOrderedAscending && [now compare:event.endTime] == NSOrderedAscending) {
        [cell.statusLabel setHidden:NO];
        cell.statusLabel.text = @"进行中";
        //cell.statusLabel.backgroundColor = makeUIColor(91, 212, 62, 180);
        cell.statusLabel.backgroundColor = makeUIColor(71, 186, 43, 180);
    } else if ([now compare:event.beginTime] == NSOrderedAscending) {
        [cell.statusLabel setHidden:NO];
        cell.statusLabel.text = @"即将开启";
        cell.statusLabel.backgroundColor = makeUIColor(212, 62, 91, 180);
    } else {
        [cell.statusLabel setHidden:YES];
    }
    
    //datelabel
    NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
    [dateFormatter setTimeStyle:NSDateFormatterNoStyle];
    [dateFormatter setDateStyle:NSDateFormatterMediumStyle];
    NSLocale *usLocale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
    [dateFormatter setLocale:usLocale];
    NSString *strDate = [dateFormatter stringFromDate:event.beginTime];
    NSArray *comps = [strDate componentsSeparatedByString:@","];
    cell.dateLabel.text = [comps objectAtIndex:0];
    
    return cell;
}

- (void)viewDidLoad
{
    g_inst = self;
    [super viewDidLoad];
    
    _gameData = [SldGameData getInstance];
    
    //creat image cache dir
    NSString *imgCacheDir = makeDocPath(@"imgCache");
    [[NSFileManager defaultManager] createDirectoryAtPath:imgCacheDir withIntermediateDirectories:YES attributes:nil error:nil];
    
    //refresh control
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.collectionView.alwaysBounceVertical = YES;
    [self.collectionView addSubview:self.refreshControl];
    [self.refreshControl addTarget:self action:@selector(refershControlAction) forControlEvents:UIControlEventValueChanged];
    
    //login view
    UIStoryboard *storyboard = [UIStoryboard storyboardWithName:@"Main_iPhone" bundle:nil];
    UIViewController* controller = [storyboard instantiateViewControllerWithIdentifier:@"login"];
    //[self.navigationController pushViewController:controller animated:NO];
    [self presentViewController:controller animated:NO completion:nil];
    
    //
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(didBecomeActiveNotification)
                                                name:UIApplicationDidBecomeActiveNotification
                                              object:nil];
    
    //
    _loadingImage = [UIImage imageNamed:@"img/loading.png"];
}

- (void)refreshList {
    NSDictionary *body = @{@"StartId":@0, @"Limit":@50};
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"event/list" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
    {
        [self.refreshControl endRefreshing];
        
        if (error) {
            lwError("Http Error: event/list, error=%@", [error localizedDescription]);
            return;
        }
        NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error, error=%@", [error localizedDescription]);
            return;
        }
        
        NSMutableArray *insertIndexPaths = [NSMutableArray arrayWithCapacity:20];
        EventInfo *oldLatestEvent = nil;
        if ([_gameData.eventInfos count]) {
            oldLatestEvent = _gameData.eventInfos[0];
        }
        for (int i = 0; i < [array count]; ++i) {
            EventInfo *event = [[EventInfo alloc] init];
            NSDictionary *dict = array[i];
            event.id = [(NSNumber*)dict[@"Id"] unsignedLongLongValue];
            event.thumb = dict[@"Thumb"];
            event.packId = [(NSNumber*)dict[@"PackId"] unsignedLongLongValue];
            event.beginTime = [NSDate dateWithTimeIntervalSince1970:[(NSNumber*)dict[@"BeginTime"] longLongValue]];
            event.endTime = [NSDate dateWithTimeIntervalSince1970:[(NSNumber*)dict[@"EndTime"] longLongValue]];
            
            if (oldLatestEvent && oldLatestEvent.id == event.id) {
                break;
            }
            
            [_gameData.eventInfos insertObject:event atIndex:i];
            [insertIndexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0] ];
        }
        [self.collectionView insertItemsAtIndexPaths:insertIndexPaths];
        
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    
    if ([_gameData.eventInfos count] == 0) {
        [self refreshList];
    }
    
    [self didBecomeActiveNotification];
}

- (void)didBecomeActiveNotification {
    UIView *view = [_musicButton valueForKey:@"view"];
    if ([SldStreamPlayer defautPlayer].playing && ![SldStreamPlayer defautPlayer].paused) {
        CABasicAnimation* rotationAnimation;
        rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
        rotationAnimation.toValue = [NSNumber numberWithFloat: M_PI * 2.0];
        rotationAnimation.duration = 2.f;
        rotationAnimation.cumulative = YES;
        rotationAnimation.repeatCount = 10000000;
        
        [view.layer addAnimation:rotationAnimation forKey:@"rotationAnimation"];
    } else {
        [view.layer removeAllAnimations];
    }
}

- (void)refershControlAction {
    [self refreshList];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if (segue.identifier && [segue.identifier compare:@"toEventHub"] == 0) {
        NSIndexPath *selectedIndexPath = [[self.collectionView indexPathsForSelectedItems] objectAtIndex:0];
        NSInteger row = selectedIndexPath.row;
        if (row < [_gameData.eventInfos count]) {
            _gameData.eventInfo = [_gameData.eventInfos objectAtIndex:row];
        }
    }
}


@end
