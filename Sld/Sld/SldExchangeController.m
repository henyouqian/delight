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
#import "SldTradeController.h"
#import "SldECardController.h"

//===============================
@interface SldEcardType : NSObject
@property (nonatomic) NSString *key;
@property (nonatomic) NSString *name;
@property (nonatomic) NSString *provider;
@property (nonatomic) NSString *thumb;
@property (nonatomic) int needPrize;
@property (nonatomic) int num;
@end

@implementation SldEcardType

- (instancetype)initWithDict:(NSDictionary*)dict {
    if (self = [super init]) {
        _key = dict[@"Key"];
        _name = dict[@"Name"];
        _provider = dict[@"Provider"];
        _thumb = dict[@"Thumb"];
        _needPrize = [(NSNumber*)dict[@"NeedPrize"] intValue];
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
- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    return layoutAttributes;
}
@end

//===============================
@interface SldExchangeHeader : UICollectionReusableView
@property (weak, nonatomic) IBOutlet UIButton *getPrizeButton;
@property (weak, nonatomic) IBOutlet UILabel *prizeLabel;
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
    
    //login notification
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onLogin) name:@"login" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(refreshPrizeUI) name:@"prizeCacheChange" object:nil];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)onLogin {
    [self refresh];
}

- (void)refreshPrizeUI {
    [self.collectionView reloadData];
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
            [cell.buyButton setTitle:[NSString stringWithFormat:@"使用%d奖金兑换(兑完补货中)", cardType.needPrize] forState:UIControlStateNormal];
            cell.buyButton.enabled = NO;
            cell.buyButton.backgroundColor = [UIColor grayColor];
        } else {
            [cell.buyButton setTitle:[NSString stringWithFormat:@"使用%d奖金兑换", cardType.needPrize] forState:UIControlStateNormal];
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
        header.prizeLabel.text = [NSString stringWithFormat:@"现有奖金：%d", _gd.playerInfo.prize];
        NSString *title = [NSString stringWithFormat:@"可领取奖金：%d", _gd.playerInfo.prizeCache];
        [header.getPrizeButton setTitle:title forState:UIControlStateNormal];
        [header.getPrizeButton setTitle:title forState:UIControlStateDisabled];
        if (_gd.playerInfo.prizeCache == 0) {
            header.getPrizeButton.enabled = NO;
            header.getPrizeButton.backgroundColor = [UIColor grayColor];
        } else {
            header.getPrizeButton.enabled = YES;
            header.getPrizeButton.backgroundColor = [SldUtil getPinkColor];
        }
        return header;
    }
    return nil;
}

- (IBAction)onGetPrizeButton:(id)sender {
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"player/addPrizeFromCache" body:nil completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        _gd.playerInfo.prize = [(NSNumber*)dict[@"Prize"] floatValue];
        _gd.playerInfo.totalPrize = [(NSNumber*)dict[@"TotalPrize"] floatValue];
        _gd.playerInfo.prizeCache = 0;
        
        [SldTradeController getInstance].tabBarItem.badgeValue = nil;
        
        [[NSNotificationCenter defaultCenter] postNotificationName:@"prizeCacheChange" object:nil];
    }];
}

- (IBAction)onExchangeButton:(id)sender {
    UIButton *btn = sender;
    NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:[self.collectionView convertPoint:btn.center fromView:btn.superview]];
    
    
    SldEcardType *cardType = _ecardTypes[indexPath.row];
    if (_gd.playerInfo.prize < cardType.needPrize) {
        alert(@"奖金不足。", nil);
        return;
    }
    
    NSString *str = [NSString stringWithFormat:@"确定兑换“%@”?", cardType.name];
    [[[UIAlertView alloc] initWithTitle:str
	                            message:nil
		               cancelButtonItem:[RIButtonItem itemWithLabel:@"取消" action:^{
        
    }]
				       otherButtonItems:[RIButtonItem itemWithLabel:@"兑换" action:^{
        SldHttpSession *session = [SldHttpSession defaultSession];
        NSDictionary *body = @{@"TypeKey":cardType.key};
        [session postToApi:@"store/buyEcard" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                NSString *error = dict[@"Error"];
                if ([error compare:@"err_zero"] == 0) {
                    alert(@"已经没有了，正在补货中，请稍后再来🙇", nil);
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
            [[SldECardController getInstance] addEcard:ecard];
            alert(@"兑换成功，请至“已兑”界面查看。", nil);
            
            _gd.playerInfo.prize = [(NSNumber*)dict[@"PlayerPrize"] floatValue];
            [[NSNotificationCenter defaultCenter] postNotificationName:@"prizeCacheChange" object:nil];
        }];
    }], nil] show];
}

@end
