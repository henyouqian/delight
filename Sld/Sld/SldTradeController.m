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
@property (weak, nonatomic) IBOutlet UIView *cardView;

@end

@implementation SldTradeController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _buyView.hidden = YES;
    _exchangeView.hidden = YES;
    _cardView.hidden = YES;
}

- (IBAction)onSegChange:(id)sender {
    _rewardView.hidden = YES;
    _buyView.hidden = YES;
    _exchangeView.hidden = YES;
    _cardView.hidden = YES;
    if (_seg.selectedSegmentIndex == 0) {
        _rewardView.hidden = NO;
    } else if (_seg.selectedSegmentIndex == 1) {
        _buyView.hidden = NO;
    } else if (_seg.selectedSegmentIndex == 2) {
        _exchangeView.hidden = NO;
    } else if (_seg.selectedSegmentIndex == 3) {
        _cardView.hidden = NO;
    }
}


@end
