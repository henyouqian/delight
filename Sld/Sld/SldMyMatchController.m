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
#import "MSWeakTimer.h"
#import "SldConfig.h"

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
@property (weak, nonatomic) IBOutlet UILabel *rewardNumLabel;
@property (weak, nonatomic) IBOutlet UILabel *timeLabel;
@property (nonatomic) Match* match;
@end

@implementation SldMyMatchCell

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

@end

//=============================
@interface SldMyMatchImagePickedHeader : UICollectionReusableView
@property (weak, nonatomic) IBOutlet UILabel *sliderNumLabel;
@property (weak, nonatomic) IBOutlet UISlider *sliderNumSlider;
@end

@implementation SldMyMatchImagePickedHeader

@end

//=============================
@interface SldMyMatchImagePickListController : UICollectionViewController

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
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}

- (void)onBack {
    [self.navigationController popViewControllerAnimated:YES];
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
        _sliderNumbers = @[@(3), @(4), @(5), @(6), @(7)];
        _sliderNum = 5;
        int numberOfSteps = ((float)[_sliderNumbers count] - 1);
        _header.sliderNumSlider.maximumValue = numberOfSteps;
        _header.sliderNumSlider.minimumValue = 0;
        _header.sliderNumSlider.continuous = YES;
        _header.sliderNumSlider.value = 2;
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
@interface SldMyMatchSettingsController : UIViewController <UITextFieldDelegate, UITextViewDelegate, QiniuUploadDelegate>
@property (weak, nonatomic) IBOutlet UISlider *slider;
@property (weak, nonatomic) IBOutlet UILabel *priceLable;
@property (weak, nonatomic) IBOutlet UILabel *goldCoinLabel;
@property (weak, nonatomic) IBOutlet UITextField *titleInput;
@property (weak, nonatomic) IBOutlet UILabel *publishDelayLabel;
@property (weak, nonatomic) IBOutlet UISlider *publishDelaySlider;
@property (weak, nonatomic) IBOutlet UIStepper *stepper;
@property (weak, nonatomic) IBOutlet UILabel *couponLabel;
@property (weak, nonatomic) IBOutlet UITextField *couponInput;
@property (weak, nonatomic) IBOutlet UILabel *couponDescLabel;
@property (weak, nonatomic) IBOutlet UISwitch *privateSwitch;

@property (nonatomic) int rewardCoupon;
@property (nonatomic) NSArray *numbers;

@property (nonatomic) QiniuSimpleUploader* uploader;
@property (nonatomic) UIAlertView *alt;
@property (nonatomic) int uploadNum;
@property (nonatomic) int finishNum;
@property (nonatomic) NSString *thumbKey;
@property (nonatomic) NSString *coverKey;
@property (nonatomic) NSString *coverBlurKey;
@property (nonatomic) NSMutableArray *images;
@property (nonatomic) SldGameData *gd;
@end

static const int COUPON_MIN = 0;
static const int COUPON_MAX = 10000;

@implementation SldMyMatchSettingsController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _gd = [SldGameData getInstance];
    _titleInput.delegate = self;
    
    //coupon slider
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:50];
    for (int i = 0; i < 101; i++) {
        [array addObject:@(i*100)];
    }
    _numbers = [NSArray arrayWithArray:array];
    _rewardCoupon = COUPON_MIN;
    NSInteger numberOfSteps = ((float)[_numbers count] - 1);
    _slider.maximumValue = numberOfSteps;
    _slider.minimumValue = 0;
    _slider.continuous = YES;
    _slider.value = 0;
    [_slider addTarget:self
               action:@selector(valueChanged:)
     forControlEvents:UIControlEventValueChanged];
    
    [self valueChanged:_slider];
    
    //
    _stepper.maximumValue = COUPON_MAX;
    _stepper.minimumValue = COUPON_MIN;
    _stepper.value = COUPON_MIN;
    _stepper.stepValue = 100;
    
    //publish delay slider
    _publishDelayHour = 0;
    _publishDelaySlider.minimumValue = 0;
    _publishDelaySlider.maximumValue = 24;
    _publishDelaySlider.continuous = YES;
    _publishDelaySlider.value = 0;
    
    [_publishDelaySlider addTarget:self
                action:@selector(publishDelayChanged:)
      forControlEvents:UIControlEventValueChanged];
    [self publishDelayChanged:_publishDelaySlider];
    
    //
    _couponDescLabel.text = [NSString stringWithFormat:@"注：总奖金的%d%%将作为奖金返还给你，总奖金包括你提供的奖金以及玩家在此游戏中消耗的金币所新增的奖金。", (int)(_gd.ownerRewardProportion*100)];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    //
    _couponLabel.text = [NSString stringWithFormat:@"（现有%d金币）", _gd.playerInfo.goldCoin];
}

