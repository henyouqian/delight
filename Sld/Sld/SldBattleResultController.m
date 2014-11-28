//
//  SldBattleResultController.m
//  pin
//
//  Created by 李炜 on 14/11/25.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldBattleResultController.h"
#import "SldGameData.h"
#import "SldUtil.h"
#import "SldEmojiController.h"

@interface SldBattleResultController ()
@property (weak, nonatomic) IBOutlet UIView *foeView;
@property (weak, nonatomic) IBOutlet UIView *emojiView;
@property (weak, nonatomic) IBOutlet UILabel *resultLabel;
@property (weak, nonatomic) IBOutlet UILabel *scoreLabel;
@property (weak, nonatomic) IBOutlet UILabel *rewardCoinLabel;

@property (nonatomic) SldGameData *gd;
@property (nonatomic) NSDictionary *procDict;
@property (nonatomic) NSDate *lastEmojiTime;
@property (nonatomic) FISound *sndPop;
@property (nonatomic) FISound *sndCollectCoin;
@end

@implementation SldBattleResultController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _gd = [SldGameData getInstance];
    
    //web socket
    _gd.webSocket.delegate = self;
    
    _procDict = @{
                  @"foeDisconnect":[NSValue valueWithPointer:@selector(onFoeDisconnect:)],
                  @"talk":[NSValue valueWithPointer:@selector(onTalk:)],
                  };
    
    _lastEmojiTime = [NSDate dateWithTimeIntervalSinceNow:-100.0];
    
    FISoundEngine *engine = [FISoundEngine sharedEngine];
    _sndPop = [engine soundNamed:@"audio/pop.wav" maxPolyphony:4 error:nil];
    
    _sndCollectCoin = [engine soundNamed:@"audio/collectCoin.wav" maxPolyphony:1 error:nil];
    
    //navi
    [self.navigationController setNavigationBarHidden:NO animated:YES];
    
    self.navigationItem.hidesBackButton = YES;
    
    UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithTitle:@"退出" style:UIBarButtonItemStylePlain target:self action:@selector(onQuit)];
    self.navigationItem.leftBarButtonItem = backItem;
    
    self.title = @"比赛结果";
    
    //animation
    _foeView.hidden = NO;
    _emojiView.hidden = NO;
    
    _foeView.alpha = 0.f;
    _emojiView.alpha = 0.f;
    CGRect foeFrame1 = _foeView.frame;
    CGRect emojiFrame1 = _emojiView.frame;
//    CGRect foeFrame2 = _foeView.frame;
    CGRect emojiFrame2 = _emojiView.frame;
    
    _foeView.frame = foeFrame1;
//    foeFrame2.origin.y -= 40;
//    _foeView.frame = foeFrame2;
    
    emojiFrame2.origin.y += 40;
    _emojiView.frame = emojiFrame2;
    
    [UIView animateWithDuration:0.6 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        _foeView.alpha = 1.f;
        _emojiView.alpha = 1.f;
        
        _emojiView.frame = emojiFrame1;
    } completion:nil];
    
    //resultLabel
    _resultLabel.text = @"???";
    NSString *result = _resultDict[@"Result"];
    if ([result compare:@"win"] == 0) {
        _resultLabel.text = @"赢了";
        
        CGRect frame1 = _rewardCoinLabel.frame;
        CGRect frame0 = _rewardCoinLabel.frame;
        frame0.origin.y -= 30;
        _rewardCoinLabel.frame = frame0;
        _rewardCoinLabel.alpha = 0;
        [UIView animateWithDuration:0.4 delay:1.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            _rewardCoinLabel.alpha = 1.f;
            _rewardCoinLabel.frame = frame1;
        } completion:^(BOOL finished){
            [_sndCollectCoin play];
        }];

    } else if ([result compare:@"lose"] == 0) {
        _resultLabel.text = @"输了";
    } else if ([result compare:@"draw"] == 0) {
        _resultLabel.text = @"平了";
    }
    
    //scoreLabel
    int myMsec = [(NSNumber*)_resultDict[@"MyMsec"] intValue];
    int foeMsec = [(NSNumber*)_resultDict[@"FoeMsec"] intValue];
    
    NSString *myStr = @"  未完成  ";
    if (myMsec > 0) {
        myStr = formatScore(-myMsec);
    }
    
    NSString *foeStr = @"  未完成  ";
    if (foeMsec > 0) {
        foeStr = formatScore(-foeMsec);
    }
    
    _scoreLabel.text = [NSString stringWithFormat:@"%@   vs   %@", myStr, foeStr];
    
    //rewardCoinLabel
    int rewardCoin = [(NSNumber*)_resultDict[@"RewardCoin"] intValue];
    if (rewardCoin > 0) {
        _rewardCoinLabel.text = [NSString stringWithFormat:@"获得%d金币", rewardCoin];
    } else if (rewardCoin < 0){
        _rewardCoinLabel.text = [NSString stringWithFormat:@"输了%d金币", -rewardCoin];
    }
    
    lwInfo(@"%@", _resultDict);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onEmoji:) name:NOTIF_EMOJI object:nil];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self];
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
        alert(@"ws error", [msg objectForKey:@"String"]);
        return;
    }
    NSValue *selVal = [_procDict objectForKey:type];
    if (selVal) {
        SEL aSel = [selVal pointerValue];
        [self performSelector:aSel withObject:msg];
    }
}

- (void)onQuit {
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (void)onFoeDisconnect: (NSDictionary*)msg{
    
}

- (void)onTalk: (NSDictionary*)msg{
    NSString *text = msg[@"Text"];
    
    float x = _foeView.frame.size.width - arc4random() % 10 - 50;
    static float lastY = 9999;
    float y;
    do {
        y = arc4random() % ((int)_foeView.frame.size.height-60) + 10;
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

- (void)onEmoji:(NSNotification*)notif {
    NSString *text = notif.object;
    NSDate *now = [NSDate dateWithTimeIntervalSinceNow:0];
    if ([now timeIntervalSinceDate:_lastEmojiTime] > 0.15) {
        NSDictionary *msg = @{@"Text":text};
        [SldUtil sendWithSocket:_gd.webSocket type:@"talk" data:msg];
    }else {
        lwInfo("too fast");
    }
    _lastEmojiTime = now;
    
    
    float x = arc4random() % 10 + 10;
    static float lastY = 9999;
    float y;
    do {
        y = arc4random() % ((int)_foeView.frame.size.height-60) + 10;
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

@end
