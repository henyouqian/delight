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

@property (weak, nonatomic) IBOutlet UITextView *outputTextView;
@property (nonatomic) SRWebSocket *webSocket;
@property (nonatomic) NSDictionary *procDict;
@property (nonatomic) SldGameData *gd;
@end

@implementation SldBattleLinkController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _gd = [SldGameData getInstance];
    
    //socket rocket
    _webSocket = [[SRWebSocket alloc] initWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"ws://192.168.2.55:9977/ws"]]];
    _webSocket.delegate = self;
    
    [_webSocket open];
    
    _procDict = @{
        @"pairing":[NSValue valueWithPointer:@selector(onPairing:)],
        @"paired":[NSValue valueWithPointer:@selector(onPaired:)],
    };
}

- (void)dealloc {
    _webSocket.delegate = nil;
    [_webSocket close];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that  can be recreated.
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    lwInfo(@"socketRocket open");
    
    NSDictionary *msg = @{@"Token":_gd.token};
    [SldUtil sendWithSocket:_webSocket type:@"authPair" data:msg];
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    lwInfo(@"socketRocket error: %@", [error localizedDescription]);
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    lwInfo(@"socketRocket close");
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
    NSValue *selVal = [_procDict objectForKey:type];
    if (selVal) {
        SEL aSel = [selVal pointerValue];
        [self performSelector:aSel withObject:msg];
    }
}

- (void)onPairing: (NSDictionary*)msg{
    lwInfo("onPairing");
    _outputTextView.text = @"Pairing...";
}

- (void)onPaired: (NSDictionary*)msg{
    lwInfo("onPaired");
    
    _gd.packInfo = [PackInfo packWithDictionary:[msg objectForKey:@"Pack"]];
    _gd.sliderNum = [[msg objectForKey:@"SliderNum"] intValue];
    _outputTextView.text = [NSString stringWithFormat:@"Paird:%@", _gd.packInfo];
    
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
                         lwInfo("downloaded");
                         [self enterGame];
                     }
                 }];
            }
        }
    }
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

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
