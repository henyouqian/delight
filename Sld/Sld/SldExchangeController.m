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

//===============================
@interface SldEcardType : NSObject
@property (nonatomic) NSString *key;
@property (nonatomic) NSString *name;
@property (nonatomic) NSString *provider;
@property (nonatomic) NSString *thumb;
@property (nonatomic) int couponPrice;
@end

@implementation SldEcardType

- (instancetype)initWithDict:(NSDictionary*)dict {
    if (self = [super init]) {
        _key = dict[@"Key"];
        _name = dict[@"Name"];
        _provider = dict[@"Provider"];
        _thumb = dict[@"Thumb"];
        _couponPrice = [(NSNumber*)dict[@"CouponPrice"] intValue];
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
@interface SldExchangeController ()
@property (nonatomic) UIRefreshControl *refreshControl;
@property (nonatomic) NSMutableArray *ecardTypes;
@end

@implementation SldExchangeController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
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
        [cell.buyButton setTitle:[NSString stringWithFormat:@"使用%d奖金兑换", cardType.couponPrice] forState:UIControlStateNormal];
        
        [cell.imgView asyncLoadUploadedImageWithKey:cardType.thumb showIndicator:NO completion:nil];
    }
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    if (kind == UICollectionElementKindSectionHeader) {
        UICollectionReusableView *header = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"exchangeHeader" forIndexPath:indexPath];
        return header;
    }
    return nil;
}


@end
