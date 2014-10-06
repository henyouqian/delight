//
//  SldIapController.m
//  Sld
//
//  Created by 李炜 on 14-6-18.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldIapController.h"
#import "SldHttpSession.h"
#import "SldGameData.h"
#import "SldUtil.h"
#import "SldHttpSession.h"
#import "SldUserController.h"

//=======================
static SldIapManager *_sldIapManager = nil;
static UIView *_hudView = nil;

@interface SldIapManager()
@property (nonatomic) SldGameData *gd;
@property (nonatomic) NSArray *productIds;
@end

@implementation SldIapManager
+ (instancetype)getInstance {
    if (_sldIapManager == nil) {
        _sldIapManager = [[SldIapManager alloc]init];
    }
    return _sldIapManager;
}

- (instancetype)init {
    if (self = [super init]) {
        _gd = [SldGameData getInstance];
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    }
    return self;
}

- (void)dealloc {
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
//    if (_alt) {
//        [_alt dismissWithClickedButtonIndex:0 animated:YES];
//        _alt = nil;
//    }
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchasing:
                lwInfo("SKPaymentTransactionStatePurchasing");
                break;
            case SKPaymentTransactionStatePurchased:
                lwInfo("SKPaymentTransactionStatePurchased");
                [self purchase:transaction];
                [MBProgressHUD hideHUDForView:_hudView animated:YES];
                break;
            case SKPaymentTransactionStateFailed:
                lwInfo("SKPaymentTransactionStateFailed");
                lwError("%@", [transaction.error localizedDescription]);
//                alert([transaction.error localizedDescription], nil);
                [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
                [MBProgressHUD hideHUDForView:_hudView animated:YES];
                break;
            case SKPaymentTransactionStateRestored:
                lwInfo("SKPaymentTransactionStateRestored");
                [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
                [MBProgressHUD hideHUDForView:_hudView animated:YES];
            default:
                lwInfo("default");
                //lwError("%@", [transaction.error localizedDescription]);
                break;
        }
    }
}

- (void)purchase:(SKPaymentTransaction*)transaction {
    if (_gd.userId == 0) {
        return;
    }
    
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"store/getIapSecret" body:nil completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        NSString *secret = [dict objectForKey:@"Secret"];
        if (!secret) {
            alert(@"服务器错误，请稍后重试", nil);
            return;
        }
        
        //checksum
        SldGameData *gd = [SldGameData getInstance];
        
        NSString *checksum = [NSString stringWithFormat:@"%@%lld%@,", secret, gd.userId, gd.userName];
        checksum = [SldUtil sha1WithString:checksum];
        
        NSDictionary *body = @{@"ProductId": transaction.payment.productIdentifier, @"Checksum":checksum};
        
        //buy
        [session postToApi:@"store/buyIap" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                alertHTTPError(error, data);
                return;
            }
            
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error) {
                lwError("Json error:%@", [error localizedDescription]);
                return;
            }
            int addGoldCoin = [(NSNumber*)[dict objectForKey:@"AddGoldCoin"] intValue];
            int goldCoin = [(NSNumber*)[dict objectForKey:@"GoldCoin"] intValue];
            gd.playerInfo.goldCoin = goldCoin;
            alert([NSString stringWithFormat:@"获得%d个金币，现有%d个金币", addGoldCoin, goldCoin], nil);
            [[SldUserController getInstance] updateMoney];
            
            [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
        }];
    }];
}

@end

//=======================
@interface SldIapCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *priceLabel;

@end

@implementation SldIapCell
@end


//=======================
@interface SldIapController ()
@property (nonatomic) UIAlertView *alt;
@property (nonatomic) UIAlertView *altBuy;
@property (nonatomic) NSString *secret;
@property (nonatomic) SldGameData *gd;
@property (nonatomic) NSArray *productIds;
@property (nonatomic) BOOL initialized;
@end

