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
#import "util.h"
#import "config.h"

NSString *CELL_ID = @"cellID";

@implementation Cell

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


@implementation Event
@end

@interface SldEventListViewController ()
@property (nonatomic) UIRefreshControl *refreshControl;
@property (nonatomic) NSMutableArray *events;
@end

@implementation SldEventListViewController

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [self.events count];
}


// The cell that is returned must be retrieved from a call to -dequeueReusableCellWithReuseIdentifier:forIndexPath:
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    Cell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:CELL_ID forIndexPath:indexPath];
    
    //
    int idx = indexPath.row;
    if (idx >= [self.events count]) {
        lwError("Out of range.");
        return cell;
    }
    Event *event = [self.events objectAtIndex:idx];
    
    //
    Config *conf = [Config sharedConf];
    NSString *thumbPath = makeDocPath([NSString stringWithFormat:@"%@/%@", conf.IMG_CACHE_DIR, event.thumb]);
    if ([[NSFileManager defaultManager] fileExistsAtPath:thumbPath]) { //local
        UIImage *image = [UIImage imageWithContentsOfFile:thumbPath];
        cell.image.image = image;
    } else { //server
        UIImage *image = [UIImage imageNamed:@"img/loading.png"];
        cell.image.image = image;
        
        //download
        SldHttpSession *session = [SldHttpSession defaultSession];
        [session downloadFromUrl:[NSString stringWithFormat:@"%@/%@", conf.DATA_HOST, event.thumb]
                          toPath:thumbPath
                        withData:nil completionHandler:^(NSURL *location, NSError *error, id data)
        {
            [self.collectionView reloadItemsAtIndexPaths:[NSArray arrayWithObjects:indexPath, nil]];
        }];
    }
    
    return cell;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    //creat image cache dir
    NSString *imgCacheDir = makeDocPath(@"imgCache");
    [[NSFileManager defaultManager] createDirectoryAtPath:imgCacheDir withIntermediateDirectories:YES attributes:nil error:nil];
    
    //
    self.events = [NSMutableArray arrayWithCapacity:20];
    
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
        Event *firstEvent = nil;
        if ([self.events count]) {
            firstEvent = self.events[0];
        }
        for (int i = 0; i < [array count]; ++i) {
            Event *event = [[Event alloc] init];
            NSDictionary *dict = array[i];
            event.id = [(NSNumber*)dict[@"Id"] unsignedLongLongValue];
            event.thumb = dict[@"Thumb"];
            event.packId = [(NSNumber*)dict[@"PackId"] unsignedLongLongValue];
            event.beginTime = [NSDate dateWithTimeIntervalSince1970:[(NSNumber*)dict[@"BeginTime"] longLongValue]];
            event.endTime = [NSDate dateWithTimeIntervalSince1970:[(NSNumber*)dict[@"EndTime"] longLongValue]];
            
            //lwInfo("%@", event.endTime);
            NSDateComponents *components = [[NSCalendar currentCalendar] components:NSCalendarUnitDay | NSCalendarUnitMonth | NSCalendarUnitYear | NSCalendarUnitHour | NSCalendarUnitMinute | NSCalendarUnitSecond fromDate:event.endTime];

            lwInfo("%@", components);
            
            if (firstEvent && firstEvent.id == event.id) {
                break;
            }
            
            [self.events insertObject:event atIndex:i];
            [insertIndexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0] ];
        }
        [self.collectionView insertItemsAtIndexPaths:insertIndexPaths];
        
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    
    if ([self.events count] == 0) {
        [self refreshList];
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
    NSIndexPath *selectedIndexPath = [[self.collectionView indexPathsForSelectedItems] objectAtIndex:0];
    int row = selectedIndexPath.row;
    if (row < [self.events count]) {
        Event *event = self.events[row];
        SldEventDetailViewController *detailController = [segue destinationViewController];
        detailController.event = event;
    }
}


@end
