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
#import "SldUtil.h"
#import "SldGameController.h"
#import "config.h"

@interface SldOfflineEventEnterControler ()
@property (weak, nonatomic) IBOutlet UIImageView *bgImageView;
@property (weak, nonatomic) IBOutlet UIView *scoresView;
@property (weak, nonatomic) IBOutlet UILabel *goldLabel;
@property (weak, nonatomic) IBOutlet UILabel *silverLabel;
@property (weak, nonatomic) IBOutlet UILabel *bronzeLabel;
@property (nonatomic) SldGameData *gd;
@end

@implementation SldOfflineEventEnterControler

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _gd = [SldGameData getInstance];
    
    //load pack data
    FMDatabase *db = [SldDb defaultDb].fmdb;
    FMResultSet *rs = [db executeQuery:@"SELECT data FROM pack WHERE id = ?", [NSNumber numberWithUnsignedLongLong:_gd.eventInfo.packId]];
    
    if ([rs next]) { //local
        NSString *data = [rs stringForColumnIndex:0];
        NSError *error = nil;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:[data dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        _gd.packInfo = [PackInfo packWithDictionary:dict];
        
        [self loadBackground];
    }
    
    self.title = @"挑战";
    _gd.recentScore = 0;
    
    //cup label
    NSArray *secs = _gd.eventInfo.challengeSecs;
    if (secs != nil && secs.count == 3) {
        _goldLabel.text = formatScore([(NSNumber*)secs[0] intValue]*-1000);
        _silverLabel.text = formatScore([(NSNumber*)secs[1] intValue]*-1000);
        _bronzeLabel.text = formatScore([(NSNumber*)secs[2] intValue]*-1000);
    } else {
        NSString *text = @"−:−−.−−−";
        _goldLabel.text = text;
        _silverLabel.text = text;
        _bronzeLabel.text = text;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [self reloadLocalScore];
}

- (void)reloadLocalScore {
    SldGameData *gd = [SldGameData getInstance];
    FMDatabase *db = [SldDb defaultDb].fmdb;
    NSError *error = nil;
    
    NSString *key = [NSString stringWithFormat:@"%d/%d", (int)gd.eventInfo.id, (int)gd.userId];
    FMResultSet *rs = [db executeQuery:@"SELECT data FROM localScore WHERE key = ?", key];
    
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
    
    float x = 160;
    float y = 100;
    float w = 100;
    float h = 25;
    BOOL recentFound = NO;
    int scoreNum = [scores count];
    for (int i = 0; i < LOCAL_SCORE_COUNT_LIMIT; ++i) {
        UILabel *idxLabel = [[UILabel alloc] initWithFrame:CGRectMake(x, y, 25, h)];
        idxLabel.text = [NSString stringWithFormat:@"%d", i+1];
        idxLabel.textColor = [UIColor whiteColor];
        idxLabel.textAlignment = NSTextAlignmentRight;
        [_scoresView addSubview:idxLabel];
        
        UILabel *scoreLabel = [[UILabel alloc] initWithFrame:CGRectMake(x+50, y, w, h)];
        
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
    
    //cup highlight
    int hs = gd.eventPlayRecord.challengeHighScore;
    NSArray *secs = gd.eventInfo.challengeSecs;
    if (hs != 0 && secs.count == 3) {
        _goldLabel.textColor = [UIColor whiteColor];
        _silverLabel.textColor = [UIColor whiteColor];
        _bronzeLabel.textColor = [UIColor whiteColor];
        
        UIColor *color = makeUIColor(255, 197, 131, 255);
        if (hs >= [(NSNumber*)secs[0] intValue]*-1000) {
            _goldLabel.textColor = color;
        } else if (hs >= [(NSNumber*)secs[1] intValue]*-1000) {
            _silverLabel.textColor = color;
        } else if (hs >= [(NSNumber*)secs[2] intValue]*-1000) {
            _bronzeLabel.textColor = color;
        }
    }
}

- (void)loadBackground{
    NSString *bgKey = [SldGameData getInstance].packInfo.coverBlur;
    
    BOOL imageExistLocal = imageExist(bgKey);
    NSString* localPath = makeImagePath(bgKey);
    if (imageExistLocal) {
        _bgImageView.image = [UIImage imageWithContentsOfFile:localPath];
    } else {
        [_bgImageView asyncLoadImageWithKey:bgKey showIndicator:NO completion:^{
            _bgImageView.alpha = 0.0;
            [UIView animateWithDuration:1.f animations:^{
                _bgImageView.alpha = 1.0;
            }];
        }];
    }
}

- (IBAction)onEnterGame:(id)sender {
    [self loadPacks];
}

- (void)loadPacks {
    NSArray *imageKeys = _gd.packInfo.images;
    __block int localNum = 0;
    NSUInteger totalNum = [imageKeys count];
    if (totalNum == 0) {
        alert(@"Not downloaded", nil);
        return;
    }
    for (NSString *imageKey in imageKeys) {
        if (imageExist(imageKey)) {
            localNum++;
        }
    }
    if (localNum == totalNum) {
        [self enterGame];
        return;
    } else if (localNum < totalNum) {
        NSString *msg = [NSString stringWithFormat:@"%d%%", (int)(100.f*(float)localNum/(float)totalNum)];
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"图集下载中..."
                                                        message:msg
                                                       delegate:self
                                              cancelButtonTitle:@"取消"
                                              otherButtonTitles:nil];
        [alert show];
        
        //download
        SldHttpSession *session = [SldHttpSession defaultSession];
        [session cancelAllTask];
        for (NSString *imageKey in imageKeys) {
            if (!imageExist(imageKey)) {
                [session downloadFromUrl:makeImageServerUrl(imageKey)
                                  toPath:makeImagePath(imageKey)
                                withData:nil completionHandler:^(NSURL *location, NSURLResponse *response, NSError *error, id data)
                 {
                     if (error) {
                         lwError("Download error: %@", error.localizedDescription);
                         [alert dismissWithClickedButtonIndex:0 animated:YES];
                         return;
                     }
                     localNum++;
                     [alert setMessage:[NSString stringWithFormat:@"%d%%", (int)(100.f*(float)localNum/(float)totalNum)]];
                     
                     //download complete
                     if (localNum == totalNum) {
                         [alert dismissWithClickedButtonIndex:0 animated:YES];
                         [self enterGame];
                     }
                 }];
            }
        }
    }
}

- (void)enterGame {
    //update db
    FMDatabase *db = [SldDb defaultDb].fmdb;
    BOOL ok = [db executeUpdate:@"UPDATE event SET packDownloaded=1 WHERE id=?", @(_gd.eventInfo.id)];
    if (!ok) {
        lwError("Sql error:%@", [db lastErrorMessage]);
        return;
    }
    
    //
    SldGameController *controller = [self.storyboard instantiateViewControllerWithIdentifier:@"game"];
    controller.matchSecret = nil;
    
    [self.navigationController pushViewController:controller animated:YES];
}


@end
