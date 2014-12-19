//
//  SldMyMatchController.m
//  pin
//
//  Created by 李炜 on 14-8-16.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldMyMatchController.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldUtil.h"
#import "SldGameData.h"
#import "SldHttpSession.h"
#import "UIImage+ImageEffects.h"
#import "UIImageView+sldAsyncLoad.h"
#import "SldGameController.h"
#import "SldIapController.h"
#import "SldConfig.h"
#import "SldMatchBriefController.h"
#import "CBStoreHouseRefreshControl.h"
#import "SldUserPageController.h"

static NSArray* _assets;
static int _publishDelayHour = 0;
static int _challengeSec = 0;
static NSString *_promoUrl = nil;
static UIImage *_promoImage = nil;
static NSString *_promoImageKey = nil;
static int _sliderNum = 0;
static SldMyMatchListController *_myMatchListController = nil;
static const int IMAGE_SIZE_LIMIT_MB = 5;
static const int IMAGE_SIZE_LIMIT_BYTE = IMAGE_SIZE_LIMIT_MB * 1024 * 1024;

//=============================
@interface SldMyMatchCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet SldAsyncImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *playTimesLabel;
@property (weak, nonatomic) IBOutlet UILabel *prizeLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@property (nonatomic) Match* match;
@end

@implementation SldMyMatchCell
- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    return layoutAttributes;
}
@end

//=============================
@interface SldMyMatchHeader : UICollectionReusableView

@end

@implementation SldMyMatchHeader

@end

//=============================
@interface SldMyMatchFooter : UICollectionReusableView
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spin;
@property (weak, nonatomic) IBOutlet UIButton *loadMoreButton;

@end

@implementation SldMyMatchFooter

@end

//=============================
@interface SldMyMatchImagePickedCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet UIImageView *imageView;
@end

@implementation SldMyMatchImagePickedCell
- (UICollectionViewLayoutAttributes *)preferredLayoutAttributesFittingAttributes:(UICollectionViewLayoutAttributes *)layoutAttributes
{
    return layoutAttributes;
}
@end

//=============================
@interface SldMyMatchImagePickedHeader : UICollectionReusableView
@property (weak, nonatomic) IBOutlet UILabel *sliderNumLabel;
@property (weak, nonatomic) IBOutlet UISlider *sliderNumSlider;
@end

@implementation SldMyMatchImagePickedHeader

@end

//=============================
@interface SldMyMatchImagePickListController()

@property (nonatomic) NSArray *sliderNumbers;
@property (nonatomic) NSMutableArray *filePathes;
@property (nonatomic) SldMyMatchImagePickedHeader *header;
@property (nonatomic) QBImagePickerController *imagePickerController;
@end

@implementation SldMyMatchImagePickListController
- (void)viewDidLoad {
    [super viewDidLoad];
    
    //
    _filePathes = [NSMutableArray arrayWithCapacity:10];
    
    UIBarButtonItem *backButton = [[UIBarButtonItem alloc] initWithTitle:@"取消发布" style:UIBarButtonItemStylePlain target:self action:@selector(onBack)];
    self.navigationItem.leftBarButtonItem = backButton;
    
    _sliderNum = 5;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)onBack {
    [self.navigationController popToRootViewControllerAnimated:YES];
//    [self.navigationController popViewControllerAnimated:YES];
}

- (void)sliderNumValueChanged:(UISlider *)sender {
    NSUInteger index = (NSUInteger)(_header.sliderNumSlider.value + 0.5);
    [_header.sliderNumSlider setValue:index animated:NO];
    NSNumber *number = _sliderNumbers[index];
    _sliderNum = [number intValue];
    _header.sliderNumLabel.text = [NSString stringWithFormat:@"拼图滑块数量：%d", _sliderNum];
}

- (void)setAssets :(NSArray *)assets{
    _assets = assets;
    [self.collectionView reloadData];
    
    SldGameData *gd = [SldGameData getInstance];
    gd.userPackTestHistory = nil;
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _assets.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    SldMyMatchImagePickedCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"myMatchImagePickedCell" forIndexPath:indexPath];
    
    ALAsset *asset = [_assets objectAtIndex:indexPath.row];
