//
//  SldUserInfoController.m
//  Sld
//
//  Created by Wei Li on 14-5-13.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldUserInfoController.h"
#import "MMPickerView.h"
#import "SldLoginViewController.h"
#import "util.h"
#import "SldHttpSession.h"
#import "SldGameData.h"
#import "UIImageView+sldAsyncLoad.h"

@interface SldUserInfoController ()
@property (weak, nonatomic) IBOutlet UITextField *nameInput;
@property (weak, nonatomic) IBOutlet UITextField *genderInput;
@property (weak, nonatomic) IBOutlet UITextField *teamInput;
@property (weak, nonatomic) IBOutlet UIImageView *avatarImageView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *cancelButton;
@property (nonatomic) NSString *gravatarKey;
@end

@implementation SldUserInfoController

+ (void)createAndPresentFromController:(UIViewController*)srcController cancelable:(BOOL)cancelable {
    UINavigationController* navVc = (UINavigationController*)[getStoryboard() instantiateViewControllerWithIdentifier:@"playerSetting"];
    
    SldUserInfoController* userInfoVc = (SldUserInfoController*)(navVc.topViewController);
    
    if (srcController.navigationController) {
        srcController = srcController.navigationController;
    }
    [srcController presentViewController:navVc animated:YES completion:nil];
    userInfoVc.cancelButton.enabled = cancelable;
}

//- (id)initWithStyle:(UITableViewStyle)style
//{
//    self = [super initWithStyle:style];
//    if (self) {
//        // Custom initialization
//    }
//    return self;
//}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    _nameInput.delegate = self;
    
    SldGameData *gamedata = [SldGameData getInstance];
    
    _nameInput.text = gamedata.nickName;
    _genderInput.text = gamedata.gender;
    _teamInput.text = gamedata.teamName;
    _gravatarKey = gamedata.gravatarKey;
    
    NSString *url = [SldUtil makeGravatarUrlWithKey:_gravatarKey width:_avatarImageView.frame.size.width];
    [_avatarImageView asyncLoadImageWithUrl:url showIndicator:NO completion:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onGenderButton:(id)sender {
    [self.view endEditing:YES];
    NSArray *strings = @[@"女", @"男", @"其他", @"保密"];
    
    NSString *genderText = _genderInput.text;
    if (genderText == nil) {
        genderText = @"";
    }
    NSDictionary *options = @{MMselectedObject:genderText, MMcaption:@"性别"};
    
    [MMPickerView showPickerViewInView:self.navigationController.view
                           withStrings:strings
                           withOptions:options
                            completion:^(NSString *selectedString) {
                                _genderInput.text = selectedString;
                            }];
}

- (IBAction)onTeamButton:(id)sender {
    [self.view endEditing:YES];
    NSArray *strings = @[@"安徽",@"澳门",@"北京",@"重庆",@"福建",@"甘肃",@"广东",@"广西族",@"贵州",@"海南",@"河北",@"黑龙江",@"河南",@"湖北",@"湖南",@"江苏",@"江西",@"吉林",@"辽宁",@"内蒙古",@"宁夏",@"青海",@"陕西",@"山东",@"上海",@"山西",@"四川",@"台湾",@"天津",@"香港",@"新疆",@"西藏",@"云南",@"浙江"];
    
    NSString *teamText = _genderInput.text;
    if (teamText == nil) {
        teamText = @"";
    }
    NSDictionary *options = @{MMselectedObject:teamText, MMcaption:@"队伍"};
    
    [MMPickerView showPickerViewInView:self.navigationController.view
                           withStrings:strings
                           withOptions:options
                            completion:^(NSString *selectedString) {
                                _teamInput.text = selectedString;
                            }];
}

- (IBAction)onAvatarButton:(id)sender {
    [self.view endEditing:YES];
    SldAvatarSelectController* vc = (SldAvatarSelectController*)[getStoryboard() instantiateViewControllerWithIdentifier:@"avatarSelect"];
    
    [self.navigationController.view addSubview:vc.view];
    [self.navigationController addChildViewController:vc];
    [vc viewWillAppear:YES];
    vc.userInfoController = self;
}

- (IBAction)onSave:(id)sender {
    if (_nameInput.text.length == 0 || _genderInput.text.length == 0 || _teamInput.text.length == 0) {
        alert(@"请填写所有信息.", nil);
        return;
    }
    
    if (_gravatarKey.length == 0) {
        alert(@"请选择头像.", nil);
        return;
    }
    
    UIAlertView *alt = alert(@"Saving...", nil);
    
    NSDictionary *body = @{@"NickName":_nameInput.text, @"TeamName":_teamInput.text, @"Gender":_genderInput.text, @"GravatarKey":_gravatarKey};
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"player/setInfo" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [alt dismissWithClickedButtonIndex:0 animated:YES];
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        
        SldGameData *gamedata = [SldGameData getInstance];
        
        //succeed
        [self dismissViewControllerAnimated:YES completion:nil];
        if (self.presentingViewController.class == SldLoginViewController.class) {
            SldLoginViewController *vc = (SldLoginViewController *)self.presentingViewController;
            vc.shouldDismiss = YES;
            gamedata.online = YES;
        }
        
        //update game data
        gamedata.nickName = _nameInput.text;
        gamedata.gender = _genderInput.text;
        gamedata.teamName = _teamInput.text;
        gamedata.gravatarKey = _gravatarKey;
        
        [self.presentingViewController viewWillAppear:YES];
    }];
}

