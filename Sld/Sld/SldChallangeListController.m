//
//  SldStarModeListController.m
//  Sld
//
//  Created by 李炜 on 14-7-7.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldChallangeListController.h"
#import "SldGameData.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldUtil.h"
#import "SldHttpSession.h"


@interface SldChallangeCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet SldAsyncImageView *imageView;
@end

@implementation SldChallangeCell

@end

@interface SldChallangeListController ()
@property (nonatomic) UIRefreshControl *refreshControl;
@property (nonatomic) UITextField *titleField;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *goButton;
@property (nonatomic) UIImage *loadingImage;
@property (nonatomic) SldGameData *gd;
@property (nonatomic) NSMutableArray *downloadTasks;
@property (nonatomic) int rowNum;
@end

static int EVENT_NUM_PER_BATCH = 20;
static NSString *STR_GOTO = @"跳转";
static NSString *STR_BOTTOM = @"到底";

@implementation SldChallangeListController

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
    
    _downloadTasks = [NSMutableArray arrayWithCapacity:20];
    
//    //refresh control
//    self.refreshControl = [[UIRefreshControl alloc] init];
//    self.collectionView.alwaysBounceVertical = YES;
//    [self.collectionView addSubview:self.refreshControl];
//    [self.refreshControl addTarget:self action:@selector(refershControlAction) forControlEvents:UIControlEventValueChanged];
    
    self.collectionView.decelerationRate = UIScrollViewDecelerationRateFast;
    
    //title
    _titleField = [[UITextField alloc] initWithFrame:CGRectMake(0, 0, 100, 30)];
    self.navigationItem.titleView = _titleField;
    _titleField.text = @"0";
    _titleField.borderStyle = UITextBorderStyleRoundedRect;
    _titleField.textAlignment = NSTextAlignmentCenter;
    _titleField.backgroundColor = [UIColor clearColor];
    _titleField.keyboardType = UIKeyboardTypeNumberPad;
    
    //tap gesture
    UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singleTapGestureCaptured:)];
    singleTap.cancelsTouchesInView = NO;
    [self.collectionView addGestureRecognizer:singleTap];
    
    //title tap notification
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(onTitleTap:)
                                                 name:UITextFieldTextDidBeginEditingNotification object:nil];
    
    
    _goButton.title = STR_BOTTOM;
    _gd = [SldGameData getInstance];
    _loadingImage = [UIImage imageNamed:@"ui/loading.png"];
    
    //fixme
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"StartId":@0, @"Limit":@1};
    [session postToApi:@"event/list" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        if (array.count != 1) {
            lwError("array.count != 1");
            return;
        }
        
        NSDictionary *dict = [array firstObject];
        
        EventInfo* evt = [EventInfo eventWithDictionary:dict];
        _rowNum = (NSInteger)evt.id;
        
        if (_gd.starModeEventInfos == nil) {
            _gd.starModeEventInfos = [NSMutableArray arrayWithCapacity:_rowNum];
            for (int i = 0; i < _rowNum; i++) {
                EventInfo *evt = [[EventInfo alloc] init];
                [_gd.starModeEventInfos addObject:evt];
            }
        } else if (_gd.starModeEventInfos.count < _rowNum) {
            for (int i = 0; i < _rowNum-_gd.starModeEventInfos.count; i++) {
                EventInfo *evt = [[EventInfo alloc] init];
                [_gd.starModeEventInfos addObject:evt];
            }
        } else if (_gd.starModeEventInfos.count > _rowNum) {
            for (int i = 0; i < _gd.starModeEventInfos.count-_rowNum; i++) {
                [_gd.starModeEventInfos removeLastObject];
            }
        }
        [self.collectionView reloadData];
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
//    [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:10 inSection:0] atScrollPosition:UICollectionViewScrollPositionTop animated:NO];
}

- (void)onTitleTap:(NSNotification*)aNotification {
    [_titleField setSelectedTextRange:[_titleField textRangeFromPosition:_titleField.beginningOfDocument toPosition:_titleField.endOfDocument]];
    
    _goButton.title = STR_GOTO;
}

- (IBAction)gotoBottom:(id)sender {
    NSInteger num = [self collectionView:self.collectionView numberOfItemsInSection:0];
    
    if ([_goButton.title compare:STR_GOTO] == 0) {
        NSInteger row = [_titleField.text integerValue];
        if (row >= num) {
            row = num - 1;
        }
        [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:row inSection:0] atScrollPosition:UICollectionViewScrollPositionTop animated:NO];
        [self.navigationItem.titleView resignFirstResponder];
        _goButton.title = STR_BOTTOM;
    } else {
        [self.collectionView scrollToItemAtIndexPath:[NSIndexPath indexPathForRow:num-1 inSection:0] atScrollPosition:UICollectionViewScrollPositionBottom animated:NO];
    }
}