- (IBAction)onTouch:(id)sender {
    [self.view endEditing:YES];
}

//- (IBAction)couponEditEnd:(id)sender {
//    int n = [_couponInput.text intValue];
//    n = n / 100 * 100;
//    if (n < 0) {
//        n = 0;
//    }
//    _couponInput.text = [NSString stringWithFormat:@"%d", n];
//}

- (void)valueChanged:(UISlider *)sender {
    NSUInteger index = (NSUInteger)(_slider.value + 0.5);
    [_slider setValue:index animated:NO];
    NSNumber *number = _numbers[index];
    
    _rewardCoupon = [number intValue];
    _stepper.value = _rewardCoupon;
    
    [self updateCouponLabel];
}

- (IBAction)onStepperValueChanged:(id)sender {
    _rewardCoupon = _stepper.value;
    _slider.value = [_numbers indexOfObject:@(_rewardCoupon)];

    [self updateCouponLabel];
}

- (void)updateCouponLabel {
    _priceLable.text = [NSString stringWithFormat:@"提供奖金数量：%d", _rewardCoupon];
    
    SldGameData *gd = [SldGameData getInstance];
    _goldCoinLabel.text = [NSString stringWithFormat:@"需要支付%d金币（现有%d金币）", _rewardCoupon, gd.playerInfo.goldCoin];
}

