//
//  SldMatchHubController.m
//  pin
//
//  Created by 李炜 on 14/11/11.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldMatchHubController.h"
#import "SldGameData.h"
#import "SldMatchListController.h"
#import "SldHotMatchListController.h"
#import "SldPlayedMatchListController.h"

@interface SldMatchHubController ()
@property (weak, nonatomic) IBOutlet UISegmentedControl *seg;
@property (weak, nonatomic) IBOutlet UIView *latestView;
@property (weak, nonatomic) IBOutlet UIView *hottestView;
@property (weak, nonatomic) IBOutlet UIView *playedView;
@property (nonatomic) SldMatchListController *latestVC;
@property (nonatomic) SldHotMatchListController *hottestVC;
@property (nonatomic) SldPlayedMatchListController *playedVC;
@end

@implementation SldMatchHubController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _latestView.hidden = NO;
    _hottestView.hidden = YES;
    _playedView.hidden = YES;
    
    _latestVC = [SldMatchListController getInst];
    _hottestVC = [SldHotMatchListController getInst];
    _playedVC = [SldPlayedMatchListController getInst];
    
//    _latestVC.view.hidden = NO;
//    _hottestVC.view.hidden = YES;
//    _playedVC.view.hidden = YES;
    
//    [_latestVC onTabSelect];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}

- (IBAction)onSegChange:(id)sender {
    _latestView.hidden = YES;
    _hottestView.hidden = YES;
    _playedView.hidden = YES;
    if (_seg.selectedSegmentIndex == 0) {
        _latestView.hidden = NO;
        [_latestVC onTabSelect];
    } else if (_seg.selectedSegmentIndex == 1) {
        _hottestView.hidden = NO;
        [_hottestVC onTabSelect];
    } else if (_seg.selectedSegmentIndex == 2) {
        _playedView.hidden = NO;
        [_playedVC onTabSelect];
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
