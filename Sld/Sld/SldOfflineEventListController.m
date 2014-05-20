//
//  SldOfflineEventController.m
//  Sld
//
//  Created by Wei Li on 14-5-18.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldOfflineEventListController.h"
#import "SldDb.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldGameData.h"

static const int FETCH_EVENT_COUNT = 50;

@interface OfflineEventCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@end

@implementation OfflineEventCell

@end


@interface SldOfflineEventListController()
@property (nonatomic) NSMutableArray *eventInfos;
@property (nonatomic) UIImage *loadingImage;
@end



@implementation SldOfflineEventListController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _eventInfos = [NSMutableArray array];
    _loadingImage = [UIImage imageNamed:@"ui/loading.png"];
    
    [self refreshList];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)refreshList {
    FMDatabase *db = [SldDb defaultDb].fmdb;
//    NSMutableArray *insertIndexPaths = [NSMutableArray arrayWithCapacity:20];
    
    FMResultSet *rs = [db executeQuery:@"SELECT data FROM event WHERE packDownloaded = 1 ORDER BY id DESC LIMIT ? OFFSET 0", @(FETCH_EVENT_COUNT)];
//    int i = 0;
    while ([rs next]) {
        NSString *data = [rs stringForColumnIndex:0];
        NSError *error = nil;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:[data dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        EventInfo *event = [EventInfo eventWithDictionary:dict];
        [_eventInfos addObject:event];
//        [_gameData.eventInfos insertObject:event atIndex:i];
//        [insertIndexPaths addObject:[NSIndexPath indexPathForRow:i inSection:0]];
//        i++;
    }
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _eventInfos.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    OfflineEventCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"offlineEventCell" forIndexPath:indexPath];
    
    EventInfo *event = [_eventInfos objectAtIndex:indexPath.row];
    
    cell.imageView.image = _loadingImage;
    [cell.imageView asyncLoadImageWithKey:event.thumb showIndicator:NO completion:nil];
    
    return cell;
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if (segue.identifier && [segue.identifier compare:@"toOfflineEnter"] == 0) {
        SldGameData *gamedata = [SldGameData getInstance];
        UIButton *button = sender;
        UICollectionViewCell *cell = (UICollectionViewCell*)button.superview.superview;
        NSIndexPath *indexPath = [self.collectionView indexPathForCell:cell];
        if (indexPath.row < [_eventInfos count]) {
            gamedata.eventInfo = [_eventInfos objectAtIndex:indexPath.row];
        }
    }
}

@end
