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
@property (weak, nonatomic) IBOutlet UIView *prizeView;
@property (weak, nonatomic) IBOutlet UIView *buyView;
@property (weak, nonatomic) IBOutlet UIView *exchangeView;
@property (weak, nonatomic) IBOutlet UIView *cardView;

@end

static __weak SldTradeController *_inst = nil;

@implementation SldTradeController

+ (instancetype)getInstance {
    return _inst;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _inst = self;
    
    _buyView.hidden = YES;
    _exchangeView.hidden = YES;
    _cardView.hidden = YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    self.tabBarController.navigationItem.title = self.tabBarItem.title;
}

- (IBAction)onSegChange:(id)sender {
    _prizeView.hidden = YES;
    _buyView.hidden = YES;
    _exchangeView.hidden = YES;
    _cardView.hidden = YES;
    if (_seg.selectedSegmentIndex == 0) {
        _prizeView.hidden = NO;
    } else if (_seg.selectedSegmentIndex == 1) {
        _buyView.hidden = NO;
    } else if (_seg.selectedSegmentIndex == 2) {
        _exchangeView.hidden = NO;
    } else if (_seg.selectedSegmentIndex == 3) {
        _cardView.hidden = NO;
    }
}


@end