//    NSString *path = asset.defaultRepresentation.url.absoluteString;
    
    cell.imageView.image = [UIImage imageWithCGImage:asset.thumbnail];
    
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    if (kind == UICollectionElementKindSectionHeader) {
        _header = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"myMatchImagePickListHeader" forIndexPath:indexPath];
        
        //
        _sliderNumbers = @[@(3), @(4), @(5), @(6), @(7), @(8)];
        //_sliderNum = 5;
        int numberOfSteps = ((float)[_sliderNumbers count] - 1);
        _header.sliderNumSlider.maximumValue = numberOfSteps;
        _header.sliderNumSlider.minimumValue = 0;
        _header.sliderNumSlider.continuous = YES;
        _header.sliderNumSlider.value = [_sliderNumbers indexOfObject:@(_sliderNum)];
        [_header.sliderNumSlider addTarget:self
                             action:@selector(sliderNumValueChanged:)
                   forControlEvents:UIControlEventValueChanged];
        [self sliderNumValueChanged:_header.sliderNumSlider];
        
        return _header;
        
    }
    return nil;
}

- (IBAction)onPlayButton:(id)sender {
    UIAlertView *alt = alertNoButton(@"生成中...");
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        if (_filePathes.count == 0) {
            int i = 0;
            for (ALAsset *asset in _assets) {
                ALAssetRepresentation *repr = asset.defaultRepresentation;
                UIImage *image = [[UIImage alloc] initWithCGImage:asset.defaultRepresentation.fullScreenImage];
                NSString *filePath = @"";
                
                //check gif
                unsigned char bytes[4];
                [repr getBytes:bytes fromOffset:0 length:4 error:nil];
                if (bytes[0]=='G' && bytes[1]=='I' && bytes[2]=='F') {
                    NSString *fileName = [NSString stringWithFormat:@"%d.gif", i];
                    filePath = makeTempPath(fileName);
                    
                    unsigned int size = (unsigned int)repr.size;
                    Byte *buffer = (Byte*)malloc(size);
                    NSUInteger buffered = [repr getBytes:buffer fromOffset:0 length:size error:nil];
                    NSData *data = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
                    [data writeToFile:filePath atomically:YES];
                    
                    if (size > IMAGE_SIZE_LIMIT_BYTE) {
                        NSString *str = [NSString stringWithFormat:@"单张图片不得大于%dMB，第%d张不符合要求", IMAGE_SIZE_LIMIT_MB, i+1];
                        alert(str, nil);
                        return;
                    }
                } else {
                    //resize
                    float l = MAX(image.size.width, image.size.height);
                    float s = MIN(image.size.width, image.size.height);
                    float scale = 1.0;
                    if (s > 400.0) {
                        scale = 400.0 / s;
                    }
                    float l2 = l * scale;
                    if (l2 > 800.0) {
                        scale *= 800.0 / l2;
                    }
                    float w = floorf(image.size.width * scale);
                    float h = floorf(image.size.height * scale);
                    image = [SldUtil imageWithImage:image scaledToSize:CGSizeMake(w, h)];
                    
                    //save
                    NSData *data = UIImageJPEGRepresentation(image, 0.85);
                    NSString *fileName = [NSString stringWithFormat:@"%d.jpg", i];
                    filePath = makeTempPath(fileName);
                    [data writeToFile:filePath atomically:YES];
                }
                
                [_filePathes addObject:filePath];
                i++;
            }
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            [alt dismissWithClickedButtonIndex:0 animated:YES];
            
            SldGameData *gd = [SldGameData getInstance];
            
            gd.match = [[Match alloc] init];
            gd.match.sliderNum = _sliderNum;
            
            gd.packInfo = [[PackInfo alloc] init];
            gd.packInfo.images = _filePathes;
            
            //enter game
            gd.gameMode = M_TEST;
            SldGameController *controller = [self.storyboard instantiateViewControllerWithIdentifier:@"game"];
            gd.matchSecret = nil;
            [self.navigationController pushViewController:controller animated:YES];
        });
    });
}

@end


//=============================
@implementation SldMatchPromoWebController
- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSURLRequest* request = [NSURLRequest requestWithURL:_url cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:30];
    
    [_reviewView loadRequest:request];
    
    self.title = [_url host];
}

- (IBAction)openSafari:(id)sender {
    [[UIApplication sharedApplication] openURL:_url];
}

@end

//=============================
@interface SldMyMatchPromoController : UIViewController <UITextFieldDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate>
@property (weak, nonatomic) IBOutlet UITextField *urlInput;
@property (weak, nonatomic) IBOutlet UIImageView *imageView;

@end

