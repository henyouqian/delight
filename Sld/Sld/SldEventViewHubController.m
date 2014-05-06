//
//  SldEventViewHubController.m
//  Sld
//
//  Created by Wei Li on 14-5-5.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldEventViewHubController.h"
#import "SldEventDetailViewController.h"
#import "SldRankController.h"
#import "SldHttpSession.h"
#import "SldGameData.h"
#import "config.h"
#import "util.h"

@interface SldEventViewHubController ()
@property (weak, nonatomic) IBOutlet UISegmentedControl *segmentedControl;
@property (nonatomic) SldEventDetailViewController *eventDetailController;
@property (nonatomic) SldRankController *rankController;
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
    
    //rank view
    _rankController = [self.storyboard instantiateViewControllerWithIdentifier:@"rankController"];
    float topInset = self.navigationController.navigationBar.bounds.size.height+20;
    _rankController.tableView.contentInset = UIEdgeInsetsMake(topInset, 0, 0, 0);
    [self.view addSubview:_rankController.view];
    [self addChildViewController:_rankController];
    
    _eventDetailController.view.hidden = NO;
    _rankController.view.hidden = YES;
}


- (IBAction)onSegChanged:(id)sender {
    switch (_segmentedControl.selectedSegmentIndex) {
        case 0:
            _eventDetailController.view.hidden = NO;
            _rankController.view.hidden = YES;
            break;
        case 1:
            _eventDetailController.view.hidden = YES;
            _rankController.view.hidden = YES;
            break;
        case 2:
            _eventDetailController.view.hidden = YES;
            _rankController.view.hidden = NO;
            [_rankController updateRanks];
            break;
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
        
        UIView *coverView = [[UIView alloc] initWithFrame:bgView.frame];
        coverView.contentMode = UIViewContentModeScaleToFill;
        coverView.backgroundColor = makeUIColor(100, 100, 100, 255);
        coverView.alpha = .5f;
        [bgView insertSubview:coverView atIndex:1];
        
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
