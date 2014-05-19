//
//  SldLobbyController.m
//  Sld
//
//  Created by Wei Li on 14-5-8.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldLobbyController.h"
#import "SldRankController.h"
#import "SldCommentController.h"
#import "SldActivityController.h"
#import "SldGameData.h"
#import "UIImageView+sldAsyncLoad.h"
#import "util.h"

@interface SldLobbyController ()
@property (weak, nonatomic) IBOutlet UIImageView *bgImageView;
@property (weak, nonatomic) IBOutlet UIView *rankView;
@property (weak, nonatomic) IBOutlet UIView *commentView;
@property (weak, nonatomic) IBOutlet UIView *activityView;
@property (weak, nonatomic) SldRankController *rankController;
@property (weak, nonatomic) SldCommentController *commentController;
@property (weak, nonatomic) SldActivityController *activityController;

@end

@implementation SldLobbyController

- (IBAction)onSegChange:(id)sender {
    UISegmentedControl *seg = sender;
    int idx = seg.selectedSegmentIndex;
    if (idx == 0) {
        _rankView.hidden = NO;
        _commentView.hidden = YES;
        _activityView.hidden = YES;
        [_commentController onViewShown];
    } else if (idx == 1) {
        _rankView.hidden = YES;
        _commentView.hidden = NO;
        _activityView.hidden = YES;
        [_activityController onViewShown];
    } else {
        _rankView.hidden = YES;
        _commentView.hidden = YES;
        _activityView.hidden = NO;
        [_commentController onViewShown];
    }
}

- (void)onViewShown {
    [_commentController onViewShown];
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSString * segueName = segue.identifier;
    if ([segueName isEqualToString: @"rankController"]) {
        _rankController = (SldRankController*) [segue destinationViewController];
    }else if ([segueName isEqualToString: @"commentController"]) {
        _commentController = (SldCommentController*) [segue destinationViewController];
    } else if ([segueName isEqualToString: @"activityController"]) {
        _activityController = (SldActivityController*) [segue destinationViewController];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _rankView.hidden = NO;
    _commentView.hidden = YES;
    _activityView.hidden = YES;
    
    [self loadBackground];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)loadBackground{
    NSString *bgKey = [SldGameData getInstance].packInfo.coverBlur;
    
    BOOL imageExistLocal = imageExist(bgKey);
    [_bgImageView asyncLoadImageWithKey:bgKey showIndicator:NO completion:^{
        if (!imageExistLocal || _bgImageView.animationImages) {
            _bgImageView.alpha = 0.0;
            [UIView animateWithDuration:1.f animations:^{
                _bgImageView.alpha = 1.0;
            }];
        }
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
