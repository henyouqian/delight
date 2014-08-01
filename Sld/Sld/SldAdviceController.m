//
//  SldAdviceController.m
//  Sld
//
//  Created by Wei Li on 14-5-9.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldAdviceController.h"
#import "SldNevigationController.h"
#import "SldHttpSession.h"
#import "SldGameData.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldUtil.h"

//AdviceCell
@interface AdviceCell : UITableViewCell
@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UIImageView *iconView;
@property (weak, nonatomic) IBOutlet UILabel *userNameLabel;
@end

@implementation AdviceCell

@end


//AdviceData
@interface AdviceData : NSObject
@property (nonatomic) UInt64 id;
@property (nonatomic) UInt64 userId;
@property (nonatomic) NSString *userName;
@property (nonatomic) NSString *gravatarKey;
@property (nonatomic) NSString *customAvatarKey;
@property (nonatomic) NSString *team;
@property (nonatomic) NSString *text;
@end

@implementation AdviceData
+ (instancetype)adviceDataWithDictionary:(NSDictionary*)dict {
    AdviceData *data = [[AdviceData alloc] init];
    NSNumber *nId = [dict objectForKey:@"Id"];
    if (nId) {
        data.id = [nId unsignedLongLongValue];
    }
    NSNumber *nUserId = [dict objectForKey:@"UserId"];
    if (nUserId) {
        data.userId = [nUserId unsignedLongLongValue];
    }
    data.userName = [dict objectForKey:@"UserName"];
    data.gravatarKey = [dict objectForKey:@"GravatarKey"];
    data.customAvatarKey = [dict objectForKey:@"CustomAvatarKey"];
    data.team = [dict objectForKey:@"Team"];
    data.text = [dict objectForKey:@"Text"];

    return data;
}
@end


//=================================
//SldAdviceController
@interface SldAdviceController ()
@property (nonatomic) NSMutableArray *adviceDatas;
@property (weak, nonatomic) SldGameData *gameData;
@property (nonatomic) NSString *adviceText;
@property (nonatomic) SldBottomRefreshControl *bottomRefresh;
@property (nonatomic) BOOL underBottom;
@end

@implementation SldAdviceController

- (void)dealloc {
    
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _gameData = [SldGameData getInstance];
    
    //set tableView inset
//    int navBottomY = [SldNevigationController getBottomY];
//    self.tableView.contentInset = UIEdgeInsetsMake(navBottomY, 0, 100, 0);
//    self.tableView.scrollIndicatorInsets = UIEdgeInsetsMake(navBottomY, 0, 100, 0);
    
    
    //refreshControl
    UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
    [refreshControl addTarget:self action:@selector(update) forControlEvents:UIControlEventValueChanged];
    refreshControl.tintColor = [UIColor grayColor];
    self.refreshControl = refreshControl;
    
    //bottomRefresh
    _bottomRefresh = [[SldBottomRefreshControl alloc] init];
    self.tableView.tableFooterView = _bottomRefresh;
    
    //
    if (_adviceDatas == nil) {
        [self update];
    }
}

- (void)update {
    SldGameData *gameData = [SldGameData getInstance];
    NSDictionary *body = @{@"PackId":@(gameData.packInfo.id), @"Key": @0, @"Limit": @20};
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"pack/getComments" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [self.refreshControl endRefreshing];
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        _adviceDatas = [NSMutableArray arrayWithCapacity:[array count]];
        for (NSDictionary *dict in array) {
            AdviceData *adviceData = [AdviceData adviceDataWithDictionary:dict];
            [_adviceDatas addObject:adviceData];
        }
        [self.tableView reloadData];
    }];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        return 1;
    } else if (section == 1) {
//        return [_adviceDatas count];
        return 10;
    }
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"adviceHeaderCell" forIndexPath:indexPath];
        return cell;
    } else if (indexPath.section == 1) {
        AdviceCell *cell = [tableView dequeueReusableCellWithIdentifier:@"adviceCell" forIndexPath:indexPath];
//        cell.textView.scrollsToTop = NO;
        
        //        AdviceData* AdviceData = [_adviceDatas objectAtIndex:indexPath.row];
        //        cell.textView.text = AdviceData.text;
        //        cell.userNameLabel.text = AdviceData.userName;
        //
        //
        //        [SldUtil loadAvatar:cell.iconView gravatarKey:AdviceData.gravatarKey customAvatarKey:AdviceData.customAvatarKey];
        //
        //        cell.backgroundColor = [UIColor clearColor];
        return cell;
    }
    return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        return 70;
    } else if (indexPath.section == 1) {
//        AdviceData* AdviceData = [_adviceDatas objectAtIndex:indexPath.row];
//        float h = [self textHeightForText:AdviceData.text width:250 fontName:@"HelveticaNeue" fontSize:14];
//        return MAX(h+22+10, 68);
        return 60;
    }
    return 0;
}