- (void)singleTapGestureCaptured:(UITapGestureRecognizer *)gesture {
    [self.navigationItem.titleView resignFirstResponder];
    
    _goButton.title = STR_BOTTOM;
}

- (void)refershControlAction {
    
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:CGPointMake(0, scrollView.contentOffset.y+scrollView.contentInset.top)];
    _titleField.text = [NSString stringWithFormat:@"%d", indexPath.row];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _rowNum;
}

// The cell that is returned must be retrieved from a call to -dequeueReusableCellWithReuseIdentifier:forIndexPath:
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    SldChallangeCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"challangeCell" forIndexPath:indexPath];
    cell.imageView.image = _loadingImage;
    
    if (indexPath.row < _gd.starModeEventInfos.count) {
        EventInfo *evt = [_gd.starModeEventInfos objectAtIndex:indexPath.row];
        if (evt.thumb) {
            [cell.imageView asyncLoadImageWithKey:evt.thumb showIndicator:NO completion:nil];
            if (cell.imageView.task) {
                [_downloadTasks addObject:cell.imageView.task];
                if (_downloadTasks.count > 24) {
                    NSURLSessionDownloadTask *task = [_downloadTasks firstObject];
                    [task cancel];
                    [_downloadTasks removeObjectAtIndex:0];
                }
            }
        } else if (evt.isLoading == NO){
            int batchIdx = indexPath.row / EVENT_NUM_PER_BATCH;
            int startId = batchIdx * EVENT_NUM_PER_BATCH;
            
            SldHttpSession *session = [SldHttpSession defaultSession];
            NSDictionary *body = @{@"StartId":@(startId), @"Limit":@(EVENT_NUM_PER_BATCH)};
            for (int i = startId; i < startId + EVENT_NUM_PER_BATCH; i++) {
                if (i >= _gd.starModeEventInfos.count) {
                    break;
                }
                EventInfo *evt = [_gd.starModeEventInfos objectAtIndex:i];
                evt.isLoading = YES;
            }
            [session postToApi:@"event/revList" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if (error) {
                    alertHTTPError(error, data);
                    return;
                }
                
                NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                if (error) {
                    lwError("Json error:%@", [error localizedDescription]);
                    return;
                }
                
                NSMutableArray *reloads = [NSMutableArray array];
                for (NSDictionary *dict in array) {
                    EventInfo *evt = [EventInfo eventWithDictionary:dict];
                    int row = (int)evt.id - 1;
                    if (row >= _gd.starModeEventInfos.count) {
                        continue;
                    }
                    [_gd.starModeEventInfos replaceObjectAtIndex:row withObject:evt];
                    [reloads addObject:[NSIndexPath indexPathForRow:row inSection:0]];
                }
                
                [self.collectionView reloadItemsAtIndexPaths:reloads];
            }];
        }
        
//        //fixme
//        NSString *gravatarKey = [NSString stringWithFormat:@"%d", indexPath.row];
//        NSString *url = [SldUtil makeGravatarUrlWithKey:gravatarKey width:48];
//        [cell.imageView asyncLoadImageWithUrl:url showIndicator:NO completion:^{
//            if (cell.imageView.task) {
//                [_downloadTasks removeObject:cell.imageView.task];
//            }
//        }];
//        if (cell.imageView.task) {
//            [_downloadTasks addObject:cell.imageView.task];
//            if (_downloadTasks.count > 24) {
//                NSURLSessionDownloadTask *task = [_downloadTasks firstObject];
//                [task cancel];
//                [_downloadTasks removeObjectAtIndex:0];
//                lwInfo("%d", _downloadTasks.count);
//            }
//        }
    }
    
    return cell;
}


#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if (segue.identifier && [segue.identifier compare:@"toChallangeSeg"] == 0) {
        UIButton *button = sender;
        UICollectionViewCell *cell = (UICollectionViewCell*)button.superview.superview;
        NSIndexPath *indexPath = [self.collectionView indexPathForCell:cell];
        if (indexPath.row < [_gd.starModeEventInfos count]) {
            _gd.eventInfo = [_gd.starModeEventInfos objectAtIndex:indexPath.row];
        }
    }
}

@end
