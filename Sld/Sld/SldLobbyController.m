//
//  SldLobbyController.m
//  Sld
//
//  Created by Wei Li on 14-5-8.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldLobbyController.h"
#import "SldCommentController.h"
#import "SldActivityController.h"

@interface SldLobbyController ()
@property (weak, nonatomic) IBOutlet UIView *commentView;
@property (weak, nonatomic) IBOutlet UIView *activityView;
@property (weak, nonatomic) SldCommentController *commentController;
@property (weak, nonatomic) SldActivityController *activityController;

@end

@implementation SldLobbyController

- (IBAction)onSegChange:(id)sender {
    UISegmentedControl *seg = sender;
    if ([seg selectedSegmentIndex] == 0) {
        _commentView.hidden = NO;
        _activityView.hidden = YES;
        [_commentController onViewShown];
    } else {
        _commentView.hidden = YES;
        _activityView.hidden = NO;
        [_activityController onViewShown];
    }
}

- (void)onViewShown {
    [_commentController onViewShown];
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSString * segueName = segue.identifier;
    if ([segueName isEqualToString: @"commentController"]) {
        _commentController = (SldCommentController*) [segue destinationViewController];
    } else if ([segueName isEqualToString: @"activityController"]) {
        _activityController = (SldActivityController*) [segue destinationViewController];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _commentView.hidden = NO;
    _activityView.hidden = YES;
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
