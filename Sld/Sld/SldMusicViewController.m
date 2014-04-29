//
//  SldMusicViewController.m
//  Sld
//
//  Created by Wei Li on 14-4-30.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldMusicViewController.h"
#import "SldStreamPlayer.h"

@interface SldMusicViewController ()
@property (weak, nonatomic) IBOutlet UITextField *channelInput;

@end

@implementation SldMusicViewController

- (IBAction)onChannelButton:(id)sender {
    NSString *text = _channelInput.text;
    if ([text length]) {
        [[SldStreamPlayer defautPlayer] setChannel:[text intValue]];
    }
}

- (IBAction)onPlayButton:(id)sender {
    [[SldStreamPlayer defautPlayer] play];
}

- (IBAction)onStopButton:(id)sender {
    [[SldStreamPlayer defautPlayer] stop];
}

- (IBAction)onNextButton:(id)sender {
    [[SldStreamPlayer defautPlayer] next];
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
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
