//
//  SldGameController.m
//  Sld
//
//  Created by Wei Li on 14-4-5.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldGameController.h"
#import "SldGameScene.h"
#import "SldGameData.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldMyMatchController.h"

@interface SldGameController()

@property (weak, nonatomic) IBOutlet UIView *userAdsView;
@property (weak, nonatomic) IBOutlet SldAsyncImageView *userAdsImageView;
@property (weak, nonatomic) IBOutlet UIView *warningView;

@property (nonatomic) SldGameData *gd;
@end

@implementation SldGameController

- (BOOL)showUserAds {
    NSString *imgKey = _gd.match.promoImage;
    if (imgKey.length) {
        [_userAdsImageView asyncLoadUploadImageWithKey:_gd.match.promoImage showIndicator:NO completion:nil];
        _userAdsView.hidden = NO;
        if (_gd.match.promoUrl && _gd.match.promoUrl.length) {
            _warningView.hidden = NO;
        } else {
            _warningView.hidden = YES;
        }
        return YES;
    }
    return NO;
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    if (_gd.match.promoUrl.length == 0) {
        return NO;
    }
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if (segue.identifier && [segue.identifier compare:@"segToPromoWeb"] == 0) {
        NSString *urlStr = _gd.match.promoUrl;
        
        NSRange range = [urlStr rangeOfString:@"://"];
        if (range.location == NSNotFound) {
            urlStr = [NSString stringWithFormat:@"http://%@", urlStr];
        }
        
        SldMatchPromoWebController *vc = segue.destinationViewController;
        vc.url = [NSURL URLWithString:urlStr];
    }
}

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _gd = [SldGameData getInstance];
    _userAdsView.hidden = YES;

    // Configure the view.
    SKView * skView = (SKView *)self.view;
//    skView.showsFPS = YES;
//    skView.showsNodeCount = YES;
    
    // Create and configure the scene.
    SldGameScene* scene = [SldGameScene sceneWithSize:skView.bounds.size controller:self];
    scene.scaleMode = SKSceneScaleModeAspectFill;
    scene.navigationController = self.navigationController;
    
    //
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationWillResignActive)
                                                 name:UIApplicationWillResignActiveNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(applicationDidBecomeActive)
                                                 name:UIApplicationDidBecomeActiveNotification
                                               object:nil];
    
    // Present the scene.
    [skView presentScene:scene];
}

- (void)applicationWillResignActive
{
    [(SKView *)self.view setPaused:YES];
}

- (void)applicationDidBecomeActive
{
    [(SKView *)self.view setPaused:NO];
}

- (IBAction)onCloseUserAds:(id)sender {
    _userAdsView.hidden = YES;
}

- (BOOL)shouldAutorotate
{
    return NO;
}

- (NSUInteger)supportedInterfaceOrientations
{
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        return UIInterfaceOrientationMaskPortrait;
    } else {
        return UIInterfaceOrientationMaskPortrait;
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.navigationController setNavigationBarHidden:YES animated:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.navigationController setNavigationBarHidden:NO animated:animated];
}


@end
