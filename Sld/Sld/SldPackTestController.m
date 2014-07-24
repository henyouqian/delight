//
//  SldPackTestController.m
//  Sld
//
//  Created by 李炜 on 14-7-24.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldPackTestController.h"
#import "SldGameData.h"
#import "SldUtil.h"
#import "SldGameController.h"
#import "SldDb.h"
#import "SldHttpSession.h"

@interface SldPackTestController ()
@property (weak, nonatomic) IBOutlet UITextField *packIdInput;
@property (weak, nonatomic) IBOutlet UITextField *sliderNumInput;
@property (nonatomic) SldGameData *gd;
@end

@implementation SldPackTestController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _gd = [SldGameData getInstance];
}

- (IBAction)onStartButton:(id)sender {
    //event
    if (_gd.eventInfo == nil) {
        _gd.eventInfo = [[EventInfo alloc] init];
    }
    _gd.eventInfo.sliderNum = [_sliderNumInput.text intValue];
    if (_gd.eventInfo.sliderNum < 3) {
        _gd.eventInfo.sliderNum = 3;
    } else if (_gd.eventInfo.sliderNum > 12) {
        _gd.eventInfo.sliderNum = 12;
    }
    
    //get pack
    int packId = [_packIdInput.text intValue];
    
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
        
        [self downloadPack];
    }];
    
    
}

- (void)downloadPack {
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
    _gd.gameMode = PRACTICE;
    
    //update db
    FMDatabase *db = [SldDb defaultDb].fmdb;
    BOOL ok = [db executeUpdate:@"UPDATE event SET packDownloaded=1 WHERE id=?", @(_gd.challengeInfo.id)];
    if (!ok) {
        lwError("Sql error:%@", [db lastErrorMessage]);
        return;
    }
    
    //
    SldGameController *controller = [self.storyboard instantiateViewControllerWithIdentifier:@"game"];
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

//==========================
@interface SldPackTestHistoryCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UILabel *label;
@end

@implementation SldPackTestHistoryCell

@end

//==========================
@interface SldPackTestHistoryController : UITableViewController
@property (nonatomic) NSArray *history;

@end


@implementation SldPackTestHistoryController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    SldDb *db = [SldDb defaultDb];
    NSString *key = @"practiceHistory";
    NSData *data = [db getValue:key];
    _history = [NSArray array];
    if (data) {
        _history = [NSJSONSerialization JSONObjectWithData:data options:0 error:nil];
    }
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _history.count;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SldPackTestHistoryCell *cell = [tableView dequeueReusableCellWithIdentifier:@"packTestHistoryCell" forIndexPath:indexPath];
    if (indexPath.row < _history.count) {
        cell.label.text = _history[indexPath.row];
    }
    return cell;
}

@end
