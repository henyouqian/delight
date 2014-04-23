//
//  SldEventListViewController.m
//  Sld
//
//  Created by Wei Li on 14-4-18.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldEventListViewController.h"
#import "SldHttpSession.h"
#import "util.h"

NSString *CELL_ID = @"cellID";
NSString *DATA_HOST = @"http://sliderpack.qiniudn.com";

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

@interface Event : NSObject
@property (nonatomic) UInt64 id;
@property (nonatomic) NSString *thumb;
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

- (NSString*)makeImgCachePath:(NSString*)filename {
    return makeDocPath([NSString stringWithFormat:@"imgCache/%@", filename]);
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
    
    //local
    NSString *thumbPath = [self makeImgCachePath:event.thumb];
    if ([[NSFileManager defaultManager] fileExistsAtPath:thumbPath]) {
        UIImage *image = [UIImage imageWithContentsOfFile:thumbPath];
        cell.image.image = image;
    } else { //fetch from server
        UIImage *image = [UIImage imageNamed:@"img/loading.png"];
        cell.image.image = image;
        
        //download
        SldHttpSession *session = [SldHttpSession defaultSession];
        [session downloadFromUrl:[NSString stringWithFormat:@"%@/%@", DATA_HOST, event.thumb]
                          toPath:thumbPath
                        withData:[NSNumber numberWithInt:idx] completionHandler:^(NSURL *location, NSError *error, id data)
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
    [self.navigationController pushViewController:controller animated:NO];
    //[self presentViewController:controller animated:YES completion:^(void) {}];
}

- (void)refreshList {
    NSDictionary *body = @{@"StartId":@0, @"Limit":@50};
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"event/list" body:body completionHandler:^(id data, NSURLResponse *response, NSError *error) {
        //NSLog(@"data:%@\nerror:%@\n", data, error);
        //alert(@"Info", [NSString stringWithFormat:@"%@", data]);
        if (!error) {
            NSArray *resp = data;
            NSMutableArray *insertIndexPaths = [NSMutableArray arrayWithCapacity:20];
            Event *firstEvent = nil;
            if ([self.events count]) {
                firstEvent = self.events[0];
            }
            for (int i = 0; i < [resp count]; ++i) {
                Event *event = [[Event alloc] init];
                NSDictionary *dict = resp[i];
                event.id = (UInt64)dict[@"Id"];
                event.thumb = dict[@"Thumb"];
                
                if (firstEvent && firstEvent.id == event.id) {
                    break;
                }
        
                [self.events insertObject:event atIndex:i];
                [insertIndexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0] ];
            }
            [self.collectionView insertItemsAtIndexPaths:insertIndexPaths];
            
        } else {
            alert(@"Error", [NSString stringWithFormat:@"%@", error]);
        }
        [self.refreshControl endRefreshing];
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
    
}
 
- (IBAction)onGameExit:(UIStoryboardSegue *)segue {

}


@end
