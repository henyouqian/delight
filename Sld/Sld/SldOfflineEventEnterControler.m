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
#import "config.h"

@interface SldOfflineEventEnterControler ()
@property (weak, nonatomic) IBOutlet UIImageView *bgImageView;
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
    
    self.title = @"本地排名";
    gd.recentScore = 0;
}

- (void)viewWillAppear:(BOOL)animated {
    [self reloadLocalScore];
}

- (void)reloadLocalScore {
    SldGameData *gd = [SldGameData getInstance];
    FMDatabase *db = [SldDb defaultDb].fmdb;
    NSError *error = nil;
    
    FMResultSet *rs = [db executeQuery:@"SELECT data FROM localScore WHERE key = ?", [NSNumber numberWithUnsignedLongLong:gd.eventInfo.id]];
    
    NSArray *scores = [NSArray array];
    BOOL dataFound = [rs next];
    if (dataFound) {
        NSData *jsData = [rs dataForColumnIndex:0];
        scores = [NSJSONSerialization JSONObjectWithData:jsData options:0 error:&error];
        if (error) {
            lwError("%@", error);
            return;
        }
    }
    [[_scoresView subviews] makeObjectsPerformSelector:@selector(removeFromSuperview)];
    
    float x = -20;
    float y = 100;
    float w = 100;
    float h = 25;
    BOOL recentFound = NO;
    int scoreNum = [scores count];
    for (int i = 0; i < LOCAL_SCORE_COUNT_LIMIT; ++i) {
        UILabel *idxLabel = [[UILabel alloc] initWithFrame:CGRectMake(x, y, w, h)];
        idxLabel.text = [NSString stringWithFormat:@"%d", i+1];
        idxLabel.textColor = [UIColor whiteColor];
        idxLabel.textAlignment = NSTextAlignmentRight;
        [_scoresView addSubview:idxLabel];
        
        UILabel *scoreLabel = [[UILabel alloc] initWithFrame:CGRectMake(x+200, y, w, h)];
        
        scoreLabel.textColor = [UIColor whiteColor];
        [_scoresView addSubview:scoreLabel];
        
        if (i < scoreNum) {
            int score = [[scores objectAtIndex:i] intValue];
            scoreLabel.text = formatScore(score);
            
            if (!recentFound && score == gd.recentScore) {
                recentFound = YES;
                UIColor *color = makeUIColor(255, 197, 131, 255);
                scoreLabel.textColor = color;
                idxLabel.textColor = color;
                gd.recentScore = 0;
            }
        } else {
            scoreLabel.text = @"−:−−.−−−";
        }
        
        y += h+5;
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
