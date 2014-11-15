//
//  SldMatchBriefController.m
//  pin
//
//  Created by 李炜 on 14-9-4.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldMatchBriefController.h"
#import "SldGameData.h"
#import "SldHttpSession.h"
#import "SldConfig.h"
#import "SldGameController.h"
#import "SldIapController.h"
#import "SldUtil.h"
#import "MSWeakTimer.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldMyMatchController.h"


//==============================
@interface SldMatchBriefController ()
@property (weak, nonatomic) IBOutlet UIButton *practiceButton;
@property (weak, nonatomic) IBOutlet UIButton *matchButton;
@property (weak, nonatomic) IBOutlet UIButton *rewardButton;
@property (weak, nonatomic) IBOutlet UIButton *rankButton;
@property (weak, nonatomic) IBOutlet UIButton *reviewButton;

@property (weak, nonatomic) IBOutlet UILabel *bestScoreLabel;
@property (weak, nonatomic) IBOutlet UILabel *rankLabel;
@property (weak, nonatomic) IBOutlet UILabel *matchTimeLabel;
@property (weak, nonatomic) IBOutlet UILabel *tryNumLabel;
@property (weak, nonatomic) IBOutlet UILabel *ownerLabel;

@property (weak, nonatomic) IBOutlet UILabel *titleLabel;
@property (weak, nonatomic) IBOutlet UILabel *rewardLabel;
@property (weak, nonatomic) IBOutlet UIImageView *bgImageView;
@property (weak, nonatomic) IBOutlet UIButton *editButton;
@property (weak, nonatomic) IBOutlet UIButton *reportButton;

@property (nonatomic) SldGameData *gd;
@property (nonatomic) MSWeakTimer *secTimer;
@property (nonatomic) MSWeakTimer *minTimer;

@property (nonatomic) NSString *secret;
@property (nonatomic) BOOL matchRunning;
@end

@implementation SldMatchBriefController

-(void)dealloc {
    [_secTimer invalidate];
    [_minTimer invalidate];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _gd = [SldGameData getInstance];
    _gd.matchPlay = nil;
    
    _ownerLabel.hidden = YES;
    
    lwInfo("matchId: %lld", _gd.match.id);
    
    //timer
    _secTimer = [MSWeakTimer scheduledTimerWithTimeInterval:1.f target:self selector:@selector(onSecTimer) userInfo:nil repeats:YES dispatchQueue:dispatch_get_main_queue()];
    
    _minTimer = [MSWeakTimer scheduledTimerWithTimeInterval:60.f target:self selector:@selector(onMinTimer) userInfo:nil repeats:YES dispatchQueue:dispatch_get_main_queue()];
    
    //button disable
    _practiceButton.enabled = NO;
    _matchButton.enabled = NO;
    _rewardButton.enabled = NO;
    _rankButton.enabled = NO;
    _reviewButton.enabled = NO;
    
    //
    [self onSecTimer];
    
    //load pack
    [_gd loadPack:_gd.match.packId completion:^(PackInfo *packInfo) {
        [self refreshDynamicData];
        [self loadBackground];
    }];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if (_gd.matchPlay) {
        [self refreshUI];
        //refreshDynamicData;
    }
}

- (void)loadBackground{
    NSString *bgKey = [SldGameData getInstance].packInfo.coverBlur;
    
    [_bgImageView asyncLoadUploadedImageWithKey:bgKey showIndicator:NO completion:^{
        _bgImageView.alpha = 0.0;
        [UIView animateWithDuration:1.f animations:^{
            _bgImageView.alpha = 1.0;
        }];
    }];
}

