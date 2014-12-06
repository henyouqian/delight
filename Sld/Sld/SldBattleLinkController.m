//
//  SldBattleLinkController.m
//  pin
//
//  Created by 李炜 on 14/11/12.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldBattleLinkController.h"
#import "SldUtil.h"
#import "SldGameData.h"
#import "SldHttpSession.h"
#import "SldConfig.h"
#import "SldBattleScene.h"


@interface SldBattleLinkController ()

@property (weak, nonatomic) IBOutlet UILabel *outputLabel;

@property (weak, nonatomic) IBOutlet UIView *foeView;
@property (weak, nonatomic) IBOutlet UIView *emojiView;
@property (weak, nonatomic) IBOutlet UIImageView *foeThumbView;
@property (weak, nonatomic) IBOutlet UILabel *foeNameLable;
@property (weak, nonatomic) IBOutlet UILabel *foeTeamLabel;
@property (weak, nonatomic) IBOutlet UILabel *foeLvLabel;
@property (nonatomic) SRWebSocket *webSocket;
@property (nonatomic) NSDictionary *procDict;
@property (nonatomic) SldGameData *gd;
//@property (nonatomic) NSDate *date;
@property (nonatomic) NSDate *lastEmojiTime;
@property (nonatomic) FISound *sndPop;
@end

@implementation SldBattleLinkController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _gd = [SldGameData getInstance];
    
    _foeView.hidden = YES;
    _emojiView.hidden = YES;
    
    //socket rocket
    SldConfig* conf = [SldConfig getInstance];
    _webSocket = [[SRWebSocket alloc] initWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:conf.WEB_SOCKET_URL]]];
    _webSocket.delegate = self;
    _gd.webSocket = _webSocket;
    
    [_webSocket open];
    
    _procDict = @{
        @"foeDisconnect":[NSValue valueWithPointer:@selector(onFoeDisconnect:)],
        @"pairing":[NSValue valueWithPointer:@selector(onPairing:)],
        @"paired":[NSValue valueWithPointer:@selector(onPaired:)],
        @"talk":[NSValue valueWithPointer:@selector(onTalk:)],
        @"start":[NSValue valueWithPointer:@selector(onStart:)],
    };
    
    //outputLabel animation
    [UIView animateKeyframesWithDuration:2.0 delay:0.0 options:UIViewKeyframeAnimationOptionAutoreverse | UIViewKeyframeAnimationOptionRepeat | UIViewAnimationOptionCurveEaseInOut animations:^{
        [UIView addKeyframeWithRelativeStartTime:0.0 relativeDuration:0.5 animations:^{
            _outputLabel.alpha = 1.f;
        }];
        [UIView addKeyframeWithRelativeStartTime:0.5 relativeDuration:0.5 animations:^{
            _outputLabel.alpha = 0.5f;
        }];
    } completion:nil];
    
    //
    FISoundEngine *engine = [FISoundEngine sharedEngine];
    _sndPop = [engine soundNamed:@"audio/pop.wav" maxPolyphony:4 error:nil];
    
    _lastEmojiTime = [NSDate dateWithTimeIntervalSinceNow:-100.0];
}

- (void)dealloc {
    _webSocket.delegate = nil;
    [_webSocket close];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onEmoji:) name:NOTIF_EMOJI object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    lwInfo(@"socketRocket open");
    
    NSDictionary *msg = @{@"Token":_gd.token, @"RoomName":_roomName};
    [SldUtil sendWithSocket:_webSocket type:@"authPair" data:msg];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    lwInfo(@"socketRocket error: %@", [error localizedDescription]);
    [[[UIAlertView alloc] initWithTitle:@"连接不成功"
                                message:nil
                       cancelButtonItem:[RIButtonItem itemWithLabel:@"好的" action:^{
        [self.navigationController popToRootViewControllerAnimated:YES];
    }]
                       otherButtonItems:nil] show];
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    [[[UIAlertView alloc] initWithTitle:@"连接已断开"
                                message:nil
                       cancelButtonItem:[RIButtonItem itemWithLabel:@"好的" action:^{
        [self.navigationController popToRootViewControllerAnimated:YES];
    }]
                       otherButtonItems:nil] show];
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    NSError *jsonErr;
    NSData* data = message;
    if ([message isKindOfClass:[NSString class]]) {
        data = [message dataUsingEncoding:NSUTF8StringEncoding];
    }
    
    NSDictionary *msg = [NSJSONSerialization JSONObjectWithData:data options:0 error:&jsonErr];
    if (jsonErr) {
        alert(@"Json error", [jsonErr localizedDescription]);
        return;
    }
    
    NSString *type = [msg objectForKey:@"Type"];
    if ([type compare:@"err"] == 0) {
        [self wsError:[msg objectForKey:@"String"]];
        return;
    }
    NSValue *selVal = [_procDict objectForKey:type];
    if (selVal) {
        SEL aSel = [selVal pointerValue];
        [self performSelector:aSel withObject:msg];
    }
}

