//
//  SldUserInfoController.m
//  Sld
//
//  Created by Wei Li on 14-5-13.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldUserInfoController.h"
#import "SldUserController.h"
#import "MMPickerView.h"
#import "SldLoginViewController.h"
#import "SldUtil.h"
#import "SldHttpSession.h"
#import "SldGameData.h"
#import "SldUserController.h"
#import "UIImageView+sldAsyncLoad.h"
#import "NSData+Base64.h"

@interface SldUserInfoController ()
@property (weak, nonatomic) IBOutlet UITextField *nameInput;
@property (weak, nonatomic) IBOutlet UITextField *genderInput;
@property (weak, nonatomic) IBOutlet UITextField *teamInput;
@property (weak, nonatomic) IBOutlet UIImageView *avatarImageView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *cancelButton;
@property (nonatomic) NSString *gravatarKey;
@property (nonatomic) NSString *customAvatarKey;
@property (nonatomic) UIAlertView *avatarUploadAlt;
@property (nonatomic) SldGameData *gd;
@property (nonatomic) BOOL needUploadCustomAvatar;
@end

static NSArray *_genderStrings;

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
    
    _gd = [SldGameData getInstance];
    PlayerInfo *playerInfo = _gd.playerInfo;
    
    _nameInput.delegate = self;
    
    _genderStrings = @[@"女", @"男", @"保密"];
    
    _nameInput.text = playerInfo.nickName;
    _genderInput.text = [_genderStrings objectAtIndex:playerInfo.gender];
    _teamInput.text = playerInfo.teamName;
    _gravatarKey = playerInfo.gravatarKey;
    if (!_gravatarKey) {
        _gravatarKey = @"";
    }
    _customAvatarKey = playerInfo.customAvatarKey;
    if (!_customAvatarKey) {
        _customAvatarKey = @"";
    }
    
    [SldUtil loadAvatar:_avatarImageView gravatarKey:playerInfo.gravatarKey customAvatarKey:_gd.playerInfo.customAvatarKey];
    
    if (_nameInput.text == nil || _nameInput.text.length == 0) {
        [_nameInput becomeFirstResponder];
    }
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (IBAction)onGenderButton:(id)sender {
    [self.view endEditing:YES];
    
    NSString *genderText = _genderInput.text;
    if (genderText == nil) {
        genderText = @"";
    }
    NSDictionary *options = @{MMselectedObject:genderText, MMcaption:@"选择性别"};
    
    [MMPickerView showPickerViewInView:self.navigationController.view
                           withStrings:_genderStrings
                           withOptions:options
                            completion:^(NSString *selectedString) {
                                _genderInput.text = selectedString;
                            }];
}

- (IBAction)onTeamButton:(id)sender {
    [self.view endEditing:YES];
    
    NSString *teamText = _teamInput.text;
    if (teamText == nil) {
        teamText = @"";
    }
    NSDictionary *options = @{MMselectedObject:teamText, MMcaption:@"选择队伍"};
    
    [MMPickerView showPickerViewInView:self.navigationController.view
                           withStrings:_gd.TEAM_NAMES
                           withOptions:options
                            completion:^(NSString *selectedString) {
                                _teamInput.text = selectedString;
                            }];
}

- (IBAction)onAvatarButton:(id)sender {
    UIActionSheet *actionSheet = [[UIActionSheet alloc]initWithTitle:@"请选择头像类型"
                                                           delegate:self
                                                  cancelButtonTitle:@"取消"
                                             destructiveButtonTitle:nil
                                                  otherButtonTitles:@"gravatar头像", @"从相册中选取", @"拍照", nil];
    [actionSheet showInView:self.view];
    return;
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        [self.view endEditing:YES];
        SldAvatarSelectController* vc = (SldAvatarSelectController*)[getStoryboard() instantiateViewControllerWithIdentifier:@"avatarSelect"];
        
        [self.navigationController.view addSubview:vc.view];
        [self.navigationController addChildViewController:vc];
        [vc viewWillAppear:YES];
        vc.userInfoController = self;
    } else if (buttonIndex == 1) {
        UIImagePickerController *imagePicker =
        [[UIImagePickerController alloc] init];
        
        imagePicker.delegate = self;
        imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        imagePicker.mediaTypes = @[(NSString *) kUTTypeImage];
        imagePicker.allowsEditing = YES;
        
        [self presentViewController:imagePicker
                           animated:YES completion:nil];
    } else if (buttonIndex == 2) {
        UIImagePickerController *imagePicker =
        [[UIImagePickerController alloc] init];
        
        imagePicker.delegate = self;
        imagePicker.sourceType = UIImagePickerControllerSourceTypeCamera;
        imagePicker.mediaTypes = @[(NSString *) kUTTypeImage];
        imagePicker.allowsEditing = YES;
        imagePicker.cameraFlashMode = UIImagePickerControllerCameraFlashModeOff;
        
        [self presentViewController:imagePicker
                           animated:YES completion:nil];
    }
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
    [picker dismissViewControllerAnimated:YES completion:nil];
    
    CGRect rect;
    [(NSValue*)info[UIImagePickerControllerCropRect] getValue:&rect];
    CGSize scaledToSize = CGSizeMake(128, 128);
    if (rect.size.width > rect.size.height) {
        scaledToSize.width = 128 * rect.size.width / rect.size.height;
    } else if (rect.size.width > rect.size.height) {
        scaledToSize.height = 128 * rect.size.height / rect.size.width;
    }
    UIImage *scaledImage = [SldUtil imageWithImage:info[UIImagePickerControllerEditedImage] scaledToSize:scaledToSize];
    _avatarImageView.image = scaledImage;
    
    _gravatarKey = @"";
    
    _needUploadCustomAvatar = YES;
}