@implementation SldMyMatchPromoController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _urlInput.delegate = self;
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
    } else {
        _promoUrl = _urlInput.text;
        if (_promoImageKey == nil) {
            _promoImageKey = @"";
        }
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
}


@end

//=============================
@interface SldMyMatchSettingsController : UIViewController <UITextFieldDelegate>
@property (weak, nonatomic) IBOutlet UITextField *titleInput;
@property (weak, nonatomic) IBOutlet UILabel *coinLabel;
@property (weak, nonatomic) IBOutlet UITextField *coinInput;
@property (weak, nonatomic) IBOutlet UILabel *coinDescLabel;
@property (weak, nonatomic) IBOutlet UISwitch *privateSwitch;

@property (nonatomic) NSArray *numbers;

@property (nonatomic) QNUploadManager *upManager;
@property (nonatomic) UIAlertView *alt;
@property (nonatomic) int uploadNum;
@property (nonatomic) int finishNum;
@property (nonatomic) NSString *thumbKey;
@property (nonatomic) NSString *coverKey;
@property (nonatomic) NSString *coverBlurKey;
@property (nonatomic) NSMutableArray *images;
@property (nonatomic) NSMutableArray *thumbs;
@property (nonatomic) SldGameData *gd;
@property (nonatomic) int totalSize;
@property (nonatomic) int coinForPrize;

@end

@implementation SldMyMatchSettingsController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _gd = [SldGameData getInstance];
    _titleInput.delegate = self;
    
    //
    _coinDescLabel.text = [NSString stringWithFormat:@"注：总奖金的%d%%将作为奖金返还给你，总奖金包括你提供的奖金以及玩家在此游戏中消耗的金币所新增的奖金。", (int)(_gd.ownerPrizeProportion*100)];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    //
    _coinLabel.text = [NSString stringWithFormat:@"（现有%d金币）", _gd.playerInfo.goldCoin];
}

- (IBAction)onTouch:(id)sender {
    [self.view endEditing:YES];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string{
    
    const int kMaxLength = 60;
    NSString * toBeString = [textField.text stringByReplacingCharactersInRange:range withString:string];
    
    if (toBeString.length > kMaxLength){
        textField.text = [toBeString substringToIndex:kMaxLength];
        return NO;
        
    }
    return YES;
}

-(BOOL)textView:(UITextView *)textView shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)string
{
    const int kMaxLength = 2000;
    NSString * toBeString = [textView.text stringByReplacingCharactersInRange:range withString:string];
    
    if (toBeString.length > kMaxLength){
        textView.text = [toBeString substringToIndex:kMaxLength];
        return NO;
        
    }
    return YES;
}

- (IBAction)onPublish:(id)sender {
    _coinForPrize = [_coinInput.text intValue];
    
    if (_coinForPrize < 0) {
        _coinForPrize = 0;
    }
    
    //check prize
    SldGameData *gd = [SldGameData getInstance];
    if (gd.playerInfo.goldCoin < _coinForPrize) {
        NSString *msg = [NSString stringWithFormat:@"需要%d金币，我拥有%d金币。去商店购买更多金币吗？", _coinForPrize, gd.playerInfo.goldCoin];
        [[[UIAlertView alloc] initWithTitle:@"金币不足"
                                    message:msg
                           cancelButtonItem:[RIButtonItem itemWithLabel:@"取消" action:^{
            // Handle "Cancel"
        }]
                           otherButtonItems:[RIButtonItem itemWithLabel:@"去商店" action:^{
            SldIapController* vc = (SldIapController*)[getStoryboard() instantiateViewControllerWithIdentifier:@"iapController"];
            [self.navigationController pushViewController:vc animated:YES];
        }], nil] show];
        return;
    }
    
    [[[UIAlertView alloc] initWithTitle:@"确定发布吗?"
	                            message:@""
		               cancelButtonItem:[RIButtonItem itemWithLabel:@"取消" action:^{
        // Handle "Cancel"
    }]
				       otherButtonItems:[RIButtonItem itemWithLabel:@"发布" action:^{
        [self doPublish];
    }], nil] show];
}

