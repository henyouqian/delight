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
#import "SldUtil.h"
#import "SldHttpSession.h"
#import "SldGameData.h"
#import "UIImageView+sldAsyncLoad.h"
#import "NSData+Base64.h"

@interface SldUserInfoController ()
@property (weak, nonatomic) IBOutlet UITextField *nameInput;
@property (weak, nonatomic) IBOutlet UITextField *genderInput;
@property (weak, nonatomic) IBOutlet UITextField *teamInput;
@property (weak, nonatomic) IBOutlet UIImageView *avatarImageView;
@property (weak, nonatomic) IBOutlet UIBarButtonItem *cancelButton;
@property (nonatomic) NSString *gravatarKey;
//@property (nonatomic) NSString *customAvatarKey;
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
    
    _nameInput.delegate = self;
    
    SldGameData *gamedata = [SldGameData getInstance];
    
    _genderStrings = @[@"女", @"男", @"保密"];
    
    _nameInput.text = gamedata.nickName;
    _genderInput.text = [_genderStrings objectAtIndex:gamedata.gender];
    _teamInput.text = gamedata.teamName;
    _gravatarKey = gamedata.gravatarKey;
    
    if (_gravatarKey) {
        NSString *url = [SldUtil makeGravatarUrlWithKey:_gravatarKey width:_avatarImageView.frame.size.width];
        [_avatarImageView asyncLoadImageWithUrl:url showIndicator:NO completion:nil];
    }
    
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
    
    SldGameData *gd = [SldGameData getInstance];
    
    [MMPickerView showPickerViewInView:self.navigationController.view
                           withStrings:gd.TEAM_NAMES
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
                                                  otherButtonTitles:@"gravatar头像", @"从相册中选取", nil];
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
    } else {
        UIImagePickerController *imagePicker =
        [[UIImagePickerController alloc] init];
        
        imagePicker.delegate = self;
        imagePicker.sourceType = UIImagePickerControllerSourceTypePhotoLibrary;
        imagePicker.mediaTypes =
        @[(NSString *) kUTTypeImage];
        imagePicker.allowsEditing = YES;
        
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
    
    _gravatarKey = nil;
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
    
    //custum avatar
    if (!_gravatarKey && _avatarImageView.image) {
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
        
        //get upload token
        SldHttpSession *session = [SldHttpSession defaultSession];
        NSArray *body = @[key];
        [session postToApi:@"player/getUptoken" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                alertHTTPError(error, data);
                return;
            }
            
            NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error) {
                lwError("Json error:%@", [error localizedDescription]);
                return;
            }
            
            if (array.count == 0) {
                return;
            }
            
            NSDictionary *dict = array.firstObject;
            NSString *token = [dict objectForKey:@"Token"];
            
            //upload
            QiniuSimpleUploader *uploader = [QiniuSimpleUploader uploaderWithToken:token];
            uploader.delegate = self;
            [uploader uploadFile:filePath key:key extra:nil];
        }];

    }
    
//    UIAlertView *alt = alertNoButton(@"保存中...");
//    
//    NSUInteger genderIdx = [_genderStrings indexOfObject:_genderInput.text];
//    if (genderIdx > 2) {
//        genderIdx = 2;
//    }
//    
//    NSString *gravatarKey = @"";
//    if (_gravatarKey != nil) {
//        gravatarKey = _gravatarKey;
//    }
//    
//    NSDictionary *body = @{@"NickName":_nameInput.text, @"TeamName":_teamInput.text, @"Gender":@(genderIdx), @"GravatarKey":gravatarKey, @"CustomAvatarKey":@""};
//    SldHttpSession *session = [SldHttpSession defaultSession];
//    [session postToApi:@"player/setInfo" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
//        [alt dismissWithClickedButtonIndex:0 animated:YES];
//        if (error) {
//            alertHTTPError(error, data);
//            return;
//        }
//        
//        SldGameData *gamedata = [SldGameData getInstance];
//        
//        //succeed
//        //[self.navigationController popViewControllerAnimated:YES];
//        [self dismissViewControllerAnimated:YES completion:nil];
//        if (self.presentingViewController.class == SldLoginViewController.class) {
//            SldLoginViewController *vc = (SldLoginViewController *)self.presentingViewController;
//            vc.shouldDismiss = YES;
//            gamedata.online = YES;
//        }
//        
//        //update game data
//        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
//        if (error) {
//            alert(@"Json parse error!", nil);
//            return;
//        }
//        gamedata.nickName = [dict objectForKey:@"NickName"];
//        gamedata.gender = [(NSNumber*)[dict objectForKey:@"Gender"] unsignedIntValue];
//        gamedata.teamName = [dict objectForKey:@"TeamName"];
//        gamedata.gravatarKey = [dict objectForKey:@"GravatarKey"];
//        gamedata.money = [(NSNumber*)[dict objectForKey:@"Money"] intValue];
//        
//        [self.presentingViewController viewWillAppear:YES];
//    }];
}

- (void)uploadSucceeded:(NSString *)filePath ret:(NSDictionary *)ret {
    
}

- (void)uploadFailed:(NSString *)filePath error:(NSError *)error {
    
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