- (void)onSecTimer {
    Match *match = _gd.match;
    MatchPlay *matchPlay = _gd.matchPlay;
    _matchRunning = NO;
    
    NSDate *beginTime = [NSDate dateWithTimeIntervalSince1970:match.beginTime];
    NSTimeInterval beginIntv = [beginTime timeIntervalSinceNow];
    
    NSDate *endTime = [NSDate dateWithTimeIntervalSince1970:match.endTime];
    NSTimeInterval endIntv = [endTime timeIntervalSinceNow];
    
    if (beginIntv > 0) {
        NSString *str = formatInterval((int)beginIntv);
        _matchTimeLabel.text = [NSString stringWithFormat:@"距离开始：%@", str];
        [_matchButton setTitle:@"未开始" forState:UIControlStateDisabled];
        _matchButton.enabled = NO;
    } else if (endIntv <= 0 ) {
        _matchTimeLabel.text = @"比赛已结束";
        [_matchButton setTitle:@"已结束" forState:UIControlStateDisabled];
        _matchButton.enabled = NO;
    } else {
        NSString *str = formatInterval((int)endIntv);
        
        _matchTimeLabel.text = [NSString stringWithFormat:@"比赛剩余：%@", str];
        
        [_matchButton setTitle:@"比赛" forState:UIControlStateNormal];
        if (_gd.packInfo && matchPlay) {
            _matchButton.enabled = YES;
        } else {
            _matchButton.enabled = NO;
        }
        
        _matchRunning = YES;
    }
    
    //edit button
    _reportButton.hidden = _gd.match.ownerId == _gd.playerInfo.userId;
    if (_gd.match.ownerId == _gd.playerInfo.userId && _matchRunning) {
        _editButton.hidden = NO;
    } else {
        _editButton.hidden = YES;
    }
}

- (void)onMinTimer {
    [self refreshDynamicData];
}

- (void)refreshDynamicData {
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"MatchId":@(_gd.match.id)};
    [session postToApi:@"match/getDynamicData" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        _gd.matchPlay = [[MatchPlay alloc] initWithDict:dict];
        
        //reward
        _gd.match.extraCoupon = _gd.matchPlay.extraCoupon;
        _gd.match.playTimes = _gd.matchPlay.playTimes;
        
        //buttons
        _practiceButton.enabled = YES;
        _rewardButton.enabled = YES;
        _rankButton.enabled = YES;
        
        [self refreshUI];
    }];

}

- (void)refreshUI {
    //reward
    Match *match = _gd.match;
    if (match.extraCoupon == 0) {
        _rewardLabel.text = [NSString stringWithFormat:@"比赛奖金：%d", match.rewardCoupon];
    } else {
        _rewardLabel.text = [NSString stringWithFormat:@"比赛奖金：%d+%d", match.rewardCoupon, match.extraCoupon];
    }
    
    //title
    _titleLabel.text = match.title;
    
    //score
    _bestScoreLabel.text = [NSString stringWithFormat:@"%@", formatScore(_gd.matchPlay.highScore)];
    
    //rank
    _rankLabel.text = [NSString stringWithFormat:@"我的排名：%d/%d", _gd.matchPlay.myRank, _gd.matchPlay.rankNum];
    
    //try number
    _tryNumLabel.text = [NSString stringWithFormat:@"尝试次数：%d/%d", _gd.matchPlay.tries, _gd.matchPlay.playTimes];
    
    //review button
    if ((_gd.matchPlay && _gd.matchPlay.highScore != 0) || _matchRunning == NO) {
        _reviewButton.enabled = YES;
    }
    
    //owner label
    if (_gd.match.ownerName && _gd.match.ownerName.length > 0) {
        _ownerLabel.text = [NSString stringWithFormat:@"发布者：%@", _gd.match.ownerName];
        _ownerLabel.hidden = NO;
    }
}

- (IBAction)onPracticeButton:(id)sender {
    _gd.gameMode = M_PRACTICE;
    _gd.autoPaging = NO;
    
    [self loadAndEnterGame];
}

- (IBAction)onLikeButton:(id)sender {
    UIButton *btn = sender;
    [btn setTitleColor:makeUIColor(244, 75, 116, 255) forState:UIControlStateNormal];
}

