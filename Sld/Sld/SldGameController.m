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


@end