@implementation SldIapController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _gd = [SldGameData getInstance];
    _gd.iapProducts = [NSArray array];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (!_initialized) {
        _initialized = YES;
        
        //UIAlertView *alt = alertNoButton(@"获取商品信息...");
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.dimBackground = YES;
        
        SldHttpSession *session = [SldHttpSession defaultSession];
        [session postToApi:@"store/listIapProductId" body:nil completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            //[alt dismissWithClickedButtonIndex:0 animated:YES];
            [MBProgressHUD hideHUDForView:self.view animated:YES];
            if (error) {
                alertHTTPError(error, data);
                return;
            }
            
            _productIds = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error) {
                lwError("Json error:%@", [error localizedDescription]);
                return;
            }
            
            [self validateProductIdentifiers];
        }];
    }
}

- (void)validateProductIdentifiers
{
//    _alt = alertWithButton(@"验证商品信息...", nil, @"关闭");
    SKProductsRequest *productsRequest = [[SKProductsRequest alloc]
                                          initWithProductIdentifiers:[NSSet setWithArray:_productIds]];
    productsRequest.delegate = self;
    [productsRequest start];
}

// SKProductsRequestDelegate protocol method
- (void)productsRequest:(SKProductsRequest *)request
     didReceiveResponse:(SKProductsResponse *)response
{
//    [_alt dismissWithClickedButtonIndex:0 animated:YES];
//    _alt = nil;
    _gd.iapProducts = [response.products sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        int price1 = [((SKProduct*)obj1).price intValue];
        int price2 = [((SKProduct*)obj2).price intValue];
        if (price1 < price2) {
//            return NSOrderedDescending;
            return NSOrderedAscending;
        } else if (price1 > price2) {
//            return NSOrderedAscending;
            return NSOrderedDescending;
        }
        return NSOrderedSame;
    }];
    
    [self.collectionView reloadData];
}


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _gd.iapProducts.count;
}


- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    SldIapCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"iapCell" forIndexPath:indexPath];
    if (indexPath.row < _gd.iapProducts.count) {
        SKProduct *product = _gd.iapProducts[indexPath.row];
        
        NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
        [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
        [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
        [numberFormatter setLocale:product.priceLocale];
        NSString *formattedPrice = [numberFormatter stringFromNumber:product.price];
        
        cell.priceLabel.text = formattedPrice;
//        cell.descTextView.text = product.localizedDescription;
        cell.titleLabel.text = product.localizedTitle;
//        NSArray *coinArray = @[
//            @(0),@(0),@(1),@(1),@(2),@(2),@(3),@(3),@(4),@(5)
//        ];
        NSArray *coinArray = @[
                               @(0),@(1),@(2),@(2),@(3),@(3),@(4),@(4),@(5),@(5)
                               ];
        int idx = [(NSNumber*)coinArray[indexPath.row] intValue];
        NSString *coinFile = [NSString stringWithFormat:@"coin%d.png", idx];
        cell.imageView.image = [UIImage imageNamed:coinFile];
    }
    return cell;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (IBAction)onBuyButton:(id)sender {
    SldGameData *gd = [SldGameData getInstance];
    
    UIButton *btn = sender;
    NSIndexPath *indexPath = [self.collectionView indexPathForItemAtPoint:[self.collectionView convertPoint:btn.center fromView:btn.superview]];
    
    if (indexPath.row < _gd.iapProducts.count) {
        SKProduct *product = _gd.iapProducts[indexPath.row];
        
        SKMutablePayment *payment = [SKMutablePayment paymentWithProduct:product];
        payment.quantity = 1;
        payment.applicationUsername = [SldUtil sha1WithString:gd.userName];
        
//        [SldIapManager getInstance].alt = alertNoButton(@"提交购买请求中...");
//        [SldIapManager getInstance].alt = alert(@"提交购买请求中...", nil);
        
        MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        hud.dimBackground = YES;
        _hudView = self.view;
        
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/



@end
