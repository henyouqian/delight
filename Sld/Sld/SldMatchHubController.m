//
//  SldMatchHubController.m
//  pin
//
//  Created by 李炜 on 14/11/11.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldMatchHubController.h"
#import "SldGameData.h"
#import "SldLoginViewController.h"

@interface SldMatchHubController ()
@property (weak, nonatomic) IBOutlet UISegmentedControl *seg;
@property (weak, nonatomic) IBOutlet UIView *latestView;
@property (weak, nonatomic) IBOutlet UIView *hottestView;
@property (weak, nonatomic) IBOutlet UIView *playedView;
@end

@implementation SldMatchHubController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _latestView.hidden = NO;
    _hottestView.hidden = YES;
    _playedView.hidden = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    SldGameData *gd = [SldGameData getInstance];
    if (!gd.online) {
        [SldLoginViewController createAndPresentWithCurrentController:self animated:YES];
    }
}

- (IBAction)onSegChange:(id)sender {
    _latestView.hidden = YES;
    _hottestView.hidden = YES;
    _playedView.hidden = YES;
    if (_seg.selectedSegmentIndex == 0) {
        _latestView.hidden = NO;
    } else if (_seg.selectedSegmentIndex == 1) {
        _hottestView.hidden = NO;
    } else if (_seg.selectedSegmentIndex == 2) {
        _playedView.hidden = NO;
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
