//
//  SldExchangeController.m
//  pin
//
//  Created by 李炜 on 14-9-27.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldExchangeController.h"
#import "SldHttpSession.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldGameData.h"
#import "SldHttpSession.h"
#import "SldUtil.h"
#import "SldCouponCardController.h"

//===============================
@interface SldEcardType : NSObject
@property (nonatomic) NSString *key;
@property (nonatomic) NSString *name;
@property (nonatomic) NSString *provider;
@property (nonatomic) NSString *thumb;
@property (nonatomic) int couponPrice;
@property (nonatomic) int num;
@end

@implementation SldEcardType

- (instancetype)initWithDict:(NSDictionary*)dict {
    if (self = [super init]) {
        _key = dict[@"Key"];
        _name = dict[@"Name"];
        _provider = dict[@"Provider"];
        _thumb = dict[@"Thumb"];
        _couponPrice = [(NSNumber*)dict[@"CouponPrice"] intValue];
        _num = [(NSNumber*)dict[@"Num"] intValue];
    }
    
    return self;
}

@end

//===============================
@interface SldExchangeCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet UIImageView *imgView;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UIButton *buyButton;
@end

@implementation SldExchangeCell

@end

//===============================
@interface SldExchangeHeader : UICollectionReusableView
@property (weak, nonatomic) IBOutlet UIButton *getRewardButton;
@property (weak, nonatomic) IBOutlet UILabel *couponLabel;
@end

@implementation SldExchangeHeader

@end

//===============================
@interface SldExchangeController ()

@property (nonatomic) UIRefreshControl *refreshControl;
@property (nonatomic) NSMutableArray *ecardTypes;
@property (nonatomic) SldGameData *gd;
@end

@implementation SldExchangeController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _gd = [SldGameData getInstance];
    
    //
    _ecardTypes = [NSMutableArray array];
    
    //refresh control
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.collectionView.alwaysBounceVertical = YES;
    [self.collectionView addSubview:self.refreshControl];
    [self.refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    
    [self refresh];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.refreshControl endRefreshing];
}

- (void)refresh {
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"store/listEcardType" body:nil completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        
        [self.refreshControl endRefreshing];
        
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        [_ecardTypes removeAllObjects];
        for (NSDictionary *dict in array) {
            SldEcardType *cardType = [[SldEcardType alloc] initWithDict:dict];
            [_ecardTypes addObject:cardType];
        }
        [self.collectionView reloadData];
    }];

}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _ecardTypes.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    SldExchangeCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"exchangeCell" forIndexPath:indexPath];
    
    SldEcardType *cardType = _ecardTypes[indexPath.row];
    if (cardType) {
        cell.titleLabel.text = cardType.name;
        if (cardType.num == 0) {
            [cell.buyButton setTitle:[NSString stringWithFormat:@"使用%d奖金兑换(兑完补货中)", cardType.couponPrice] forState:UIControlStateNormal];
            cell.buyButton.enabled = NO;
            cell.buyButton.backgroundColor = [UIColor grayColor];
        } else {
            [cell.buyButton setTitle:[NSString stringWithFormat:@"使用%d奖金兑换", cardType.couponPrice] forState:UIControlStateNormal];
            cell.buyButton.enabled = YES;
            cell.buyButton.backgroundColor = [SldUtil getPinkColor];
        }
        
        [cell.imgView asyncLoadUploadedImageWithKey:cardType.thumb showIndicator:NO completion:nil];
    }
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    if (kind == UICollectionElementKindSectionHeader) {
        SldExchangeHeader *header = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"exchangeHeader" forIndexPath:indexPath];
        header.couponLabel.text = [NSString stringWithFormat:@"现有奖金：%.2f", _gd.playerInfo.coupon];
        NSString *title = [NSString stringWithFormat:@"可领取奖金：%.2f", _gd.playerInfo.couponCache];
        [header.getRewardButton setTitle:title forState:UIControlStateNormal];
        [header.getRewardButton setTitle:title forState:UIControlStateDisabled];
        if (_gd.playerInfo.couponCache < 0.01) {
            header.getRewardButton.enabled = NO;
            header.getRewardButton.backgroundColor = [UIColor grayColor];
        } else {
            header.getRewardButton.enabled = YES;
            header.getRewardButton.backgroundColor = [SldUtil getPinkColor];
        }
        return header;
    }
    return nil;
}

- (IBAction)onGetRewardButton:(id)sender {
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"player/addCouponFromCache" body:nil completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        _gd.playerInfo.coupon = [(NSNumber*)dict[@"Coupon"] floatValue];
        _gd.playerInfo.totalCoupon = [(NSNumber*)dict[@"TotalCoupon"] floatValue];
        _gd.playerInfo.couponCache = 0;
        
        [self.collectionView reloadData];
    }];
}

- (IBAction)onExchangeButton:(id)sender {
    UIButton *btn = sender;
    NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:[self.collectionView convertPoint:btn.center fromView:btn.superview]];
    
    
    SldEcardType *cardType = _ecardTypes[indexPath.row];
    if (_gd.playerInfo.coupon < (float)cardType.couponPrice) {
        alert(@"奖金不足。", nil);
        return;
    }
    
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"TypeKey":cardType.key};
    [session postToApi:@"store/buyEcard" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            NSString *error = dict[@"Error"];
            if ([error compare:@"err_zero"] == 0) {
                alert(@"兑完补货中，请稍后再来🙇", nil);
            }
            cardType.num = 0;
            [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        NSDictionary *ecardDict = dict[@"Ecard"];
        SldEcard *ecard = [[SldEcard alloc] initWithDict:ecardDict];
        [[SldCouponCardController getInstance] addEcard:ecard];
        alert(@"兑换成功，请至“已兑”界面查看。", nil);
    }];

}

@end
