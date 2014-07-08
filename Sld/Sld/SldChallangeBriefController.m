//
//  SldChallangeBriefController.m
//  Sld
//
//  Created by 李炜 on 14-7-8.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldChallangeBriefController.h"
#import "SldGameData.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldDb.h"
#import "SldHttpSession.h"

@interface SldChallangeBriefController ()
@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@property (weak, nonatomic) IBOutlet UILabel *starLabel1;
@property (weak, nonatomic) IBOutlet UILabel *starLabel2;
@property (weak, nonatomic) IBOutlet UILabel *starLabel3;
@property (weak, nonatomic) IBOutlet UIImageView *bgImageView;
@property (nonatomic) SldGameData *gd;

@end

@implementation SldChallangeBriefController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _gd = [SldGameData getInstance];
    
    //load pack data
    UInt64 packId = _gd.eventInfo.packId;
    FMDatabase *db = [SldDb defaultDb].fmdb;
    FMResultSet *rs = [db executeQuery:@"SELECT data FROM pack WHERE id = ?", [NSNumber numberWithUnsignedLongLong:packId]];
    if ([rs next]) { //local
        NSString *data = [rs stringForColumnIndex:0];
        NSError *error = nil;
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:[data dataUsingEncoding:NSUTF8StringEncoding] options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        _gd.packInfo = [PackInfo packWithDictionary:dict];
        
        _titleLabel.text = _gd.packInfo.title;
        
        [self loadBackground];
    } else {
        SldHttpSession *session = [SldHttpSession defaultSession];
        NSDictionary *body = @{@"Id":@(packId)};
        [session postToApi:@"pack/get" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                alertHTTPError(error, data);
                return;
            }
            
            NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error) {
                lwError("Json error:%@", [error localizedDescription]);
                return;
            }
            _gd.packInfo = [PackInfo packWithDictionary:dict];
            
            //save to db
            BOOL ok = [db executeUpdate:@"REPLACE INTO pack (id, data) VALUES(?, ?)", dict[@"Id"], data];
            if (!ok) {
                lwError("Sql error:%@", [db lastErrorMessage]);
                return;
            }
            
            [self loadBackground];
            _titleLabel.text = _gd.packInfo.title;
            
        }];
    }
}

- (void)loadBackground{
    NSString *bgKey = [SldGameData getInstance].packInfo.coverBlur;
    
    [_bgImageView asyncLoadImageWithKey:bgKey showIndicator:NO completion:^{
        _bgImageView.alpha = 0.0;
        [UIView animateWithDuration:1.f animations:^{
            _bgImageView.alpha = 1.0;
        }];
    }];
}

- (IBAction)onStartButton:(id)sender {
    
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
