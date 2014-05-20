//
//  SldOfflineEventEnterControler.m
//  Sld
//
//  Created by Wei Li on 14-5-20.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldOfflineEventEnterControler.h"
#import "SldGameData.h"
#import "SldDb.h"
#import "SldHttpSession.h"
#import "UIImageView+sldAsyncLoad.h"
#import "util.h"
#import "SldGameController.h"

@interface SldOfflineEventEnterControler ()
@property (weak, nonatomic) IBOutlet UIImageView *bgImageView;

@end

@implementation SldOfflineEventEnterControler

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    SldGameData *gdata = [SldGameData getInstance];
    
    //load pack data
    FMDatabase *db = [SldDb defaultDb].fmdb;
    FMResultSet *rs = [db executeQuery:@"SELECT data FROM pack WHERE id = ?", [NSNumber numberWithUnsignedLongLong:gdata.eventInfo.packId]];
    
    if ([rs next]) { //local
        NSString *data = [rs stringForColumnIndex:0];
        NSError *error = nil;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:[data dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        gdata.packInfo = [PackInfo packWithDictionary:dict];
        
        [self loadBackground];
    }
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

- (IBAction)onEnterGame:(id)sender {
    SldGameController *controller = [self.storyboard instantiateViewControllerWithIdentifier:@"game"];
    controller.gameMode = PRACTICE;
    controller.matchSecret = nil;
    
    [self.navigationController pushViewController:controller animated:YES];
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
