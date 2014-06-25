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
@interface SldIapCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UITextView *descTextView;
@property (weak, nonatomic) IBOutlet UIButton *buyButton;

@end

@implementation SldIapCell
@end


//=======================
@interface SldIapController ()
@property (nonatomic) UIAlertView *alt;
@property (nonatomic) UIAlertView *altBuy;
@property (nonatomic) NSString *secret;
@property (nonatomic) SldGameData *gd;
@end

@implementation SldIapController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _gd = [SldGameData getInstance];
    
    if (_gd.iapProducts == nil) {
        _gd.iapProducts = [NSArray array];
        //UIAlertView *alt = alertNoButton(@"获取商品信息");
        UIAlertView *alt = alert(@"获取商品信息", nil);
        
        SldHttpSession *session = [SldHttpSession defaultSession];
        [session postToApi:@"store/listIapProductId" body:nil completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [alt dismissWithClickedButtonIndex:0 animated:YES];
            if (error) {
                alertHTTPError(error, data);
                return;
            }
            
            NSArray *productIds = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error) {
                lwError("Json error:%@", [error localizedDescription]);
                return;
            }
            
            [self validateProductIdentifiers:productIds];
        }];
        
        [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
    } else {
        [self.collectionView reloadData];
    }
}

- (void)dealloc {
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)validateProductIdentifiers:(NSArray *)productIdentifiers
{
    //_alt = alertNoButton(@"验证商品信息");
    _alt = alert(@"验证商品信息", nil);
    SKProductsRequest *productsRequest = [[SKProductsRequest alloc]
                                          initWithProductIdentifiers:[NSSet setWithArray:productIdentifiers]];
    productsRequest.delegate = self;
    [productsRequest start];
}

// SKProductsRequestDelegate protocol method
- (void)productsRequest:(SKProductsRequest *)request
     didReceiveResponse:(SKProductsResponse *)response
{
    [_alt dismissWithClickedButtonIndex:0 animated:YES];
    _alt = nil;
    _gd.iapProducts = [response.products sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        int price1 = [((SKProduct*)obj1).price intValue];
        int price2 = [((SKProduct*)obj2).price intValue];
        if (price1 < price2) {
            return NSOrderedAscending;
        } else if (price1 > price2) {
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
        
        [cell.buyButton setTitle:formattedPrice forState:UIControlStateNormal];
        cell.descTextView.text = product.localizedDescription;
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
        
        //_altBuy = alertNoButton(@"提交购买请求中...");
        _altBuy = alert(@"提交购买请求中...", nil);
        [[SKPaymentQueue defaultQueue] addPayment:payment];
    }
}

- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions {
    if (_altBuy) {
        [_altBuy dismissWithClickedButtonIndex:0 animated:YES];
        _altBuy = nil;
    }
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
                // Call the appropriate custom method.
            case SKPaymentTransactionStatePurchased:
                [self purchase:transaction];
                
                break;
            case SKPaymentTransactionStateFailed:
                lwError("%@", [transaction.error localizedDescription]);
                //lwInfo("Failed: %@", transaction.error);
                //[self failedTransaction:transaction];
                alert([transaction.error localizedDescription], nil);
                [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
                break;
            case SKPaymentTransactionStateRestored:
                //lwInfo("Restored");
                //[self restoreTransaction:transaction];
                [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            default:
                lwError("%@", [transaction.error localizedDescription]);
                break;
        }
    }
}

- (void)purchase:(SKPaymentTransaction*)transaction {
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
        
        _secret = [dict objectForKey:@"Secret"];
        if (!_secret) {
            alert(@"服务器错误，请稍后重试", nil);
            return;
        }
        
        //checksum
        SldGameData *gd = [SldGameData getInstance];
        
        NSString *checksum = [NSString stringWithFormat:@"%@%lld%@,", _secret, gd.userId, gd.userName];
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
            SInt64 addMoney = [(NSNumber*)[dict objectForKey:@"AddMoney"] longLongValue];
            SInt64 money = [(NSNumber*)[dict objectForKey:@"Money"] longLongValue];
            gd.money = money;
            alert([NSString stringWithFormat:@"获得%lld个金币，现有%lld个金币", addMoney, money], nil);
            [[SldUserController getInstance] updateMoney];
            
            [[SKPaymentQueue defaultQueue] finishTransaction: transaction];
        }];
        
    }];
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