- (void)doPublish {
    //save to temp dir
    _alt = alertNoButton(@"生成中...");
    _images = [NSMutableArray array];
    _thumbs = [NSMutableArray array];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int i = 0;
        NSMutableArray *filePathes = [NSMutableArray array];
        NSMutableArray *fileKeys = [NSMutableArray array];
        _totalSize = 0;

        for (ALAsset *asset in _assets) {
            NSString *fileName = [NSString stringWithFormat:@"%d.jpg", i];
            NSString *filePath = makeTempPath(fileName);
            ALAssetRepresentation *repr = asset.defaultRepresentation;
            NSString *key = @"";
            
            UIImage *image = [[UIImage alloc] initWithCGImage:repr.fullScreenImage];
            
            //check gif
            BOOL isGif = NO;
            unsigned char bytes[4];
            [repr getBytes:bytes fromOffset:0 length:4 error:nil];
            if (bytes[0]=='G' && bytes[1]=='I' && bytes[2]=='F') {
                isGif = YES;
                fileName = [NSString stringWithFormat:@"%d.gif", i];
                filePath = makeTempPath(fileName);
                
                unsigned int size = (unsigned int)repr.size;
                Byte *buffer = (Byte*)malloc(size);
                NSUInteger buffered = [repr getBytes:buffer fromOffset:0 length:size error:nil];
                NSData *data = [NSData dataWithBytesNoCopy:buffer length:buffered freeWhenDone:YES];
                [data writeToFile:filePath atomically:YES];
                key = [NSString stringWithFormat:@"%@.gif", [SldUtil sha1WithData:data]];
                
                if (size > IMAGE_SIZE_LIMIT_BYTE) {
                    NSString *str = [NSString stringWithFormat:@"单张图片不得大于%dMB，第%d张不符合要求", IMAGE_SIZE_LIMIT_MB, i+1];
                    [_alt dismissWithClickedButtonIndex:0 animated:NO];
                    alert(str, nil);
                    return;
                }
                _totalSize += size;
            } else {
                //resize
                float l = MAX(image.size.width, image.size.height);
                float s = MIN(image.size.width, image.size.height);
                float scale = 1.0;
                if (s > 400.0) {
                    scale = 400.0 / s;
                }
                float l2 = l * scale;
                if (l2 > 800.0) {
                    scale *= 800.0 / l2;
                }
                float w = floorf(image.size.width * scale);
                float h = floorf(image.size.height * scale);
                image = [SldUtil imageWithImage:image scaledToSize:CGSizeMake(w, h)];
                
                //save
                NSData *data = UIImageJPEGRepresentation(image, 0.85);
                [data writeToFile:filePath atomically:YES];
                
                _totalSize += data.length;
                
                //key
                key = [NSString stringWithFormat:@"%@.jpg", [SldUtil sha1WithData:data]];
            }
            
            [fileKeys addObject:key];
            [filePathes addObject:filePath];
            [_images addObject:@{@"File":fileName, @"Key":key}];
            
            //blur first image
            if (i == 0) {
                UIColor *tintColor = [UIColor colorWithWhite:1.0 alpha:0.3];
                UIImage *bluredImage = [image applyBlurWithRadius:25 tintColor:tintColor saturationDeltaFactor:1.4 maskImage:nil];
                
                //save
                NSData *data = UIImageJPEGRepresentation(bluredImage, 0.85);
                NSString *fileName = @"coverBlur.jpg";
                NSString *filePath = makeTempPath(fileName);
                [filePathes addObject:filePath];
                [data writeToFile:filePath atomically:YES];
                
                _coverKey = key;
                _coverBlurKey = [NSString stringWithFormat:@"%@.jpg", [SldUtil sha1WithData:data]];
                [fileKeys addObject:_coverBlurKey];
            }
            
            //thumbs
            float s = MIN(image.size.width, image.size.height);
            float l = 200.0;
            float scale = l/s;
            float w = image.size.width * scale;
            float h = image.size.height * scale;
            image = [SldUtil imageWithImage:image scaledToSize:CGSizeMake(w, h)];
            CGRect cropRect = CGRectMake(0, 0, l, l);
            if (image.size.width >= image.size.height) {
                cropRect.origin.x = (w-l)*0.5;
            } else {
                cropRect.origin.y = (h-l)*0.5;
            }
            
            CGImageRef imageRef = CGImageCreateWithImageInRect([image CGImage], cropRect);
            image = [UIImage imageWithCGImage:imageRef];
            
            //thumb save
            NSData *data = UIImageJPEGRepresentation(image, 0.85);
            if (isGif) {
                fileName = [NSString stringWithFormat:@"thumb%d.gif", i];
            } else {
                fileName = [NSString stringWithFormat:@"thumb%d.jpg", i];
            }
            
            filePath = makeTempPath(fileName);
            [filePathes addObject:filePath];
            [data writeToFile:filePath atomically:YES];
            
            //thumb key
            if (isGif) {
                key = [NSString stringWithFormat:@"%@.gif", [SldUtil sha1WithData:data]];
            } else {
                key = [NSString stringWithFormat:@"%@.jpg", [SldUtil sha1WithData:data]];
            }
            
            [fileKeys addObject:key];
            [_thumbs addObject:key];
            
            if (i == 0) {
                _thumbKey = key;
            }
            
            i++;
        }
        
        //promo image
        if (_promoImage) {
            NSData *data = UIImageJPEGRepresentation(_promoImage, 0.85);
            NSString *fileName = @"promo.jpg";
            NSString *filePath = makeTempPath(fileName);
            [filePathes addObject:filePath];
            [data writeToFile:filePath atomically:YES];
            
            _promoImageKey = [NSString stringWithFormat:@"%@.jpg", [SldUtil sha1WithData:data]];
            [fileKeys addObject:_promoImageKey];
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
//            //thumb
//            ALAsset *asset = [_assets firstObject];
//            UIImage *image = [[UIImage alloc] initWithCGImage:asset.defaultRepresentation.fullScreenImage];
//            float s = MIN(image.size.width, image.size.height);
//            float scale = 256.0/s;
//            float w = image.size.width * scale;
//            float h = image.size.height * scale;
//            image = [SldUtil imageWithImage:image scaledToSize:CGSizeMake(w, h)];
//            CGRect cropRect = CGRectMake(0, 0, 256, 256);
//            if (image.size.width >= image.size.height) {
//                cropRect.origin.x = w*0.5-128;
//            } else {
//                cropRect.origin.y = h*0.5-128;
//            }
//            
//            CGImageRef imageRef = CGImageCreateWithImageInRect([image CGImage], cropRect);
//            image = [UIImage imageWithCGImage:imageRef];
//            
//            //thumb save
//            NSData *data = UIImageJPEGRepresentation(image, 0.85);
//            NSString *fileName = @"thumb.jpg";
//            NSString *filePath = makeTempPath(fileName);
//            [filePathes addObject:filePath];
//            [data writeToFile:filePath atomically:YES];
//            
//            //thumb key
//            _thumbKey = [NSString stringWithFormat:@"%@.jpg", [SldUtil sha1WithData:data]];
//            [fileKeys addObject:_thumbKey];
            
            
            
            //
            _alt.title = @"上传中... 0%";
            
            //uploader
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
                
                _uploadNum = 0;
                _finishNum = 0;
//                int i = 0;
                
                SldConfig *conf = [SldConfig getInstance];
                int i = 0;
                for (NSString *filePath in filePathes) {
                    NSString *key = [fileKeys objectAtIndex:i];
                    i++;
                    NSString *strUrl = [NSString stringWithFormat:@"%@/%@", conf.UPLOAD_HOST, key];
                    _uploadNum++;
                    
                    //check exist
                    NSURL *url = [NSURL URLWithString: strUrl];
                    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL: url];
                    [request setHTTPMethod: @"HEAD"];
                    dispatch_async( dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), ^{
                        NSHTTPURLResponse *response;
                        NSError *error;
                        [NSURLConnection sendSynchronousRequest: request returningResponse: &response error: &error];
                        
                        dispatch_async( dispatch_get_main_queue(), ^{
                            if (response.statusCode != 200) {
                                //upload
                                [_upManager putFile:filePath
                                               key:key
                                             token:token
                                          complete:^(QNResponseInfo *info, NSString *key, NSDictionary *resp) {
                                              if (info.ok) {
                                                  _finishNum++;
                                                  if (_finishNum >= _uploadNum) {
                                                      [self addUserPack];
                                                  } else {
                                                      float f = (float)_finishNum/_uploadNum;
                                                      int n = f*100;
                                                      _alt.title = [NSString stringWithFormat:@"上传中... %d%%", n];
                                                  }
                                              } else {
                                                  [_alt dismissWithClickedButtonIndex:0 animated:YES];
                                                  _alt = nil;
                                                  alert(@"上传失败", nil);
                                                  lwError(@"uploadFailed: %@", filePath);
                                              }
                                          }
                                            option:nil];
                            } else {
                                _finishNum++;
                                if (_finishNum >= _uploadNum) {
                                    [self addUserPack];
                                } else {
                                    float f = (float)_finishNum/_uploadNum;
                                    int n = f*100;
                                    _alt.title = [NSString stringWithFormat:@"上传中... %d%%", n];
                                }
                            }
                        });
                    });
                }
            }];
        });
    });
    
}

