//
//  SldMyUserPackController.m
//  pin
//
//  Created by 李炜 on 14-8-16.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldMyUserPackController.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldUtil.h"
#import "SldHttpSession.h"

static const int USER_PACK_LIST_LIMIT = 30;

//=============================
@interface SldMyUserPackCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet SldAsyncImageView *imageView;
@end

@implementation SldMyUserPackCell

@end

//=============================
@interface SldMyUserPackFooter : UICollectionReusableView
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spin;
@end

@implementation SldMyUserPackFooter

@end

//=============================
@interface UserPack : NSObject
@property (nonatomic) SInt64 id;

- (instancetype)initWithDict:(NSDictionary*)dict;

@end

@implementation UserPack

- (instancetype)initWithDict:(NSDictionary*)dict {
    if (self = [super init]) {
        
        return self;
    }
    return nil;
}

@end

//=============================
@interface SldMyUserPackEditCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@end

@implementation SldMyUserPackEditCell

@end

//=============================
@interface SldMyUserPackEditController : UICollectionViewController
- (void)setAssets:(NSArray *)assets;

@property (nonatomic) NSArray* assets;
@end

@implementation SldMyUserPackEditController
- (void)setAssets :(NSArray *)assets{
    _assets = assets;
    [self.collectionView reloadData];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _assets.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    SldMyUserPackEditCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"myUserPackEditCell" forIndexPath:indexPath];
    
    ALAsset *asset = [_assets objectAtIndex:indexPath.row];
//    NSString *path = asset.defaultRepresentation.url.absoluteString;
    
    cell.imageView.image = [UIImage imageWithCGImage:asset.thumbnail];
    
    return cell;
}

@end

//=============================
@interface SldMyUserPackController()

@property (nonatomic) NSMutableArray *userPacks;
@property (nonatomic) BOOL reachEnd;
@property (nonatomic) BOOL scrollUnderBottom;
@property (nonatomic) SldMyUserPackFooter* footer;
@property (nonatomic) QBImagePickerController *imagePickerController;

@end

@implementation SldMyUserPackController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _userPacks = [NSMutableArray array];
    
    UIEdgeInsets insets = self.collectionView.contentInset;
    insets.top = 64;
    insets.bottom = 50;
    
    self.collectionView.contentInset = insets;
    self.collectionView.scrollIndicatorInsets = insets;
    self.tabBarController.automaticallyAdjustsScrollViewInsets = NO;
    
    //
    if (_userPacks.count == 0) {
        NSDictionary *body = @{@"StartId": @(0), @"Limit": @(USER_PACK_LIST_LIMIT)};
        SldHttpSession *session = [SldHttpSession defaultSession];
        [session postToApi:@"userPack/list" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                alertHTTPError(error, data);
                return;
            }
            NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error) {
                lwError("Json error:%@", [error localizedDescription]);
                return;
            }
            
            if (array.count < USER_PACK_LIST_LIMIT) {
                _reachEnd = YES;
            }
            
            NSMutableArray *insertIndexPathes = [NSMutableArray array];
            for (NSDictionary *dict in array) {
                UserPack *userPack = [[UserPack alloc] initWithDict:dict];
                [_userPacks addObject:userPack];
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:_userPacks.count-1 inSection:1];
                [insertIndexPathes addObject:indexPath];
            }
            [self.collectionView insertItemsAtIndexPaths:insertIndexPathes];
        }];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
//    self.tabBarController.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addPack)];
    self.tabBarController.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"发布" style:UIBarButtonItemStylePlain target:self action:@selector(addPack)];
}

- (void)addPack {
    _imagePickerController = [[QBImagePickerController alloc] init];
    _imagePickerController.delegate = self;
    _imagePickerController.filterType = QBImagePickerControllerFilterTypePhotos;
    _imagePickerController.allowsMultipleSelection = YES;
    _imagePickerController.minimumNumberOfSelection = 4;
    _imagePickerController.maximumNumberOfSelection = 12;
    _imagePickerController.title = @"选择4-12张图片";
    
    [self.navigationController pushViewController:_imagePickerController animated:YES];
}

- (void)qb_imagePickerController:(QBImagePickerController *)imagePickerController didSelectAssets:(NSArray *)assets {
    [self.navigationController popToViewController:self.tabBarController animated:NO];
    
    SldMyUserPackEditController* vc = (SldMyUserPackEditController*)[getStoryboard() instantiateViewControllerWithIdentifier:@"myUserPackEditVC"];
    
    [self.navigationController pushViewController:vc animated:YES];
    
    [vc setAssets:assets];
}

- (void)qb_imagePickerControllerDidCancel:(QBImagePickerController *)imagePickerController {
    [self.navigationController popToViewController:self.tabBarController animated:YES];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return 30;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    SldMyUserPackCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"myUserPackCell" forIndexPath:indexPath];
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    if (kind == UICollectionElementKindSectionFooter) {
        lwInfo("%d/%d", indexPath.section, indexPath.row);
        _footer = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"myUserPackFooter" forIndexPath:indexPath];
        return _footer;
    }
    return nil;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (_userPacks.count == 0 || _reachEnd) {
        return;
    }
    
    if (scrollView.contentSize.height > scrollView.frame.size.height
        &&(scrollView.contentOffset.y + scrollView.frame.size.height) > scrollView.contentSize.height) {
        if (!_scrollUnderBottom) {
            _scrollUnderBottom = YES;
            if (![_footer.spin isAnimating]) {
                [_footer.spin startAnimating];
                
                SInt64 startId = 0;
                if (_userPacks.count > 0) {
                    UserPack *userPack = [_userPacks lastObject];
                    startId = userPack.id;
                }
//
//                NSDictionary *body = @{@"StartId": @(startId), @"Limit": @(ADVICE_LIMIT)};
//                SldHttpSession *session = [SldHttpSession defaultSession];
//                [session postToApi:@"etc/listAdvice" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
//                    [_bottomRefresh endRefreshing];
//                    if (error) {
//                        alertHTTPError(error, data);
//                        return;
//                    }
//                    NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
//                    if (error) {
//                        lwError("Json error:%@", [error localizedDescription]);
//                        return;
//                    }
//                    
//                    if (array.count < ADVICE_LIMIT) {
//                        _reachEnd = YES;
//                    }
//                    
//                    NSMutableArray *insertIndexPathes = [NSMutableArray array];
//                    for (NSDictionary *dict in array) {
//                        AdviceData *adviceData = [AdviceData adviceDataWithDictionary:dict];
//                        [_adviceDatas addObject:adviceData];
//                        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:_adviceDatas.count-1 inSection:1];
//                        [insertIndexPathes addObject:indexPath];
//                    }
//                    [self.tableView insertRowsAtIndexPaths:insertIndexPathes withRowAnimation:UITableViewRowAnimationAutomatic];
//                }];
            }
        }
        
    } else {
        _scrollUnderBottom = NO;
    }
}

@end
