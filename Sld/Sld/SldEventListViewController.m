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
#import "SldLoginViewController.h"
#import "util.h"
#import "config.h"
#import "SldStreamPlayer.h"
#import "SldDb.h"
#import "UIImageView+sldAsyncLoad.h"

NSString *CELL_ID = @"cellID";
static const int FETCH_EVENT_COUNT = 8;

@interface EventCell()
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
//@property (weak, nonatomic) IBOutlet UIView *highlight;
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
//
//- (void)setHighlighted:(BOOL)highlighted {
//    [self.highlight setHidden:!highlighted];
//}

@end


//
@interface SldCollectionView : UICollectionView
@end

@implementation SldCollectionView

- (void)setContentInset:(UIEdgeInsets)contentInset {
    if (self.tracking) {
        CGFloat diff = contentInset.top - self.contentInset.top;
        CGPoint translation = [self.panGestureRecognizer translationInView:self];
        translation.y -= diff * 3.0 / 2.0;
        [self.panGestureRecognizer setTranslation:translation inView:self];
    }
    [super setContentInset:contentInset];
}

@end

@interface EventListFooterView()
@property (weak, nonatomic) IBOutlet UILabel *label;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spinner;

@end

@implementation EventListFooterView

@end


@interface SldEventListViewController ()
@property (weak, nonatomic) IBOutlet UIBarButtonItem *musicButton;
@property (nonatomic) UIRefreshControl *refreshControl;
@property (nonatomic) UIImage *loadingImage;
@property (nonatomic) SldGameData *gameData;
@property (weak, nonatomic) EventListFooterView *footerView;
@property (nonatomic) BOOL fetching;
@property (nonatomic) BOOL bottomFetched;
@property (nonatomic) BOOL appendable;
@property (nonatomic) BOOL reachBottom;
@end

@implementation SldEventListViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _gameData = [SldGameData getInstance];
    _fetching = NO;
    _bottomFetched = NO;
    _appendable = YES;
    _reachBottom = NO;
    
    //creat image cache dir
    NSString *imgCacheDir = makeDocPath(@"imgCache");
    [[NSFileManager defaultManager] createDirectoryAtPath:imgCacheDir withIntermediateDirectories:YES attributes:nil error:nil];
    
    //refresh control
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.collectionView.alwaysBounceVertical = YES;
    [self.collectionView addSubview:self.refreshControl];
    [self.refreshControl addTarget:self action:@selector(refershControlAction) forControlEvents:UIControlEventValueChanged];
    
    //login view
    [SldLoginViewController createAndPresentWithCurrentController:self animated:NO];
    
    //
    [[NSNotificationCenter defaultCenter]addObserver:self
                                            selector:@selector(didBecomeActiveNotification)
                                                name:UIApplicationDidBecomeActiveNotification
                                              object:nil];
    
    //
    _loadingImage = [UIImage imageNamed:@"ui/loading.png"];
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

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)refershControlAction {
    [self refreshList];
}

- (void)refreshList {
    if (_fetching) {
        return;
    }
    
    FMDatabase *db = [SldDb defaultDb].fmdb;
    NSMutableArray *insertIndexPaths = [NSMutableArray arrayWithCapacity:20];
    
    //online
    if (_gameData.online) {
        NSDictionary *body = @{@"StartId":@0, @"Limit":@(FETCH_EVENT_COUNT)};
        SldHttpSession *session = [SldHttpSession defaultSession];
        
        _fetching = YES;
        [session postToApi:@"event/list" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
         {
             _fetching = NO;
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
             if (array.count == 0) {
                 return;
             }
             
             EventInfo *oldLatestEvent = nil;
             if ([_gameData.eventInfos count]) {
                 oldLatestEvent = _gameData.eventInfos[0];
             }
             
             EventInfo *newLastEvent = [EventInfo eventWithDictionary:array.lastObject];
             BOOL refreshAll = NO;
             if (newLastEvent && oldLatestEvent) {
                 if (newLastEvent.id > oldLatestEvent.id) {
                     refreshAll = YES;
                     [_gameData.eventInfos removeAllObjects];
                 }
             }
             
             for (int i = 0; i < [array count]; ++i) {
                 //EventInfo *event = [[EventInfo alloc] init];
                 NSDictionary *dict = array[i];
                 EventInfo *event = [EventInfo eventWithDictionary:dict];
                 
                 if (oldLatestEvent && oldLatestEvent.id >= event.id) {
                     break;
                 }
                 
                 [_gameData.eventInfos insertObject:event atIndex:i];
                 [insertIndexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
                 
                 NSData *eventData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
                 if (error) {
                     lwError("Json error, error=%@", [error localizedDescription]);
                     return;
                 }
                 
                 //save to db
                 FMResultSet *rs = [db executeQuery:@"SELECT packDownloaded FROM event WHERE id=?", dict[@"Id"]];
                 BOOL packDownloaded = NO;
                 if ([rs next]) {
                     packDownloaded = [rs boolForColumnIndex:0];
                 }
                 
                 BOOL ok = [db executeUpdate:@"REPLACE INTO event (id, data, packDownloaded) VALUES(?, ?, ?)", dict[@"Id"], eventData, @(packDownloaded)];
                 if (!ok) {
                     lwError("Sql error:%@", [db lastErrorMessage]);
                 }
             }
             
             if (refreshAll) {
                 [self.collectionView reloadData];
             }
             if (insertIndexPaths.count) {
                 [self.collectionView insertItemsAtIndexPaths:insertIndexPaths];
             }
         }];
    }
    
//    //offline
//    else {
//        [self.refreshControl endRefreshing];
//        FMResultSet *rs = [db executeQuery:@"SELECT data FROM event ORDER BY id DESC LIMIT ? OFFSET 0", @(FETCH_EVENT_COUNT)];
//        int i = 0;
//        while ([rs next]) {
//            NSString *data = [rs stringForColumnIndex:0];
//            NSError *error = nil;
//            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:[data dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
//            if (error) {
//                lwError("Json error:%@", [error localizedDescription]);
//                return;
//            }
//            
//            EventInfo *event = [EventInfo eventWithDictionary:dict];
//            [_gameData.eventInfos insertObject:event atIndex:i];
//            [insertIndexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
//            i++;
//        }
//    }
}



- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [_gameData.eventInfos count];
}


