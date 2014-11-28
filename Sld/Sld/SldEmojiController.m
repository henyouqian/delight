//
//  SldEmojiController.m
//  pin
//
//  Created by 李炜 on 14/11/27.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldEmojiController.h"

NSString *const NOTIF_EMOJI = @"NOTIF_EMOJI";

@interface SldEmojiController ()

@end

@implementation SldEmojiController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
}

- (IBAction)onButton:(id)sender {
    UIButton *button = sender;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:NOTIF_EMOJI object:button.titleLabel.text];
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