- (float)textHeightForText:(NSString*)text width:(float)width fontName:(NSString*)fontName fontSize:(float)fontSize {
    UIFont *font = nil;
    if (fontName == nil) {
        font = [UIFont systemFontOfSize:fontSize];
    } else {
        font = [UIFont fontWithName:fontName size:fontSize];
    }
    NSDictionary *attributes = [NSDictionary dictionaryWithObject:font forKey:NSFontAttributeName];
    NSAttributedString *string = [[NSAttributedString alloc] initWithString:text attributes:attributes];
    return [self textViewHeightForAttributedText:string andWidth:width];
}

- (CGFloat)textViewHeightForAttributedText: (NSAttributedString*)text andWidth: (CGFloat)width {
    UITextView *calculationView = [[UITextView alloc] init];
    [calculationView setAttributedText:text];
    CGSize size = [calculationView sizeThatFits:CGSizeMake(width, FLT_MAX)];
    return size.height;
}


- (void)onSendAdvice {
    _adviceText = nil;
    [self update];
}

- (IBAction)cancelAdvice:(UIStoryboardSegue *)segue {
    SldAddAdviceController* vc = (SldAddAdviceController*)segue.sourceViewController;
    _adviceText = vc.textView.text;
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender
{
    if ([segue.identifier compare:@"addAdviceSeg"] == 0) {
        SldAddAdviceController* vc = (SldAddAdviceController*)segue.destinationViewController;
        vc.restoreText = _adviceText;
        vc.adviceController = self;
    }
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
//    if (_adviceDatas.count == 0) {
//        return;
//    }
    
    if ((scrollView.contentOffset.y + scrollView.frame.size.height) > scrollView.contentSize.height) {
        if (!_underBottom) {
            _underBottom = YES;
            if (!_bottomRefresh.refreshing) {
                [_bottomRefresh beginRefreshing];
                
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                    [_bottomRefresh endRefreshing];
                });
            }
        }
        
    } else {
        _underBottom = NO;
    }
}

@end

//==================================
@interface SldAddAdviceController ()

@end

@implementation SldAddAdviceController


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
    RIButtonItem *cancelItem = [RIButtonItem itemWithLabel:@"取消" action:nil];
    
	RIButtonItem *sendItem = [RIButtonItem itemWithLabel:@"发送" action:^{
        SldHttpSession *session = [SldHttpSession defaultSession];
        NSDictionary *body = @{@"Text": _textView.text};
        UIAlertView *alert = alertNoButton(@"发送中...");
        [session postToApi:@"etc/addAdvice" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            [alert dismissWithClickedButtonIndex:0 animated:YES];
            if (error) {
                alertHTTPError(error, data);
                return;
            }
            
            [_adviceController onSendAdvice];
            [self dismissViewControllerAnimated:YES completion:nil];
        }];
	}];
    
    UIAlertView *alertView = [[UIAlertView alloc] initWithTitle:@"确定发送?"
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
    
    UIEdgeInsets contentInsets = _textView.contentInset;
    contentInsets.bottom = kbSize.height+40;
    _textView.contentInset = contentInsets;
    _textView.scrollIndicatorInsets = contentInsets;
}

// Called when the UIKeyboardWillHideNotification is sent
- (void)keyboardWillBeHidden:(NSNotification*)aNotification
{
    UIEdgeInsets contentInsets = _textView.contentInset;
    contentInsets.bottom = 0;
    _textView.contentInset = contentInsets;
    _textView.scrollIndicatorInsets = contentInsets;
}

- (NSUInteger)supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskPortrait;
}

@end

//============================
@interface SldBottomRefreshControl()
@end

@implementation SldBottomRefreshControl
- (instancetype)init {
    if (self = [super initWithFrame:CGRectMake(0, 0, 320, 44)]) {
        _spin = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
        CGRect frame = _spin.frame;
        frame.origin.x = 150;
        frame.origin.y = 12;
        _spin.frame = frame;
        [self addSubview:_spin];
        _spin.hidden = YES;
        [_spin stopAnimating];
        _refreshing = NO;
    }
    return self;
}

- (void)beginRefreshing {
    _spin.hidden = NO;
    [_spin startAnimating];
    _refreshing = YES;
}

- (void)endRefreshing {
    _spin.hidden = YES;
    [_spin stopAnimating];
    _refreshing = NO;
}
@end