- (void)addUserPack {
    _alt.title = @"生成中...";
    
//    [_alt dismissWithClickedButtonIndex:0 animated:NO];
//    alert(@"上传成功", nil);
//
    NSString *beginTimeStr = @"";
    if (_publishDelayHour) {
        NSDate *date = [NSDate dateWithTimeIntervalSinceNow:_publishDelayHour*3600.0];
        NSDateFormatter* fmt = [[NSDateFormatter alloc] init];
        fmt.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"zh_CN"];
        fmt.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss";
        beginTimeStr = [fmt stringFromDate:date];
    }
    
    SldHttpSession *session = [SldHttpSession defaultSession];
    float fMb = (float)_totalSize/(1024.f*1024.f);
    NSDictionary *body = @{
        @"Title":_titleInput.text,
        @"Text":@"",
        @"Thumb":_thumbKey,
        @"Cover":_coverKey,
        @"CoverBlur":_coverBlurKey,
        @"Images":_images,
        @"Thumbs":_thumbs,
        @"SizeMb":@(fMb),
        @"GoldCoinForPrize":@(_coinForPrize),
        @"SliderNum":@(_sliderNum),
        @"BeginTimeStr":beginTimeStr,
        @"ChallengeSeconds":@(_challengeSec),
        @"PromoUrl":_promoUrl,
        @"PromoImage":_promoImageKey,
        @"Private":@([_privateSwitch isOn]),
    };
    [session postToApi:@"match/new" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            [_alt dismissWithClickedButtonIndex:0 animated:NO];
            _alt = nil;
            alertHTTPError(error, data);
            return;
        }
        
        [_alt dismissWithClickedButtonIndex:0 animated:YES];
        
        _gd.playerInfo.goldCoin -= _coinForPrize;
        
        //
        [[[UIAlertView alloc] initWithTitle:@"发布成功！"
                                    message:nil
                           cancelButtonItem:[RIButtonItem itemWithLabel:@"好的" action:^{
//            [self.navigationController popToViewController:_myMatchListController animated:YES];
            [self.navigationController popToRootViewControllerAnimated:YES];
//            [_myMatchListController refresh];
            [_gd.myPageController refresh];
        }]
                           otherButtonItems:nil] show];
    }];
}