- (void)wsError:(NSString *)error {
    if ([error compare:@"err_timeout"] == 0) {
        [self quit:@"服务器无响应，请重新进入"];
    } else {
        NSString *str = [NSString stringWithFormat:@"ws错误：%@", error];
        [self quit:str];
    }
}

- (void)onFoeDisconnect: (NSDictionary*)msg{
    [self quit:@"对手已离开"];
}

- (void)quit:(NSString*)alertMsg{
    [[[UIAlertView alloc] initWithTitle:alertMsg
                                message:nil
                       cancelButtonItem:[RIButtonItem itemWithLabel:@"好的" action:^{
        [self.navigationController popToRootViewControllerAnimated:YES];
    }]
                       otherButtonItems:nil] show];
}

- (void)onPairing: (NSDictionary*)msg{
    lwInfo("onPairing");
    _outputLabel.text = @"配对中...";
}

- (void)onPaired: (NSDictionary*)msg{
    lwInfo("onPaired");
    
    [self.navigationController setNavigationBarHidden:YES];
    
//    _date = [NSDate dateWithTimeIntervalSinceNow:0];
    
    _foeView.hidden = NO;
    _emojiView.hidden = NO;
    
    _foeView.alpha = 0.f;
    _emojiView.alpha = 0.f;
    CGRect foeFrame1 = _foeView.frame;
    CGRect emojiFrame1 = _emojiView.frame;
    CGRect foeFrame2 = _foeView.frame;
    CGRect emojiFrame2 = _emojiView.frame;
    
    foeFrame2.origin.y -= 40;
    emojiFrame2.origin.y += 40;
    _foeView.frame = foeFrame2;
    _emojiView.frame = emojiFrame2;
    
    [UIView animateWithDuration:0.6 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            _foeView.alpha = 1.f;
            _emojiView.alpha = 1.f;
        
            _foeView.frame = foeFrame1;
            _emojiView.frame = emojiFrame1;
        } completion:nil];
    
    //
    _gd.packInfo = [PackInfo packWithDictionary:[msg objectForKey:@"Pack"]];
    _gd.sliderNum = [[msg objectForKey:@"SliderNum"] intValue];
    _outputLabel.text = @"配对成功";
    _gd.matchSecret = [msg objectForKey:@"Secret"];
    _gd.playerInfo.BattleHeartZeroTime = [(NSNumber*)[msg objectForKey:@"HeartZeroTime"] longLongValue];
    
    //foe player
    NSDictionary *foePlayer = [msg objectForKey:@"FoePlayer"];
    
    //update ui
    _foeNameLable.text = [foePlayer objectForKey:@"NickName"];
    _foeTeamLabel.text = [foePlayer objectForKey:@"TeamName"];
    [SldUtil loadAvatar:_foeThumbView gravatarKey:foePlayer[@"GravatarKey"] customAvatarKey:foePlayer[@"CustomAvatarKey"]];
    int battlePoint = [(NSNumber*)[foePlayer objectForKey:@"BattlePoint"] intValue];
    _foeLvLabel.text = [_gd getPlayerBattleLevelTitleWithPoint:battlePoint];
    
    NSArray *imageKeys = _gd.packInfo.images;
    __block int localNum = 0;
    NSUInteger totalNum = [imageKeys count];
    if (totalNum == 0) {
        alert(@"no image", nil);
        return;
    }
    for (NSString *imageKey in imageKeys) {
        if (imageExist(imageKey)) {
            localNum++;
        }
    }
    
    if (localNum == totalNum) {
        lwInfo("already downloaded");
        [self ready];
        return;
    } else if (localNum < totalNum) {
        NSString *msg = [NSString stringWithFormat:@"图集下载中...%d%%", (int)(100.f*(float)localNum/(float)totalNum)];
        
        _outputLabel.text = msg;
        
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
                     }
                     localNum++;
                     
                     NSString *msg = [NSString stringWithFormat:@"图集下载中...%d%%", (int)(100.f*(float)localNum/(float)totalNum)];
                     _outputLabel.text = msg;
                     
                     //download complete
                     if (localNum == totalNum) {
                         lwInfo("downloaded");
                         [self ready];
                     }
                 }];
            }
        }
    }
}