- (IBAction)onCancel:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
    
}

- (void)setGravartarWithKey:(NSString*)key url:(NSString*)url {
    _gravatarKey = key;
    [_avatarImageView asyncLoadImageWithUrl:url showIndicator:NO completion:nil];
}

-(BOOL)textFieldShouldReturn:(UITextField*)textField;{
    if (textField == _nameInput) {
        [self onGenderButton:nil];
    }
    return NO;
}


#pragma mark - Table view data source

//- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
//{
//
//    return 1;
//}
//
//- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
//{
//
//    return 2;
//}

/*
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:<#@"reuseIdentifier"#> forIndexPath:indexPath];
    
    // Configure the cell...
    
    return cell;
}
*/

/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/

/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source
        [tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationFade];
    } else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
    }   
}
*/

/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath
{
}
*/

/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/

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

@interface SldAvatarSelectCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@property (weak, nonatomic) IBOutlet UIView *highlightView;

@end

@implementation SldAvatarSelectCell

@end


@interface SldAvatarSelectController()
@property (weak, nonatomic) IBOutlet UIView *groupView;
@property (weak, nonatomic) IBOutlet UICollectionView *collectionView;
@end

static UInt32 _idStart = 0;

@implementation SldAvatarSelectController
- (void)viewDidLoad {
    _collectionView.delegate = self;
    _collectionView.dataSource = self;
    
    if (_idStart == 0) {
        _idStart = arc4random() % UINT32_MAX;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    CGRect frame = _groupView.frame;
    float toY = frame.origin.y;
    frame.origin.y = self.view.frame.size.height;
    _groupView.frame = frame;
    UIColor *originColor = self.view.backgroundColor;
    self.view.backgroundColor = [UIColor clearColor];
    
    [UIView animateWithDuration:.3f delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        CGRect newFrame = frame;
        newFrame.origin.y = toY;
        _groupView.frame = newFrame;
        self.view.backgroundColor = originColor;
    } completion:nil];
}

- (IBAction)onChangeAvatarSet:(id)sender {
    [[SldHttpSession defaultSession] cancelAllTask];
    _idStart = arc4random() % UINT32_MAX;
    [self deselectAll];
    [_collectionView reloadData];
}

- (IBAction)onDone:(id)sender {
    [UIView animateWithDuration:.3f delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        CGRect frame = _groupView.frame;
        frame.origin.y = self.view.frame.size.height;
        _groupView.frame = frame;
        self.view.backgroundColor = [UIColor clearColor];
    } completion:^(BOOL finished) {
        [self.view removeFromSuperview];
        [self removeFromParentViewController];
    }];
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return 12;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    SldAvatarSelectCell *cell = (SldAvatarSelectCell*)[collectionView dequeueReusableCellWithReuseIdentifier:@"selectGravatarCell" forIndexPath:indexPath];
    
    cell.imageView.image = nil;
    NSString *key = [NSString stringWithFormat:@"%lu", _idStart+ indexPath.row];
    NSString *url = [SldUtil makeGravatarUrlWithKey:key width:64];
    [cell.imageView asyncLoadImageWithUrl:url showIndicator:YES completion:nil];
    
    return cell;
}

- (BOOL)collectionView:(UICollectionView *)collectionView shouldHighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    SldAvatarSelectCell *cell = (SldAvatarSelectCell*)[collectionView cellForItemAtIndexPath:indexPath];
    if (cell.selected) {
        cell.highlightView.hidden = YES;
        return NO;
    } else {
        [self deselectAll];
        cell.highlightView.hidden = NO;
        NSString *key = [NSString stringWithFormat:@"%lu", _idStart+ indexPath.row];
        NSString *url = [SldUtil makeGravatarUrlWithKey:key width:64];
        [_userInfoController setGravartarWithKey:key url:url];
        return YES;
    }
}

- (void) deselectAll {
    for (NSIndexPath *ip in [self.collectionView indexPathsForSelectedItems]) {
        SldAvatarSelectCell *cell = (SldAvatarSelectCell*)[self.collectionView cellForItemAtIndexPath:ip];
        cell.highlightView.hidden = YES;
        cell.selected = NO;
    }
}

@end