@end

//=============================
@interface SldMyMatchListController()

@property (nonatomic) NSMutableArray *matches;
@property (nonatomic) SldMyMatchFooter* footer;
@property (nonatomic) SldMyMatchHeader* header;
@property (nonatomic) QBImagePickerController *imagePickerController;
@property (nonatomic) MSWeakTimer *secTimer;
@property (nonatomic) SldGameData *gd;
@property (nonatomic) CBStoreHouseRefreshControl *storeHouseRefreshControl;
@property (nonatomic) BOOL refreshOnce;

@end

@implementation SldMyMatchListController

static SldMyMatchListController* _inst = nil;

+ (instancetype)getInst {
    return _inst;
}

- (void)onTabSelect {
    if (!_refreshOnce) {
        _refreshOnce = YES;
        [self refresh];
    }
}

- (void)dealloc {
    [_secTimer invalidate];
    _inst = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _inst = self;
    _gd = [SldGameData getInstance];
    _refreshOnce = NO;
    
    _myMatchListController = self;
    _matches = [NSMutableArray array];
    
    self.collectionView.alwaysBounceVertical = YES;
    self.storeHouseRefreshControl = [CBStoreHouseRefreshControl attachToScrollView:self.collectionView target:self refreshAction:@selector(refresh) plist:@"storehouse"];
    
    //
    [self refresh];
    
    //timer
    _secTimer = [MSWeakTimer scheduledTimerWithTimeInterval:1.f target:self selector:@selector(onSecTimer) userInfo:nil repeats:YES dispatchQueue:dispatch_get_main_queue()];
}

- (void)onSecTimer {
    NSArray *visibleCells = [self.collectionView visibleCells];
    for (SldMyMatchCell *cell in visibleCells) {
        [self refreshTimeLabel:cell];
    }
}
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    CGFloat top = self.topLayoutGuide.length;
    CGFloat bottom = self.bottomLayoutGuide.length;
    UIEdgeInsets newInsets = UIEdgeInsetsMake(top, 0, bottom, 0);
    self.collectionView.contentInset = newInsets;
    