// The cell that is returned must be retrieved from a call to -dequeueReusableCellWithReuseIdentifier:forIndexPath:
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    __weak EventCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:CELL_ID forIndexPath:indexPath];
    
    //
    NSInteger idx = indexPath.row;
    if (idx >= [_gameData.eventInfos count]) {
        lwError("Out of range.");
        return cell;
    }
    EventInfo *event = [_gameData.eventInfos objectAtIndex:idx];
    
    cell.imageView.image = _loadingImage;
    [cell.imageView asyncLoadImageWithKey:event.thumb showIndicator:NO completion:nil];
    
    //check finished
    NSDate *now = getServerNow();
    if (event.hasResult) {
        [cell.statusLabel setHidden:YES];
    } else if ([event.beginTime compare:now] == NSOrderedAscending && [now compare:event.endTime] == NSOrderedAscending) {
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

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (_gameData.eventInfos.count == 0) {
        return;
    }
    
    if ((scrollView.contentOffset.y + scrollView.frame.size.height + _footerView.frame.size.height) >= scrollView.contentSize.height) {
        if (_fetching || !_appendable || _reachBottom) {
            return;
        }
        
        _footerView.hidden = NO;
        
        EventInfo *lastEventInfo = _gameData.eventInfos.lastObject;
        NSDictionary *body = @{@"StartId":@(lastEventInfo.id), @"Limit":@(FETCH_EVENT_COUNT)};
        SldHttpSession *session = [SldHttpSession defaultSession];
        _fetching = YES;
        _appendable = NO;
        [session postToApi:@"event/list" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error)
         {
             _fetching = NO;
             if (error) {
                 NSString *errType = getServerErrorType(data);
                 if ([errType compare:@"err_not_found"] == 0) {
                     _reachBottom = YES;
                 } else {
                     alertHTTPError(error, data);
                 }
                 return;
             }
             NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
             if (error) {
                 alert([NSString stringWithFormat:@"Json error, error=%@", [error localizedDescription]], nil);
                 return;
             }
             if (array.count < FETCH_EVENT_COUNT) {
                 _reachBottom = YES;
             }
             
             if (_reachBottom) {
                 [_footerView.spinner stopAnimating];
                 _footerView.spinner.hidden = YES;
                 _footerView.label.text = @"NO MORE DATA";
             }
             
             FMDatabase *db = [SldDb defaultDb].fmdb;
             NSMutableArray *insertIndexPaths = [NSMutableArray arrayWithCapacity:20];
             
             for (int i = 0; i < [array count]; ++i) {
                 NSDictionary *dict = array[i];
                 EventInfo *event = [EventInfo eventWithDictionary:dict];
    
                 [insertIndexPaths addObject:[NSIndexPath indexPathForRow:_gameData.eventInfos.count inSection:0]];
                 [_gameData.eventInfos addObject:event];
                 
                 //save to db
                 NSData *eventData = [NSJSONSerialization dataWithJSONObject:dict options:0 error:&error];
                 if (error) {
                     lwError("Json error, error=%@", [error localizedDescription]);
                     return;
                 }
                 FMResultSet *rs = [db executeQuery:@"SELECT packDownloaded FROM event WHERE id=?", dict[@"Id"]];
                 
                 BOOL packDownloaded = NO;
                 if ([rs next]) {
                     packDownloaded = [rs boolForColumnIndex:0];
                 }
                 
                 BOOL ok = [db executeUpdate:@"REPLACE INTO event (id, data, packDownloaded) VALUES(?, ?, ?)", dict[@"Id"], eventData, @(packDownloaded)];
                 if (!ok) {
                     lwError("Sql error:%@", [db lastErrorMessage]);
                 }
             }
             
             if (insertIndexPaths.count) {
                 [self.collectionView insertItemsAtIndexPaths:insertIndexPaths];
             }
         }];
    }
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    _appendable = YES;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
    if (kind == UICollectionElementKindSectionFooter) {
        _footerView = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"eventListFooter" forIndexPath:indexPath];
        
        return _footerView;
    }
    
    return nil;
}

#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if (segue.identifier && [segue.identifier compare:@"toEventDetail"] == 0) {
        UIButton *button = sender;
        UICollectionViewCell *cell = (UICollectionViewCell*)button.superview.superview;
        NSIndexPath *indexPath = [self.collectionView indexPathForCell:cell];
        if (indexPath.row < [_gameData.eventInfos count]) {
            _gameData.eventInfo = [_gameData.eventInfos objectAtIndex:indexPath.row];
        }
    }
}

@end

























