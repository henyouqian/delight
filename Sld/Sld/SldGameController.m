//
//  SldGameController.m
//  Sld
//
//  Created by Wei Li on 14-4-5.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldGameController.h"
#import "SldGameScene.h"

@interface SldGameController()
@end

@implementation SldGameController

- (BOOL)prefersStatusBarHidden {
    return YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    // Configure the view.
    SKView * skView = (SKView *)self.view;
    skView.showsFPS = YES;
    skView.showsNodeCount = YES;
    
    // Create and configure the scene.
    SldGameScene* scene = [SldGameScene sceneWithSize:skView.bounds.size packInfo:self.packInfo];
    scene.scaleMode = SKSceneScaleModeAspectFill;
    scene.gamePlay.delegate = self;
    scene.navigationController = self.navigationController;
    
    // Present the scene.
    [skView presentScene:scene];
}

-(void)dealloc {
    
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
    [self.navigationController setNavigationBarHidden:YES animated:animated];
    [super viewWillAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [self.navigationController setNavigationBarHidden:NO animated:animated];
    [super viewWillDisappear:animated];
}

#pragma mark - SldGamePlayDelegate
- (void)onNextImageWithRotate:(BOOL)rotate {
//    [UIView beginAnimations:nil context:NULL];
//    [UIView setAnimationDuration:0.2];
//    [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
//    if (rotate) {
//        self.backButton.transform = CGAffineTransformMakeRotation(M_PI_2);
//    } else {
//        self.backButton.transform = CGAffineTransformMakeRotation(0);
//    }
//    
//    [UIView commitAnimations];
    
}

@end
