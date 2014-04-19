//
//  SldMatchListViewController.m
//  Sld
//
//  Created by Wei Li on 14-4-18.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldMatchListViewController.h"
#import "util.h"
#import "SldHttpSession.h"

NSString *CELL_ID = @"cellID";

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



@interface SldMatchListViewController ()
@property (nonatomic) UIRefreshControl *refreshControl;
@end

@implementation SldMatchListViewController

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return 1;
}

// The cell that is returned must be retrieved from a call to -dequeueReusableCellWithReuseIdentifier:forIndexPath:
- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    Cell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:CELL_ID forIndexPath:indexPath];
    
    NSString *filename = [NSString stringWithFormat:@"testImg/Image%02d.jpg", indexPath.row+1];
    UIImage *image = [UIImage imageNamed:filename];
    cell.image.image = image;
    return cell;
}


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
    
    self.refreshControl = [[UIRefreshControl alloc] init];
    //refreshControl.tintColor = [UIColormagentaColor];
    
    [self.collectionView addSubview:self.refreshControl];
    [self.collectionView sendSubviewToBack:self.refreshControl];
    
    self.collectionView.alwaysBounceVertical = YES;
    [self.refreshControl addTarget:self action:@selector(refershControlAction) forControlEvents:UIControlEventValueChanged];
}

- (void)refershControlAction {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self.refreshControl endRefreshing];
    });
    
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
//    //
//    NSURL * url = [NSURL URLWithString:@"http://192.168.2.55:9999/auth/login"];
//    
//    // 2
//    NSURLSessionConfiguration *sessionConfig = [NSURLSessionConfiguration defaultSessionConfiguration];
//    
//    // 3
//    NSURLSession *session = [NSURLSession sessionWithConfiguration:sessionConfig
//                                  delegate:nil
//                             delegateQueue:nil];
//    
//    NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:url];
//    [request setHTTPMethod:@"POST"];
//    NSDictionary *body = @{@"Username":@"aa", @"Password":@"aa"};
//    NSData *data = [NSJSONSerialization dataWithJSONObject:body options:0 error:nil];
//    [request setHTTPBody:data];
//    
//    NSURLSessionDataTask * dataTask =[session dataTaskWithRequest:request
//       completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
//           NSDictionary *resp = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
//           NSLog(@"Response:%@\n", resp);
//           
//           NSURL * url = [NSURL URLWithString:@"http://192.168.2.55:9999/auth/info"];
//           NSMutableURLRequest * request = [NSMutableURLRequest requestWithURL:url];
//           [request setHTTPMethod:@"POST"];
//           
//           [[session dataTaskWithRequest:request
//              completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
//                  NSDictionary *resp = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
//                  NSLog(@"Response:%@\n", resp);
//                  
//              }] resume];
//           
//       }];
//    [dataTask resume];
    
    NSDictionary *body = @{@"Username":@"aa", @"Password":@"aa"};
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"auth/login" body:body completionHandler:^(id data, NSURLResponse *response, NSError *error) {
        NSLog(@"data:%@\nerror:%@\n", data, error);
        if (!error) {
            [session postToApi:@"auth/info" body:nil completionHandler:^(id data, NSURLResponse *response, NSError *error) {
                NSLog(@"Response:%@\n", data);
                
            }];
        }
    }];
}
 
- (IBAction)onGameExit:(UIStoryboardSegue *)segue
{

}


@end