- (IBAction)onSave:(id)sender {
    if (_nameInput.text.length == 0 || _genderInput.text.length == 0 || _teamInput.text.length == 0) {
        alert(@"请填写所有信息.", nil);
        return;
    }
    
    if (_avatarImageView.image == nil) {
        alert(@"请选择头像.", nil);
        return;
    }
    
    //gravatar
    if (_gravatarKey.length) {
        _customAvatarKey = @"";
        [self save];
    }
    
    //custum avatar
    else if (_avatarImageView.image && _needUploadCustomAvatar) {
        //gen file name
        NSData *imageData = UIImageJPEGRepresentation(_avatarImageView.image, 0.85);
        
        SHA1 *sha1 = [[SHA1 alloc] init];
        [sha1 updateWith:imageData.bytes length:imageData.length];
        [sha1 final];
        
        NSData *nsd = [NSData dataWithBytes:sha1.buffer length:sha1.bufferSize];
        NSString *b64Name = [nsd urlBase64EncodedString];
        
        NSString *fileName = [NSString stringWithFormat:@"%@.jpg", b64Name];
        
        //save jpg
        NSString *filePath = makeImagePath(fileName);
        BOOL ok = [imageData writeToFile:filePath atomically:YES];
        if (!ok) {
            alert(@"图片保存失败", nil);
            return;
        }
        
        NSString *key = fileName;
        _customAvatarKey = key;
        _avatarUploadAlt = alertNoButton(@"上传头像中...");
        //get upload token
        SldHttpSession *session = [SldHttpSession defaultSession];
        NSArray *body = @[key];
        [session postToApi:@"player/getUptokens" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                alertHTTPError(error, data);
                [_avatarUploadAlt dismissWithClickedButtonIndex:0 animated:YES];
                return;
            }
            
            NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error) {
                lwError("Json error:%@", [error localizedDescription]);
                [_avatarUploadAlt dismissWithClickedButtonIndex:0 animated:YES];
                return;
            }
            
            if (array.count == 0) {
                [_avatarUploadAlt dismissWithClickedButtonIndex:0 animated:YES];
                return;
            }
            
            NSDictionary *dict = array.firstObject;
            NSString *token = [dict objectForKey:@"Token"];
            
            //upload
            QiniuSimpleUploader *uploader = [QiniuSimpleUploader uploaderWithToken:token];
            uploader.delegate = self;
            [uploader uploadFile:filePath key:key extra:nil];
        }];
    } else {
        [self save];
    }
}

- (void)save {
    UIAlertView *alt = alertNoButton(@"保存中...");

    NSUInteger genderIdx = [_genderStrings indexOfObject:_genderInput.text];
    if (genderIdx > 2) {
        genderIdx = 2;
    }

    NSDictionary *body = @{@"NickName":_nameInput.text, @"TeamName":_teamInput.text, @"Gender":@(genderIdx), @"GravatarKey":_gravatarKey, @"CustomAvatarKey":_customAvatarKey};
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"player/setInfo" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [alt dismissWithClickedButtonIndex:0 animated:YES];
        if (error) {
            alertHTTPError(error, data);
            return;
        }

        //succeed
        //[self.navigationController popViewControllerAnimated:YES];
        [self dismissViewControllerAnimated:YES completion:nil];
        if (self.presentingViewController.class == SldLoginViewController.class) {
            SldLoginViewController *vc = (SldLoginViewController *)self.presentingViewController;
            vc.shouldDismiss = YES;
            _gd.online = YES;
        }

        //update game data
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            alert(@"Json parse error!", nil);
            return;
        }
        
        _gd.playerInfo = [PlayerInfo playerWithDictionary:dict];
        
        SldUserController *userVc = [SldUserController getInstance];
        [userVc updateUI];
    }];
}

- (void)uploadSucceeded:(NSString *)filePath ret:(NSDictionary *)ret {
    [_avatarUploadAlt dismissWithClickedButtonIndex:0 animated:YES];
    [self save];
    _gd.playerInfo.customAvatarKey = _customAvatarKey;
    _needUploadCustomAvatar = NO;
}

- (void)uploadFailed:(NSString *)filePath error:(NSError *)error {
    [_avatarUploadAlt dismissWithClickedButtonIndex:0 animated:YES];
    alert(@"头像上传失败", nil);
    _customAvatarKey = _gd.playerInfo.customAvatarKey;
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














