//
//  SldLobbyController.m
//  Sld
//
//  Created by Wei Li on 14-5-8.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldLobbyController.h"
#import "SldRankController.h"
#import "SldBriefController.h"
#import "SldBetController.h"
#import "SldGameData.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldUtil.h"

@interface SldLobbyController ()
@property (weak, nonatomic) IBOutlet UIImageView *bgImageView;
@property (weak, nonatomic) IBOutlet UIView *rankView;
@property (weak, nonatomic) IBOutlet UIView *commentView;
@property (weak, nonatomic) IBOutlet UIView *betView;
@property (weak, nonatomic) SldRankController *rankController;
@property (weak, nonatomic) SldBriefController *briefController;
@property (weak, nonatomic) SldBetController *betController;
@property (weak, nonatomic) IBOutlet UISegmentedControl *seg;

@end

@implementation SldLobbyController

- (IBAction)onSegChange:(id)sender {
    UISegmentedControl *seg = sender;
    NSInteger idx = seg.selectedSegmentIndex;
    
    _rankView.hidden = YES;
    _commentView.hidden = YES;
    _betView.hidden = YES;
    _rankController.tableView.scrollsToTop = NO;
    _betController.tableView.scrollsToTop = NO;
    
    if (idx == 0) {
        _commentView.hidden = NO;
//        _briefController.tableView.scrollsToTop = YES;
//        [_briefController onViewShown];
    } else if (idx == 1) {
        _rankView.hidden = NO;
        _rankController.tableView.scrollsToTop = YES;
        [_rankController onViewShown];
    } else {
        _betView.hidden = NO;
        _betController.tableView.scrollsToTop = YES;
        [_betController onViewShown];
    }
    self.title = [seg titleForSegmentAtIndex:idx];
}

- (void)viewWillAppear:(BOOL)animated {
    //[_briefController onViewShown];
}

- (void) prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    NSString * segueName = segue.identifier;
    UIViewController* vc = (UIViewController*) [segue destinationViewController];
    if ([segueName isEqualToString: @"rankController"]) {
        _rankController = (SldRankController*)vc;
    } else if ([segueName isEqualToString: @"briefController"]) {
        _briefController = (SldBriefController*)vc;
    } else if ([segueName isEqualToString: @"betController"]) {
        _betController = (SldBetController*)vc;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self onSegChange:_seg];
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
    NSString* localPath = makeImagePath(bgKey);
    if (imageExistLocal) {
        _bgImageView.image = [UIImage imageWithContentsOfFile:localPath];
    } else {
        [_bgImageView asyncLoadImageWithKey:bgKey showIndicator:NO completion:^{
            _bgImageView.alpha = 0.0;
            [UIView animateWithDuration:1.f animations:^{
                _bgImageView.alpha = 1.0;
            }];
        }];
    }
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