- (void)publishDelayChanged:(UISlider *)sender {
    _publishDelayHour = (int)(sender.value + 0.5);
    [sender setValue:_publishDelayHour animated:NO];
    if (_publishDelayHour == 0) {
        _publishDelayLabel.text = [NSString stringWithFormat:@"延时发布：%d小时（即时发布）", _publishDelayHour];
    } else {
        _publishDelayLabel.text = [NSString stringWithFormat:@"延时发布：%d小时", _publishDelayHour];
    }
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
    //
    _rewardCoupon = [_couponInput.text intValue];
//    if (_rewardCoupon % 100 != 0) {
//        alert(@"奖励必须为0或者100的倍数", nil);
//        return;
//    }
    
    if (_rewardCoupon < 0) {
        _rewardCoupon = 0;
    }
    
    //check coupon
    SldGameData *gd = [SldGameData getInstance];
    if (gd.playerInfo.goldCoin < _rewardCoupon) {
        NSString *msg = [NSString stringWithFormat:@"需要%d金币，我拥有%d金币。去商店购买更多金币吗？", _rewardCoupon, gd.playerInfo.goldCoin];
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
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        int i = 0;
        NSMutableArray *filePathes = [NSMutableArray array];
        NSMutableArray *fileKeys = [NSMutableArray array];

        for (ALAsset *asset in _assets) {
            NSString *fileName = [NSString stringWithFormat:@"%d.jpg", i];
            NSString *filePath = makeTempPath(fileName);
            ALAssetRepresentation *repr = asset.defaultRepresentation;
            NSString *key = @"";
            
            UIImage *image = [[UIImage alloc] initWithCGImage:repr.fullScreenImage];
            
            //check gif
            unsigned char bytes[4];
            [repr getBytes:bytes fromOffset:0 length:4 error:nil];
            if (bytes[0]=='G' && bytes[1]=='I' && bytes[2]=='F') {
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
                lwInfo("gifSize: %d", (int)size);
                //free(buffer);
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
                
                //key
                key = [NSString stringWithFormat:@"%@.jpg", [SldUtil sha1WithData:data]];
            }
            
            [fileKeys addObject:key];
            [filePathes addObject:filePath];
            [_images addObject:@{@"File":fileName, @"Key":key}];
            
            //blur first image
            if (i == 0) {
                UIColor *tintColor = [UIColor colorWithWhite:1.0 alpha:0.3];
                image = [image applyBlurWithRadius:25 tintColor:tintColor saturationDeltaFactor:1.4 maskImage:nil];
                
                //save
                NSData *data = UIImageJPEGRepresentation(image, 0.85);
                NSString *fileName = @"coverBlur.jpg";
                NSString *filePath = makeTempPath(fileName);
                [filePathes addObject:filePath];
                [data writeToFile:filePath atomically:YES];
                
                _coverKey = key;
                _coverBlurKey = [NSString stringWithFormat:@"%@.jpg", [SldUtil sha1WithData:data]];
                [fileKeys addObject:_coverBlurKey];
            }
            
            i++;
        }
        dispatch_async(dispatch_get_main_queue(), ^{
            //thumb
            ALAsset *asset = [_assets firstObject];
            UIImage *image = [[UIImage alloc] initWithCGImage:asset.defaultRepresentation.fullScreenImage];
            float s = MIN(image.size.width, image.size.height);
            float scale = 256.0/s;
            float w = image.size.width * scale;
            float h = image.size.height * scale;
            image = [SldUtil imageWithImage:image scaledToSize:CGSizeMake(w, h)];
            CGRect cropRect = CGRectMake(0, 0, 256, 256);
            if (image.size.width >= image.size.height) {
                cropRect.origin.x = w*0.5-128;
            } else {
                cropRect.origin.y = h*0.5-128;
            }
            
            CGImageRef imageRef = CGImageCreateWithImageInRect([image CGImage], cropRect);
            image = [UIImage imageWithCGImage:imageRef];
            
            //thumb save
            NSData *data = UIImageJPEGRepresentation(image, 0.85);
            NSString *fileName = @"thumb.jpg";
            NSString *filePath = makeTempPath(fileName);
            [filePathes addObject:filePath];
            [data writeToFile:filePath atomically:YES];
            
            //thumb key
            _thumbKey = [NSString stringWithFormat:@"%@.jpg", [SldUtil sha1WithData:data]];
            [fileKeys addObject:_thumbKey];
            
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
                
                _uploader = [QiniuSimpleUploader uploaderWithToken:token];
                _uploader.delegate = self;
                
                _uploadNum = 0;
                _finishNum = 0;
                int i = 0;
                for (NSString *filePath in filePathes) {
                    NSString *key = [fileKeys objectAtIndex:i];
                    [_uploader uploadFile:filePath key:key extra:nil];
                    _uploadNum++;
                    i++;
                }
            }];
        });
    });
    
}

- (void)uploadSucceeded:(NSString *)filePath ret:(NSDictionary *)ret {
    _finishNum++;
    if (_finishNum >= _uploadNum) {
        [self addUserPack];
    } else {
        float f = (float)_finishNum/_uploadNum;
        int n = f*100;
        _alt.title = [NSString stringWithFormat:@"上传中... %d%%", n];
    }
}