- (void)ready {
    _outputLabel.text = @"对手准备中，请稍候";
    [SldUtil sendWithSocket:_webSocket type:@"ready" data:nil];
}

- (void)enterGame {
    int rd = arc4random() % _gd.packInfo.images.count;
    NSString *imgKey = _gd.packInfo.images[rd];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        SldSprite *sprite = [SldSprite spriteWithPath:makeImagePath(imgKey) index:0];
        dispatch_async(dispatch_get_main_queue(), ^{
            _gd.autoPaging = YES;
            SldBattleSceneController *controller = [self.storyboard instantiateViewControllerWithIdentifier:@"battleScene"];
            controller.firstSprite = sprite;
            controller.firstIndex = rd;
            [self.navigationController pushViewController:controller animated:YES];
        });
    });
}

- (void)onTalk: (NSDictionary*)msg{
    NSString *text = msg[@"Text"];
    
    float x = _foeView.frame.size.width - arc4random() % 10 - 50;
    static float lastY = 9999;
    float y;
    do {
        y = arc4random() % ((int)_foeView.frame.size.height-20) + 10;
    } while (ABS(y-lastY) < 40.0);
    lastY = y;
    
    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(x, y, 50, 50)];
    lbl.text = text;
    
    [_foeView addSubview:lbl];
    
    lbl.font = [lbl.font fontWithSize:36];
    lbl.alpha = 1.4;
    [UIView animateWithDuration:1.5 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        lbl.alpha = 0;
        CGRect rect = lbl.frame;
        rect.origin.x -= 100;
        lbl.frame = rect;
    } completion:^(BOOL finished) {
        [lbl removeFromSuperview];
    }];
    
    [_sndPop play];
}

- (void)onStart: (NSDictionary*)msg{
    [self enterGame];
}

- (void)onEmoji:(NSNotification*)notif {
    NSString *text = notif.object;
    NSDate *now = [NSDate dateWithTimeIntervalSinceNow:0];
    if ([now timeIntervalSinceDate:_lastEmojiTime] > 0.15) {
        NSDictionary *msg = @{@"Text":text};
        [SldUtil sendWithSocket:_webSocket type:@"talk" data:msg];
    }else {
        lwInfo("too fast");
    }
    _lastEmojiTime = now;


    float x = arc4random() % 10 + 10;
    static float lastY = 9999;
    float y;
    do {
        y = arc4random() % ((int)_foeView.frame.size.height-20) + 10;
    } while (ABS(y-lastY) < 40.0);
    lastY = y;

    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(x, y, 50, 50)];
    lbl.text = text;

    [_foeView addSubview:lbl];

    lbl.font = [lbl.font fontWithSize:36];
    lbl.alpha = 1.4;
    [UIView animateWithDuration:1.5 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        lbl.alpha = 0;
        CGRect rect = lbl.frame;
        rect.origin.x += 100;
        lbl.frame = rect;
    } completion:^(BOOL finished) {
        [lbl removeFromSuperview];
    }];
    
    [_sndPop play];
}

//- (IBAction)onEmojiButton:(id)sender {
//    UIButton *btn = sender;
//    
//    NSDate *now = [NSDate dateWithTimeIntervalSinceNow:0];
//    if ([now timeIntervalSinceDate:_lastEmojiTime] > 0.15) {
//        NSDictionary *msg = @{@"Text":btn.titleLabel.text};
//        [SldUtil sendWithSocket:_webSocket type:@"talk" data:msg];
//    }else {
//        lwInfo("too fast");
//    }
//    _lastEmojiTime = now;
//    
//    
//    float x = arc4random() % 10 + 10;
//    static float lastY = 9999;
//    float y;
//    do {
//        y = arc4random() % ((int)_foeView.frame.size.height-20) + 10;
//    } while (ABS(y-lastY) < 20.0);
//    lastY = y;
//    
//    UILabel *lbl = [[UILabel alloc] initWithFrame:CGRectMake(x, y, 50, 50)];
//    lbl.text = btn.titleLabel.text;
//
//    [_foeView addSubview:lbl];
//    
//    lbl.font = [lbl.font fontWithSize:36];
//    lbl.alpha = 1.4;
//    [UIView animateWithDuration:1.5 delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
//        lbl.alpha = 0;
//        CGRect rect = lbl.frame;
//        rect.origin.x += 100;
//        lbl.frame = rect;
//    } completion:^(BOOL finished) {
//        [lbl removeFromSuperview];
//    }];
//    
//    [_sndPop play];
//}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
