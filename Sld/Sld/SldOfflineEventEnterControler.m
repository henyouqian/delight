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
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@end

@interface SldOfflineEventEnterControler()
@property (weak, nonatomic) IBOutlet UIView *scoresView;
@end

@implementation SldOfflineEventEnterControler

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    SldGameData *gd = [SldGameData getInstance];
    
    //load pack data
    FMDatabase *db = [SldDb defaultDb].fmdb;
    FMResultSet *rs = [db executeQuery:@"SELECT data FROM pack WHERE id = ?", [NSNumber numberWithUnsignedLongLong:gd.eventInfo.packId]];
    
    if ([rs next]) { //local
        NSString *data = [rs stringForColumnIndex:0];
        NSError *error = nil;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:[data dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        gd.packInfo = [PackInfo packWithDictionary:dict];
        
        [self loadBackground];
    }
    
    _titleLabel.text = gd.packInfo.title;
}

- (void)viewWillAppear:(BOOL)animated {
    [self reloadLocalScore];
}

- (void)reloadLocalScore {
    SldGameData *gd = [SldGameData getInstance];
    FMDatabase *db = [SldDb defaultDb].fmdb;
    NSError *error = nil;
    
    FMResultSet *rs = [db executeQuery:@"SELECT data FROM localScore WHERE key = ?", [NSNumber numberWithUnsignedLongLong:gd.eventInfo.id]];
    if ([rs next]) {
        NSData *jsData = [rs dataForColumnIndex:0];
        NSArray *scores = [NSJSONSerialization JSONObjectWithData:jsData options:0 error:&error];
        if (error) {
            lwError("%@", error);
            return;
        }
        
        [[_scoresView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
        float x = 80;
        float y = 150;
        float w = 100;
        float h = 25;
        int i = 0;
        for (NSNumber *score in scores) {
            UILabel *idxLabel = [[UILabel alloc] initWithFrame:CGRectMake(x, y, w, h)];
            idxLabel.text = [NSString stringWithFormat:@"%d", i+1];
            idxLabel.textColor = [UIColor whiteColor];
            [_scoresView addSubview:idxLabel];
            
            UILabel *scoreLabel = [[UILabel alloc] initWithFrame:CGRectMake(x+90, y, w, h)];
            scoreLabel.text = formatScore([score intValue]);
            scoreLabel.textColor = [UIColor whiteColor];
            [_scoresView addSubview:scoreLabel];
            
            y += h+5;
            i++;
        }
    } else {
        lwInfo(@"no local score");
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
