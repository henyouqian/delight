//
//  SldUserPackLatestController.m
//  pin
//
//  Created by 李炜 on 14-8-16.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldUserPackLatestController.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldUtil.h"
#import "SldGameData.h"
#import "SldHttpSession.h"
#import "UIImage+ImageEffects.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldMyUserPackMenuController.h"
#import "SldMyUserPackController.h"

static const int USER_PACK_LIST_LIMIT = 30;

//=============================
@interface SldUserPackLatestCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet SldAsyncImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *rewardNumLabel;
@property (nonatomic) UserPack* userPack;
@end

@implementation SldUserPackLatestCell

@end

//=============================
@interface SldUserPackLatestFooter : UICollectionReusableView
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spin;
@end

@implementation SldUserPackLatestFooter

@end

//=============================
@interface SldUserPackLatestController()

@property (nonatomic) NSMutableArray *userPacks;
@property (nonatomic) BOOL reachEnd;
@property (nonatomic) BOOL scrollUnderBottom;
@property (nonatomic) SldUserPackLatestFooter* footer;

@end

@implementation SldUserPackLatestController

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
        [session postToApi:@"userPack/listLatest" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
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
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:_userPacks.count-1 inSection:0];
                [insertIndexPathes addObject:indexPath];
            }
            [self.collectionView insertItemsAtIndexPaths:insertIndexPathes];
        }];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.tabBarController.navigationItem.rightBarButtonItem = nil;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _userPacks.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    SldUserPackLatestCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"userPackLatestCell" forIndexPath:indexPath];
    UserPack *userPack = [_userPacks objectAtIndex:indexPath.row];
    [cell.imageView asyncLoadUploadImageWithKey:userPack.thumb showIndicator:NO completion:nil];
//    cell.rewardNumLabel.text = [NSString stringWithFormat:@"%d", userPack.playTimes];
    cell.userPack = userPack;
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    if (kind == UICollectionElementKindSectionFooter) {
        _footer = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"userPackLatestFooter" forIndexPath:indexPath];
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

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    SldUserPackLatestCell *cell = sender;
    SldGameData *gd = [SldGameData getInstance];
    gd.userPack = cell.userPack;
}

@end