- (IBAction)onMatchButton:(id)sender {
    MatchPlay *matchPlay = _gd.matchPlay;
    
    if (matchPlay.freeTries > 0) {
        NSString *str = [NSString stringWithFormat:@"剩余%d次免费机会，开始比赛吗？", matchPlay.freeTries];
        [[[UIAlertView alloc] initWithTitle:str
                                    message:nil
                           cancelButtonItem:[RIButtonItem itemWithLabel:@"取消" action:^{
            // Handle "Cancel"
        }]
                           otherButtonItems:[RIButtonItem itemWithLabel:@"开始比赛" action:^{
            [self playBegin];
        }], nil] show];
    } else {
        //check gold coin
        if (_gd.playerInfo.goldCoin == 0) {
            [[[UIAlertView alloc] initWithTitle:@"购买金币？"
                                        message:@"使用金币游戏可以：1.多一次挑战高分的机会。2.开启自动翻页，助你获得更好成绩。3.此金币加入到奖池中，您可能获得更高到奖金。"
                               cancelButtonItem:[RIButtonItem itemWithLabel:@"取消" action:^{
                // Handle "Cancel"
            }]
                               otherButtonItems:[RIButtonItem itemWithLabel:@"去购买金币" action:^{
                // buy
                SldIapController* vc = (SldIapController*)[getStoryboard() instantiateViewControllerWithIdentifier:@"iapController"];
                [self.navigationController pushViewController:vc animated:YES];
                
            }], nil] show];
        } else {
            NSString *str = [NSString stringWithFormat:@"花一枚金币，开始比赛？(现有%d金币)", _gd.playerInfo.goldCoin];
            
            [[[UIAlertView alloc] initWithTitle:str
                                        message:nil
                               cancelButtonItem:[RIButtonItem itemWithLabel:@"取消" action:^{
                // Handle "Cancel"
            }]
                               otherButtonItems:[RIButtonItem itemWithLabel:@"开始比赛" action:^{
                [self playBegin];
            }], nil] show];
        }
    }
    
//    [self loadAndEnterGame];
}

- (void)playBegin {
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{@"MatchId":@(_gd.match.id)};
    [session postToApi:@"match/playBegin" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        _gd.matchSecret = dict[@"Secret"];
        _gd.matchPlay.freeTries = [(NSNumber*)dict[@"FreeTries"] intValue];
        _gd.playerInfo.goldCoin = [(NSNumber*)dict[@"GoldCoin"] intValue];
        _gd.gameMode = M_MATCH;
        _gd.autoPaging = [(NSNumber*)dict[@"AutoPaging"] boolValue];
        
        [self loadAndEnterGame];
    }];
}

