//
//  SldMatchPrepareController.m
//  Sld
//
//  Created by 李炜 on 14-6-5.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldMatchPrepareController.h"
#import "SldGameData.h"
#import "SldUtil.h"
#import "UIImageView+sldAsyncLoad.h"

@interface SldMatchPrepareController ()
@property (weak, nonatomic) IBOutlet UIImageView *bgView;

@end

@implementation SldMatchPrepareController

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
    
    [self loadBackground];
    // Do any additional setup after loading the view.
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)loadBackground{
    NSString *bgKey = [SldGameData getInstance].packInfo.coverBlur;
    
    BOOL imageExistLocal = imageExist(bgKey);
    [_bgView asyncLoadImageWithKey:bgKey showIndicator:NO completion:^{
        if (!imageExistLocal || _bgView.animationImages) {
            _bgView.alpha = 0.0;
            [UIView animateWithDuration:1.f animations:^{
                _bgView.alpha = 1.0;
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
