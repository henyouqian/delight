//
//  SldMainMenuControllerViewController.m
//  Sld
//
//  Created by 李炜 on 14-7-6.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldMainMenuControllerViewController.h"
#import "SldLoginViewController.h"

@interface SldMainMenuControllerViewController ()
@end

@implementation SldMainMenuControllerViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    
    //login view
    [SldLoginViewController createAndPresentWithCurrentController:self animated:NO];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