- (void)loadAndEnterGame {
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
        SldConfig *conf = [SldConfig getInstance];
        for (NSString *imageKey in imageKeys) {
            if (!imageExist(imageKey)) {
                [session downloadFromUrl:makeImageServerUrl2(imageKey, conf.UPLOAD_HOST)
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
    SldGameController *controller = [self.storyboard instantiateViewControllerWithIdentifier:@"game"];
    
    [self.navigationController pushViewController:controller animated:YES];
}

- (IBAction)onSocial:(id)sender {
    SldHttpSession *session = [SldHttpSession defaultSession];
    int msec = 0;
    if (_gd.matchPlay) {
        msec = -_gd.matchPlay.highScore;
    }
    
    UIAlertView* alt = alertNoButton(@"正在生成我的比赛...");
    NSDictionary *body = @{@"PackId":@(_gd.match.packId), @"SliderNum":@(_gd.match.sliderNum), @"Msec":@(msec)};
    [session postToApi:@"social/newPack" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [alt dismissWithClickedButtonIndex:0 animated:YES];
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        NSString *key = [dict objectForKey:@"Key"];
        
        //
        NSString *path = makeImagePath(_gd.match.thumb);
        UIImage *image = [UIImage imageWithContentsOfFile:path];
        NSString *url = [NSString stringWithFormat:@"%@?key=%@", [SldConfig getInstance].HTML5_URL, key];
        
        [[[UIAlertView alloc] initWithTitle:@"邀请朋友一起玩。朋友可以直接点开链接挑战，也可以下载客户端一起玩。"
                                    message:nil
                           cancelButtonItem:[RIButtonItem itemWithLabel:@"好的" action:^{
            NSString *weixinText = [NSString stringWithFormat:@"我自己做的拼图游戏，一起来玩吧。"];
            if (_gd.matchPlay && _gd.matchPlay.highScore != 0) {
                weixinText = [NSString stringWithFormat:@"我只用了%@就完成了比赛，敢来挑战么？", formatScore(_gd.matchPlay.highScore)];
            }
            UMSocialData *umData = [UMSocialData defaultData];
            umData.extConfig.title = @"";
            umData.extConfig.wechatSessionData.url = url;
            umData.extConfig.wechatSessionData.shareText = weixinText;
            NSString *text = [NSString stringWithFormat:@"%@\n%@", weixinText, url];
            [UMSocialSnsService presentSnsIconSheetView:self
                                                 appKey:nil
                                              shareText:text
                                             shareImage:image
                                        shareToSnsNames:@[UMShareToWechatSession,UMShareToWechatTimeline,UMShareToSina,UMShareToTencent, UMShareToDouban, UMShareToQzone]
                                               delegate:self];
        }]
                           otherButtonItems:nil] show];
    }];
    
}

- (IBAction)onReportButton:(id)sender {
    [[[UIAlertView alloc] initWithTitle:@"举报此图集有色情暴力等不和谐内容?"
	                            message:nil
		               cancelButtonItem:[RIButtonItem itemWithLabel:@"取消" action:^{
        // Handle "Cancel"
    }]
				       otherButtonItems:[RIButtonItem itemWithLabel:@"举报！" action:^{
        UIAlertView *alt = alertNoButton(@"举报中...");
        SldHttpSession *session = [SldHttpSession defaultSession];
        NSDictionary *body = @{@"MatchId":@(_gd.match.id)};
        [session postToApi:@"match/report" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [alt dismissWithClickedButtonIndex:0 animated:NO];
            if (error) {
                alertHTTPError(error, data);
                return;
            }
            alert(@"举报完毕", nil);
        }];

    }], nil] show];
}

@end

//====================================
@interface SldMatchEditController : UITableViewController <UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>

@property (weak, nonatomic) IBOutlet UITextField *titleInput;
@property (weak, nonatomic) IBOutlet UITextField *urlInput;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UISwitch *privateSwitch;

@property (nonatomic) UIImage *promoImage;
@property (nonatomic) SldGameData *gd;
@property (nonatomic) BOOL imageChanged;
@property (nonatomic) QNUploadManager *upManager;
@property (nonatomic) UIAlertView *alt;
@property (nonatomic) NSString *imageKey;


@end

@implementation SldMatchEditController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _gd = [SldGameData getInstance];
    _urlInput.delegate = self;
    
    //fill ui
    _titleInput.text = _gd.match.title;
    _urlInput.text = _gd.match.promoUrl;
    [_imageView asyncLoadUploadedImageWithKey:_gd.match.promoImage showIndicator:NO completion:nil];
    _privateSwitch.on = _gd.match.isPrivate;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.view endEditing:YES];
}