//    //refesh
//    if (_gd.playerInfo && _gd.needRefreshOwnerList) {
//        [self refresh];
//    }
}

- (void)refresh {
    _gd.needRefreshOwnerList = NO;
    _footer.loadMoreButton.enabled = NO;
    
    NSDictionary *body = @{@"StartId": @(0), @"BeginTime":@(0), @"Limit": @(MATCH_FETCH_LIMIT)};
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"match/listMine" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        _footer.loadMoreButton.enabled = YES;
        [_storeHouseRefreshControl finishingLoading];
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        if (array.count < MATCH_FETCH_LIMIT) {
            [_footer.loadMoreButton setTitle:@"后面没有了" forState:UIControlStateNormal];
            _footer.loadMoreButton.enabled = NO;
        } else {
            [_footer.loadMoreButton setTitle:@"更多" forState:UIControlStateNormal];
            _footer.loadMoreButton.enabled = YES;
        }
        
        //delete
        int matchNum = _matches.count;
        [_matches removeAllObjects];
        NSMutableArray *deleteIndexPathes = [NSMutableArray array];
        for (int i = 0; i < matchNum; ++i) {
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
            [deleteIndexPathes addObject:indexPath];
        }
        [self.collectionView deleteItemsAtIndexPaths:deleteIndexPathes];
        
        //insert
        NSMutableArray *insertIndexPathes = [NSMutableArray array];
        for (NSDictionary *dict in array) {
            Match *match = [[Match alloc] initWithDict:dict];
            [_matches addObject:match];
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:_matches.count-1 inSection:0];
            [insertIndexPathes addObject:indexPath];
        }
        [self.collectionView insertItemsAtIndexPaths:insertIndexPathes];
    }];
}

- (void)refreshTimeLabel:(SldMyMatchCell*)cell {
    NSDate *endTime = [NSDate dateWithTimeIntervalSince1970:cell.match.endTime];
    NSDate *now = getServerNow();
    NSTimeInterval endIntv = [endTime timeIntervalSinceDate:now];
    if (endIntv <= 0) {
        cell.timeLabel.text = @"已结束";
        cell.timeLabel.backgroundColor = _matchTimeLabelRed;
    } else {
        cell.timeLabel.backgroundColor = _matchTimeLabelGreen;
        if (endIntv > 3600) {
            cell.timeLabel.text = [NSString stringWithFormat:@"%d小时", (int)endIntv/3600];
        } else {
            cell.timeLabel.text = [NSString stringWithFormat:@"%d分钟", (int)endIntv/60];
        }
    }
}

- (IBAction)onNewMatch:(id)sender {
    _imagePickerController = [[QBImagePickerController alloc] init];
    _imagePickerController.delegate = self;
    _imagePickerController.filterType = QBImagePickerControllerFilterTypePhotos;
    _imagePickerController.allowsMultipleSelection = YES;
    _imagePickerController.minimumNumberOfSelection = 4;
    _imagePickerController.maximumNumberOfSelection = 12;
    _imagePickerController.title = @"选择4-12张图片";
 
    _imagePickerController.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:_imagePickerController animated:YES];
}

- (void)qb_imagePickerController:(QBImagePickerController *)imagePickerController didSelectAssets:(NSArray *)assets {
//    [self.navigationController popToViewController:self animated:NO];
    
    SldMyMatchImagePickListController* vc = (SldMyMatchImagePickListController*)[getStoryboard() instantiateViewControllerWithIdentifier:@"myUserPackEditVC"];
    
    [self.navigationController pushViewController:vc animated:YES];
    
    [vc setAssets:assets];
}

