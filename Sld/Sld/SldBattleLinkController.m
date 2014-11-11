//
//  SldBattleLinkController.m
//  pin
//
//  Created by 李炜 on 14/11/12.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldBattleLinkController.h"


@interface SldBattleLinkController ()

@property (weak, nonatomic) IBOutlet UITextView *outputTextView;
@property (nonatomic) SRWebSocket *webSocket;
@end

@implementation SldBattleLinkController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    //socket rocket
    _webSocket = [[SRWebSocket alloc] initWithURLRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"ws://192.168.2.55:9977/ws"]]];
    _webSocket.delegate = self;
    
    [_webSocket open];
}

- (void)dealloc {
    _webSocket.delegate = nil;
    [_webSocket close];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)webSocketDidOpen:(SRWebSocket *)webSocket {
    lwInfo(@"socketRocket open");
}

- (void)webSocket:(SRWebSocket *)webSocket didFailWithError:(NSError *)error {
    lwInfo(@"socketRocket error: %@", [error localizedDescription]);
}

- (void)webSocket:(SRWebSocket *)webSocket didCloseWithCode:(NSInteger)code reason:(NSString *)reason wasClean:(BOOL)wasClean {
    lwInfo(@"socketRocket close");
}

- (void)webSocket:(SRWebSocket *)webSocket didReceiveMessage:(id)message {
    lwInfo(@"socketRocket msg: %@", message);
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
