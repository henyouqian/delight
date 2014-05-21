//
//  SldAddCommentController.m
//  Sld
//
//  Created by Wei Li on 14-5-10.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldAddCommentController.h"
#import "SldHttpSession.h"
#import "SldGameData.h"

@interface SldAddCommentController ()

@end

@implementation SldAddCommentController


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [self registerForKeyboardNotifications];
    [_textView becomeFirstResponder];
    
    if (_restoreText) {
        _textView.text = _restoreText;
    }
}

- (IBAction)onSendButton:(id)sender {
    if (_textView.text.length == 0) {
        return;
    }
    RIButtonItem *cancelItem = [RIButtonItem itemWithLabel:@"No" action:nil];
    
	RIButtonItem *sendItem = [RIButtonItem itemWithLabel:@"Yes" action:^{
        SldGameData *gd = [SldGameData getInstance];
        SldHttpSession *session = [SldHttpSession defaultSession];
        NSDictionary *body = @{@"PackId":@(gd.packInfo.id), @"Text": _textView.text};
        UIAlertView *alert = alertNoButton(@"Sending comment ...");
        [session postToApi:@"pack/addComment" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [alert dismissWithClickedButtonIndex:0 animated:YES];
            if (error) {
                alertHTTPError(error, data);
                return;
            }
            
            [_commentController onSendComment];
            [self dismissViewControllerAnimated:YES completion:nil];
        }];
	}];
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"Send this comment?"
	                                                    message:nil
											   cancelButtonItem:cancelItem
											   otherButtonItems:sendItem, nil];
	[alertView show];
}

- (void)registerForKeyboardNotifications
{
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWasShown:)
                                                 name:UIKeyboardDidShowNotification object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillBeHidden:)
                                                 name:UIKeyboardWillHideNotification object:nil];
    
}

// Called when the UIKeyboardDidShowNotification is sent.
- (void)keyboardWasShown:(NSNotification*)aNotification
{
    NSDictionary* info = [aNotification userInfo];
    CGSize kbSize = [[info objectForKey:UIKeyboardFrameBeginUserInfoKey] CGRectValue].size;
    
    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, kbSize.height+40, 0.0);
    _textView.contentInset = contentInsets;
    _textView.scrollIndicatorInsets = contentInsets;
    
    // If active text field is hidden by keyboard, scroll it so it's visible
    // Your app might not need or want this behavior.
//    CGRect aRect = self.view.frame;
//    aRect.size.height -= kbSize.height;
//    if (!CGRectContainsPoint(aRect, activeField.frame.origin) ) {
//        [self.scrollView scrollRectToVisible:activeField.frame animated:YES];
//    }
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    UIEdgeInsets contentInsets = UIEdgeInsetsZero;
    _textView.contentInset = contentInsets;
    _textView.scrollIndicatorInsets = contentInsets;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

@end