- (BOOL)shouldPerformSegueWithIdentifier:(NSString *)identifier sender:(id)sender {
    if (identifier && [identifier compare:@"segToPromoWeb"] == 0) {
        if (_urlInput.text.length == 0) {
            alert(@"请填写展示链接地址后再进行预览。", nil);
            return NO;
        }
    } else if (_urlInput.text.length != 0 && _imageView.image == nil) {
        alert(@"填写了展示链接的情况下必须提供展示图片。", nil);
        return NO;
    }
    return YES;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if (segue.identifier && [segue.identifier compare:@"segToPromoWeb"] == 0) {
        
        NSString *urlStr = _urlInput.text;
        NSRange range = [_urlInput.text rangeOfString:@"://"];
        if (range.location == NSNotFound) {
            urlStr = [NSString stringWithFormat:@"http://%@", urlStr];
        }
        
        SldMatchPromoWebController *vc = segue.destinationViewController;
        vc.url = [NSURL URLWithString:urlStr];
    }
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField
{
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [_urlInput resignFirstResponder];
    return YES;
}

- (IBAction)onTouch:(id)sender {
    [self.view endEditing:YES];
}

- (IBAction)onDeleteImage:(id)sender {
    if (_imageView.image) {
        _imageChanged = YES;
    }
    
    _imageView.image = nil;
    _promoImage = nil;
}

- (IBAction)onSelectImage:(id)sender {
    UIImagePickerController *imagePicker =
    [[UIImagePickerController alloc] init];
    
    imagePicker.delegate = self;
    imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
    imagePicker.mediaTypes = @[(NSString *) kUTTypeImage];
    imagePicker.allowsEditing = YES;
    
    [self presentViewController:imagePicker
                       animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    CGRect rect;
    [(NSValue*)info[UIImagePickerControllerCropRect] getValue:&rect];
    CGSize scaledToSize = CGSizeMake(512, 512);
    if (rect.size.width > rect.size.height) {
        scaledToSize.width = 512 * rect.size.width / rect.size.height;
    } else if (rect.size.width > rect.size.height) {
        scaledToSize.height = 512 * rect.size.height / rect.size.width;
    }
    UIImage *scaledImage = [SldUtil imageWithImage:info[UIImagePickerControllerEditedImage] scaledToSize:scaledToSize];
    
    _imageView.image = scaledImage;
    _promoImage = scaledImage;
    
    _imageChanged = YES;
}

- (IBAction)onModButton:(id)sender {
    NSString *title = _titleInput.text;
    NSString *promoUrl = _urlInput.text;
    if (promoUrl.length > 0 && !_imageView.image) {
        alert(@"填写了展示链接的情况下必须提供展示图片。", nil);
        return;
    }
    
    if ([title compare:_gd.match.title] != 0
        || [promoUrl compare:_gd.match.promoUrl] != 0
        || _imageChanged
        || _gd.match.isPrivate != _privateSwitch.on)
    {
        _alt = alertNoButton(@"更改中");
        
        if (_imageView.image) {
            _imageKey = _gd.match.promoImage;
        }
        
        if (_imageChanged && _imageView.image) {
            NSData *data = UIImageJPEGRepresentation(_imageView.image, 0.85);
            NSString *fileName = @"promo.jpg";
            NSString *filePath = makeTempPath(fileName);
            [data writeToFile:filePath atomically:YES];
            
            _imageKey = [NSString stringWithFormat:@"%@.jpg", [SldUtil sha1WithData:data]];
            
            //
            SldHttpSession *session = [SldHttpSession defaultSession];
            [session postToApi:@"player/getUptoken" body:nil completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
                if (error) {
                    alertHTTPError(error, data);
                    [_alt dismissWithClickedButtonIndex:0 animated:YES];
                    _alt = nil;
                    return;
                }
                
                NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
                if (error) {
                    lwError("Json error:%@", [error localizedDescription]);
                    [_alt dismissWithClickedButtonIndex:0 animated:YES];
                    _alt = nil;
                    return;
                }
                
                NSString *token = [dict objectForKey:@"Token"];
                
                _upManager = [[QNUploadManager alloc] init];
                [_upManager putFile:filePath
                                key:_imageKey
                              token:token
                           complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
                               if (info.ok) {
                                  [self postModMsg];
                               } else {
                                   [_alt dismissWithClickedButtonIndex:0 animated:YES];
                                   _alt = nil;
                                   alert(@"上传失败", nil);
                               }
                           }
                             option:nil];
            }];
        } else {
            [self postModMsg];
        }


    } else {
        alert(@"没有任何变动。", nil);
    }
}

- (void)postModMsg {
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSString *title = _titleInput.text;
    if (title == nil) {
        title = @"";
    }
    NSString *url = _urlInput.text;
    if (url == nil) {
        url = @"";
    }
    if (_imageKey == nil) {
        _imageKey = @"";
    }
    NSDictionary *body = @{
                           @"MatchId":@(_gd.match.id),
                           @"Title":title,
                           @"PromoUrl":url,
                           @"PromoImage":_imageKey,
                           @"Private":@(_privateSwitch.on),
                           };
    [session postToApi:@"match/mod" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [_alt dismissWithClickedButtonIndex:0 animated:NO];
        
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        _gd.match.title = _titleInput.text;
        _gd.match.promoUrl = _urlInput.text;
        _gd.match.promoImage = _imageKey;
        _gd.match.isPrivate = _privateSwitch.on;
        
        [[[UIAlertView alloc] initWithTitle:@"更改成功。"
                                    message:nil
                           cancelButtonItem:[RIButtonItem itemWithLabel:@"好的" action:^{
            [self.navigationController popViewControllerAnimated:YES];
        }]
                           otherButtonItems:nil] show];
    }];
}



@end