- (void)uploadFailed:(NSString *)filePath error:(NSError *)error {
    [_alt dismissWithClickedButtonIndex:0 animated:YES];
    _alt = nil;
    alert(@"上传失败", nil);
    lwError(@"uploadFailed: %@", filePath);
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
    NSDictionary *body = @{
        @"Title":_titleInput.text,
        @"Text":@"",
        @"Thumb":_thumbKey,
        @"Cover":_coverKey,
        @"CoverBlur":_coverBlurKey,
        @"Images":_images,
        @"RewardCoupon":@(_rewardCoupon),
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
        
        _gd.playerInfo.goldCoin -= _rewardCoupon;
        
        //
        [[[UIAlertView alloc] initWithTitle:@"发布成功！"
                                    message:nil
                           cancelButtonItem:[RIButtonItem itemWithLabel:@"好的" action:^{
            [self.navigationController popToViewController:_myMatchListController.tabBarController animated:YES];
            [_myMatchListController refresh];
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
@property (nonatomic) UIRefreshControl *refreshControl;
@property (nonatomic) MSWeakTimer *secTimer;
@property (nonatomic) SldGameData *gd;

@end

@implementation SldMyMatchListController

- (void)dealloc {
    [_secTimer invalidate];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _gd = [SldGameData getInstance];
    
    _myMatchListController = self;
    _matches = [NSMutableArray array];
    
    UIEdgeInsets insets = self.collectionView.contentInset;
    insets.top = 64;
    insets.bottom = 50;
    
    self.collectionView.contentInset = insets;
    self.collectionView.scrollIndicatorInsets = insets;
    self.tabBarController.automaticallyAdjustsScrollViewInsets = NO;
    
    //refresh control
    self.refreshControl = [[UIRefreshControl alloc] init];
    self.collectionView.alwaysBounceVertical = YES;
    [self.collectionView addSubview:self.refreshControl];
    [self.refreshControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
    
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

static float _scrollY = -64;

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.tabBarController.navigationItem.title = self.tabBarItem.title;
    self.tabBarController.automaticallyAdjustsScrollViewInsets = NO;
    
    UIEdgeInsets insets = self.collectionView.contentInset;
    insets.top = 64;
    insets.bottom = 50;
    
    self.collectionView.contentInset = insets;
    self.collectionView.scrollIndicatorInsets = insets;
    
    self.collectionView.contentOffset = CGPointMake(0, _scrollY);
    
    [_refreshControl endRefreshing];
    
    //refesh
    if (_gd.playerInfo && _gd.needRefreshOwnerList) {
        [self refresh];
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    _scrollY = self.collectionView.contentOffset.y;
}

- (void)refresh {
    _gd.needRefreshOwnerList = NO;
    _footer.loadMoreButton.enabled = NO;
    
    NSDictionary *body = @{@"StartId": @(0), @"BeginTime":@(0), @"Limit": @(MATCH_FETCH_LIMIT)};
    SldHttpSession *session = [SldHttpSession defaultSession];
    [session postToApi:@"match/listMine" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        _footer.loadMoreButton.enabled = YES;
        [_refreshControl endRefreshing];
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
    
    [self.navigationController pushViewController:_imagePickerController animated:YES];
}

- (void)qb_imagePickerController:(QBImagePickerController *)imagePickerController didSelectAssets:(NSArray *)assets {
    [self.navigationController popToViewController:self.tabBarController animated:NO];
    
    SldMyMatchImagePickListController* vc = (SldMyMatchImagePickListController*)[getStoryboard() instantiateViewControllerWithIdentifier:@"myUserPackEditVC"];
    
    [self.navigationController pushViewController:vc animated:YES];
    
    [vc setAssets:assets];
}

- (void)qb_imagePickerControllerDidCancel:(QBImagePickerController *)imagePickerController {
    [self.navigationController popToViewController:self.tabBarController animated:YES];
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
    if (match.extraCoupon == 0) {
        cell.rewardNumLabel.text = [NSString stringWithFormat:@"奖金：%d", match.rewardCoupon];
    } else {
        cell.rewardNumLabel.text = [NSString stringWithFormat:@"奖金：%d+%d", match.rewardCoupon, match.extraCoupon];
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

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    SldMyMatchCell *cell = sender;
    SldGameData *gd = [SldGameData getInstance];
    gd.match = cell.match;
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

@end
