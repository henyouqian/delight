//
//  SldEventViewHubController.m
//  Sld
//
//  Created by Wei Li on 14-5-5.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldEventViewHubController.h"
#import "SldEventDetailViewController.h"
#import "SldLobbyController.h"
#import "SldRankController.h"
#import "SldHttpSession.h"
#import "SldGameData.h"
#import "config.h"
#import "util.h"

@interface SldEventViewHubController ()
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentedControl;
@property (nonatomic) SldEventDetailViewController *eventDetailController;
@property (nonatomic) SldLobbyController *lobbyController;
@property (nonatomic) SldRankController *rankController;
@property (nonatomic) UIView *coverView;
@end

@implementation SldEventViewHubController

static __weak SldEventViewHubController* g_inst = nil;

+ (instancetype)getInstance {
    return g_inst;
}

//- (void)dealloc {
////    _eventDetailController = nil;
////    _rankController = nil;
//}

- (void)viewDidLoad
{
    [super viewDidLoad];
    g_inst = self;
    
    //detail view
    _eventDetailController = [self.storyboard instantiateViewControllerWithIdentifier:@"eventDetail"];
    self.automaticallyAdjustsScrollViewInsets = NO;
    [self.view addSubview:_eventDetailController.view];
    [self addChildViewController:_eventDetailController];
    
    //lobby view
    _lobbyController = [self.storyboard instantiateViewControllerWithIdentifier:@"lobbyController"];
    self.automaticallyAdjustsScrollViewInsets = NO;
    _lobbyController.view.backgroundColor = [UIColor clearColor];
    [self.view addSubview:_lobbyController.view];
    [self addChildViewController:_lobbyController];
    
    //rank view
    _rankController = [self.storyboard instantiateViewControllerWithIdentifier:@"rankController"];
    float topInset = self.navigationController.navigationBar.bounds.size.height+self.navigationController.navigationBar.frame.origin.y;
    _rankController.tableView.contentInset = UIEdgeInsetsMake(topInset, 0, 0, 0);
    [self.view addSubview:_rankController.view];
    [self addChildViewController:_rankController];
    
    _eventDetailController.view.hidden = NO;
    _lobbyController.view.hidden = YES;
    _rankController.view.hidden = YES;
    
    //
    UIInterpolatingMotionEffect *verticalMotionEffect =
    [[UIInterpolatingMotionEffect alloc]
     initWithKeyPath:@"center.y"
     type:UIInterpolatingMotionEffectTypeTiltAlongVerticalAxis];
    verticalMotionEffect.minimumRelativeValue = @(-20);
    verticalMotionEffect.maximumRelativeValue = @(20);
    
    // Set horizontal effect
    UIInterpolatingMotionEffect *horizontalMotionEffect =
    [[UIInterpolatingMotionEffect alloc]
     initWithKeyPath:@"center.x"
     type:UIInterpolatingMotionEffectTypeTiltAlongHorizontalAxis];
    horizontalMotionEffect.minimumRelativeValue = @(-20);
    horizontalMotionEffect.maximumRelativeValue = @(20);
    
    // Create group to combine both
    UIMotionEffectGroup *group = [UIMotionEffectGroup new];
    group.motionEffects = @[horizontalMotionEffect, verticalMotionEffect];
    
    // Add both effects to your view
    //[self.view addMotionEffect:group];
    [_eventDetailController.view addMotionEffect:group];
}


- (IBAction)onSegChanged:(id)sender {
    switch (_segmentedControl.selectedSegmentIndex) {
        case 0:
            _eventDetailController.view.hidden = NO;
            _lobbyController.view.hidden = YES;
            _rankController.view.hidden = YES;
            break;
        case 1:
            _eventDetailController.view.hidden = YES;
            _lobbyController.view.hidden = YES;
            _rankController.view.hidden = NO;
            [_rankController onViewShown];
            break;
        case 2:
            _eventDetailController.view.hidden = YES;
            _lobbyController.view.hidden = NO;
            _rankController.view.hidden = YES;
            break;
    }
    
    if (_coverView) {
        if (_segmentedControl.selectedSegmentIndex == 2) {
            _coverView.backgroundColor = makeUIColor(30, 30, 30, 255);
        } else {
            _coverView.backgroundColor = makeUIColor(100, 100, 100, 255);
        }
    }
}

- (void)loadBackground{
    NSString *bgKey = [SldGameData getInstance].packInfo.coverBlur;
    Config *conf = [Config sharedConf];
    
    NSString *bgPath = makeDocPath([NSString stringWithFormat:@"%@/%@", conf.IMG_CACHE_DIR, bgKey]);
    
    void (^addBg)(BOOL fadein) = ^(BOOL fadein){
        UIImage *image = [UIImage imageWithContentsOfFile:bgPath];
        
        UIImageView *bgView = [[UIImageView alloc] initWithImage:image];
        bgView.contentMode = UIViewContentModeScaleAspectFill;
        bgView.frame = self.view.frame;
        [self.view insertSubview:bgView atIndex:0];
        
        _coverView = [[UIView alloc] initWithFrame:bgView.frame];
        _coverView.contentMode = UIViewContentModeScaleToFill;
        _coverView.backgroundColor = makeUIColor(100, 100, 100, 255);
        _coverView.alpha = .5f;
        [bgView insertSubview:_coverView atIndex:1];
        
        if (fadein) {
            bgView.alpha = 0.0;
            [UIView beginAnimations:@"fade in" context:nil];
            [UIView setAnimationDuration:1.0];
            bgView.alpha = 1.0;
            [UIView commitAnimations];
        }
    };
    
    if ([[NSFileManager defaultManager] fileExistsAtPath:bgPath]) { //local
//        UIImage *image = nil;
//        if ([[[bgPath pathExtension] lowercaseString] compare:@"gif"] == 0) {
//            NSURL *url = [NSURL fileURLWithPath:bgPath];
//            image = [UIImage animatedImageWithAnimatedGIFURL:url];
//        } else {
//            image = [UIImage imageWithContentsOfFile:bgPath];
//        }
        addBg(NO);
        
    } else { //server
        //download
        SldHttpSession *session = [SldHttpSession defaultSession];
        [session downloadFromUrl:[NSString stringWithFormat:@"%@/%@", conf.DATA_HOST, bgKey]
                          toPath:bgPath
                        withData:nil completionHandler:^(NSURL *location, NSError *error, id data)
         {
             addBg(YES);
         }];
    }
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
