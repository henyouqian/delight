//
//  SldTradeController.m
//  pin
//
//  Created by 李炜 on 14-9-25.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldTradeController.h"

@interface SldTradeController ()
@property (weak, nonatomic) IBOutlet UISegmentedControl *seg;
@property (weak, nonatomic) IBOutlet UIView *rewardView;
@property (weak, nonatomic) IBOutlet UIView *buyView;
@property (weak, nonatomic) IBOutlet UIView *exchangeView;

@end

@implementation SldTradeController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _buyView.hidden = YES;
    _exchangeView.hidden = YES;
}

- (IBAction)onSegChange:(id)sender {
    if (_seg.selectedSegmentIndex == 0) {
        _rewardView.hidden = NO;
        _buyView.hidden = YES;
        _exchangeView.hidden = YES;
    } else if (_seg.selectedSegmentIndex == 1) {
        _rewardView.hidden = YES;
        _buyView.hidden = NO;
        _exchangeView.hidden = YES;
    } else {
        _rewardView.hidden = YES;
        _buyView.hidden = YES;
        _exchangeView.hidden = NO;
    }
}


@end