- (void)qb_imagePickerControllerDidCancel:(QBImagePickerController *)imagePickerController {
//    [self.navigationController popToViewController:self animated:YES];
    [self.navigationController popToRootViewControllerAnimated:YES];
}

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return _matches.count;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath {
    SldMyMatchCell *cell = [collectionView dequeueReusableCellWithReuseIdentifier:@"myMatchCell" forIndexPath:indexPath];
    Match *match = [_matches objectAtIndex:indexPath.row];
    [cell.imageView asyncLoadUploadImageWithKey:match.thumb showIndicator:NO completion:nil];
    cell.playTimesLabel.text = [NSString stringWithFormat:@"%d", match.playTimes];
    if (match.extraPrize == 0) {
        cell.prizeLabel.text = [NSString stringWithFormat:@"奖金：%d", match.prize];
    } else {
        cell.prizeLabel.text = [NSString stringWithFormat:@"奖金：%d+%d", match.prize, match.extraPrize];
    }
    cell.match = match;
    
    [self refreshTimeLabel:cell];
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    if (kind == UICollectionElementKindSectionHeader) {
        _header = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader withReuseIdentifier:@"myMatchListHeader" forIndexPath:indexPath];
        return _header;

    } else if (kind == UICollectionElementKindSectionFooter) {
        _footer = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"myMatchListFooter" forIndexPath:indexPath];
        return _footer;
    }
    return nil;
}

//- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath
//{
//    SldMyMatchCell* cell = (SldMyMatchCell*)[collectionView cellForItemAtIndexPath:indexPath];
//    
//    //
//    SldGameData *gd = [SldGameData getInstance];
//    gd.match = cell.match;
//    
//    SldMatchBriefController *controller = [self.storyboard instantiateViewControllerWithIdentifier:@"matchBrief"];
//    [self.tabBarController.navigationController pushViewController:controller animated:YES];
//    self.tabBarController.navigationController.navigationBarHidden = NO;
//}
//
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    if (segue.identifier && [segue.identifier compare:@"cellSegue"] == 0) {
        SldMyMatchCell *cell = sender;
        SldGameData *gd = [SldGameData getInstance];
        gd.match = cell.match;
    }
}

- (IBAction)onLoadMoreButton:(id)sender {
    if (_matches.count == 0) {
        return;
    }
    
    [_footer.spin startAnimating];
    _footer.spin.hidden = NO;
    _footer.loadMoreButton.enabled = NO;
    
    Match* lastMatch = [_matches lastObject];
    
    NSDictionary *body = @{@"StartId": @(lastMatch.id), @"BeginTime":@(lastMatch.beginTime), @"Limit": @(MATCH_FETCH_LIMIT)};
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"match/listMine" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        [_footer.spin stopAnimating];
        _footer.loadMoreButton.enabled = YES;
        if (error) {
            alertHTTPError(error, data);
            return;
        }
        NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
        if (error) {
            lwError("Json error:%@", [error localizedDescription]);
            return;
        }
        
        if (array.count < MATCH_FETCH_LIMIT) {
            [_footer.loadMoreButton setTitle:@"后面没有了" forState:UIControlStateNormal];
            _footer.loadMoreButton.enabled = NO;
        }
        
        NSMutableArray *insertIndexPathes = [NSMutableArray array];
        for (NSDictionary *dict in array) {
            Match *match = [[Match alloc] initWithDict:dict];
            [_matches addObject:match];
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:_matches.count-1 inSection:0];
            [insertIndexPathes addObject:indexPath];
        }
        [self.collectionView insertItemsAtIndexPaths:insertIndexPathes];
    }];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
    [self.storeHouseRefreshControl scrollViewDidScroll];
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    [self.storeHouseRefreshControl scrollViewDidEndDragging];
}

- (IBAction)onShareButton:(id)sender {
    if (_matches.count == 0) {
        alert(@"暂时没有什么可分享的，先发布一个图集试试吧。", nil);
        return;
    }
    
    Match *match = _matches[0];
    NSString *path = makeImagePath(match.thumb);
    UIImage *image = [UIImage imageWithContentsOfFile:path];
    NSString *url = [NSString stringWithFormat:@"%@?u=%lld", [SldConfig getInstance].USER_HOME_URL, _gd.playerInfo.userId];
    
    [[[UIAlertView alloc] initWithTitle:    @"把我的所有图集生成网页分享给朋友（注意，包括私密发布的图集）"
                                message:    nil
                       cancelButtonItem:    [RIButtonItem itemWithLabel:@"取消" action:nil]
                       otherButtonItems:    [RIButtonItem itemWithLabel:@"拷贝链接地址" action:^{
                                                UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
                                                pasteboard.string = url;
                                            }],
                                            [RIButtonItem itemWithLabel:@"分享到社交平台" action:^{
                                                NSString *weixinText = [NSString stringWithFormat:@"我创建的所有拼图都在这儿啦。"];
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
                                                                                   delegate:nil];
                                            }],
    nil] show];
}

@end
