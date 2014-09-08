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
#import "SldMyUserPackMenuController.h"

static const int USER_PACK_LIST_LIMIT = 30;
static NSArray* _assets;

//=============================
@interface SldMyMatchCell : UICollectionViewCell
@property (weak, nonatomic) IBOutlet SldAsyncImageView *imageView;
@property (weak, nonatomic) IBOutlet UILabel *playTimesLabel;
@property (nonatomic) Match* match;
@end

@implementation SldMyMatchCell

@end

//=============================
@interface SldMyMatchFooter : UICollectionReusableView
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *spin;
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
@interface SldMyMatchImagePickListController : UICollectionViewController

@end

@implementation SldMyMatchImagePickListController
- (void)setAssets :(NSArray *)assets{
    _assets = assets;
    [self.collectionView reloadData];
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

@end

//=============================
@interface SldMyMatchGamePlayTuneController : UIViewController
@property (weak, nonatomic) IBOutlet UILabel *sliderNumLabel;
@property (weak, nonatomic) IBOutlet UISlider *sliderNumSlider;
@property (weak, nonatomic) IBOutlet UILabel *challengeSecondsLabel;
@property (weak, nonatomic) IBOutlet UISlider *challengeSecondsSlider;
@property (nonatomic) NSArray *sliderNumbers;
@property (nonatomic) int sliderNum;
@property (nonatomic) NSMutableArray *challengeSecs;
@property (nonatomic) int challengeSec;
@end

static const int CHALLENGE_SEC_MIN = 3;
static const int CHALLENGE_SEC_MAX = 90;

@implementation SldMyMatchGamePlayTuneController
- (void)viewDidLoad {
    [super viewDidLoad];
    
    //
    _sliderNumbers = @[@(3), @(4), @(5), @(6), @(7)];
    _sliderNum = 5;
    int numberOfSteps = ((float)[_sliderNumbers count] - 1);
    _sliderNumSlider.maximumValue = numberOfSteps;
    _sliderNumSlider.minimumValue = 0;
    _sliderNumSlider.continuous = YES;
    _sliderNumSlider.value = 2;
    [_sliderNumSlider addTarget:self
                         action:@selector(sliderNumValueChanged:)
               forControlEvents:UIControlEventValueChanged];
    [self sliderNumValueChanged:_sliderNumSlider];
    
    //
    _challengeSecs = [NSMutableArray arrayWithCapacity:90];
    for (int i = CHALLENGE_SEC_MIN; i < CHALLENGE_SEC_MAX+1; ++i) {
        [_challengeSecs addObject:@(i)];
    }
    _challengeSec = 30;
    numberOfSteps = ((float)[_challengeSecs count] - 1);
    _challengeSecondsSlider.maximumValue = numberOfSteps;
    _challengeSecondsSlider.minimumValue = 0;
    _challengeSecondsSlider.continuous = YES;
    _challengeSecondsSlider.value = 2;
    [_challengeSecondsSlider addTarget:self
                         action:@selector(challengeSecValueChanged:)
               forControlEvents:UIControlEventValueChanged];
    [self challengeSecValueChanged:_challengeSecondsSlider];
}

- (void)sliderNumValueChanged:(UISlider *)sender {
    NSUInteger index = (NSUInteger)(_sliderNumSlider.value + 0.5);
    [_sliderNumSlider setValue:index animated:NO];
    NSNumber *number = _sliderNumbers[index]; // <-- This numeric value you want
    _sliderNum = [number intValue];
    _sliderNumLabel.text = [NSString stringWithFormat:@"拼图滑块数量：%d", _sliderNum];
}

- (void)challengeSecValueChanged:(UISlider *)sender {
    NSUInteger index = (NSUInteger)(sender.value + 0.5);
    [sender setValue:index animated:NO];
    NSNumber *number = _challengeSecs[index]; // <-- This numeric value you want
    _challengeSec = [number intValue];
    _challengeSecondsLabel.text = [NSString stringWithFormat:@"挑战目标：%d秒", _challengeSec];
}

- (IBAction)onPlusButton:(id)sender {
    _challengeSec++;
    if (_challengeSec > CHALLENGE_SEC_MAX) {
        _challengeSec = CHALLENGE_SEC_MAX;
    }
    NSInteger index = [_challengeSecs indexOfObject:@(_challengeSec)];
    [_challengeSecondsSlider setValue:index animated:NO];
    
    _challengeSecondsLabel.text = [NSString stringWithFormat:@"挑战目标：%d秒", _challengeSec];
}

- (IBAction)onMinusButton:(id)sender {
    _challengeSec--;
    if (_challengeSec < CHALLENGE_SEC_MIN) {
        _challengeSec = CHALLENGE_SEC_MIN;
    }
    NSInteger index = [_challengeSecs indexOfObject:@(_challengeSec)];
    [_challengeSecondsSlider setValue:index animated:NO];
    
    _challengeSecondsLabel.text = [NSString stringWithFormat:@"挑战目标：%d秒", _challengeSec];
}



@end

//=============================
@interface SldMyMatchSettingsController : UIViewController <UITextFieldDelegate, UITextViewDelegate, QiniuUploadDelegate>
@property (weak, nonatomic) IBOutlet UISlider *slider;
@property (weak, nonatomic) IBOutlet UILabel *priceLable;
@property (weak, nonatomic) IBOutlet UITextField *titleInput;
@property (weak, nonatomic) IBOutlet UITextView *textInput;
@property (weak, nonatomic) IBOutlet UILabel *sliderNumLabel;
@property (weak, nonatomic) IBOutlet UISlider *sliderNumSlider;
@property (nonatomic) int couponReward;
@property (nonatomic) NSArray *numbers;
@property (nonatomic) NSArray *sliderNumbers;
@property (nonatomic) int sliderNum;
@property (nonatomic) QiniuSimpleUploader* uploader;
@property (nonatomic) UIAlertView *alt;
@property (nonatomic) int uploadNum;
@property (nonatomic) int finishNum;
@property (nonatomic) NSString *thumbKey;
@property (nonatomic) NSString *coverKey;
@property (nonatomic) NSString *coverBlurKey;
@property (nonatomic) NSMutableArray *images;
@end

@implementation SldMyMatchSettingsController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:50];
    for (int i = 0; i < 100; i++) {
        [array addObject:@(i*100+100)];
    }
    _numbers = [NSArray arrayWithArray:array];
    _couponReward = 50;
    NSInteger numberOfSteps = ((float)[_numbers count] - 1);
    _slider.maximumValue = numberOfSteps;
    _slider.minimumValue = 0;
    _slider.continuous = YES;
    _slider.value = 0;
    [_slider addTarget:self
               action:@selector(valueChanged:)
     forControlEvents:UIControlEventValueChanged];
    
    _titleInput.delegate = self;
    _textInput.delegate = self;
    [self valueChanged:_slider];
    
    //
    _sliderNumbers = @[@(3), @(4), @(5), @(6), @(7), @(8), @(9)];
    _sliderNum = 5;
    numberOfSteps = ((float)[_sliderNumbers count] - 1);
    _sliderNumSlider.maximumValue = numberOfSteps;
    _sliderNumSlider.minimumValue = 0;
    _sliderNumSlider.continuous = YES;
    _sliderNumSlider.value = 2;
    [_sliderNumSlider addTarget:self
                action:@selector(sliderNumValueChanged:)
      forControlEvents:UIControlEventValueChanged];
    [self sliderNumValueChanged:_sliderNumSlider];
    
}

- (void)valueChanged:(UISlider *)sender {
    NSUInteger index = (NSUInteger)(_slider.value + 0.5);
    [_slider setValue:index animated:NO];
    NSNumber *number = _numbers[index]; // <-- This numeric value you want
    _couponReward = [number intValue];
    _priceLable.text = [NSString stringWithFormat:@"提供%d奖票，需要%d水晶", _couponReward, _couponReward];
}

- (void)sliderNumValueChanged:(UISlider *)sender {
    NSUInteger index = (NSUInteger)(_sliderNumSlider.value + 0.5);
    [_sliderNumSlider setValue:index animated:NO];
    NSNumber *number = _sliderNumbers[index]; // <-- This numeric value you want
    _sliderNum = [number intValue];
    _sliderNumLabel.text = [NSString stringWithFormat:@"拼图滑块数量：%d", _sliderNum];
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
    _alt = alertNoButton(@"上传中...");
    
    _images = [NSMutableArray array];
    
    int i = 0;
    NSMutableArray *filePathes = [NSMutableArray array];
    NSMutableArray *fileKeys = [NSMutableArray array];
    
    for (ALAsset *asset in _assets) {
        UIImage *image = [[UIImage alloc] initWithCGImage:asset.defaultRepresentation.fullScreenImage];
        
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
        NSString *filePath = makeTempPath(fileName);
        [filePathes addObject:filePath];
        [data writeToFile:filePath atomically:YES];
        
        //key
        NSString *key = [NSString stringWithFormat:@"%@.jpg", [SldUtil sha1WithData:data]];
        [fileKeys addObject:key];
        [_images addObject:@{@"File":fileName, @"Key":key}];
        
        //blur first image
        if (i == 0) {
            //image = [image applyLightEffect];
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
}

- (void)addUserPack {
    _alt.title = @"生成中...";
    
//    [_alt dismissWithClickedButtonIndex:0 animated:NO];
//    alert(@"上传成功", nil);
//    
    
    SldHttpSession *session = [SldHttpSession defaultSession];
    NSDictionary *body = @{
        @"Title":_titleInput.text,
        @"Text":_textInput.text,
        @"Thumb":_thumbKey,
        @"Cover":_coverKey,
        @"CoverBlur":_coverBlurKey,
        @"Images":_images,
        @"CouponReward":@(_couponReward),
        @"SliderNum":@(_sliderNum),
        @"BeginTime":@"",
    };
    [session postToApi:@"match/new" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
        if (error) {
            [_alt dismissWithClickedButtonIndex:0 animated:NO];
            _alt = nil;
            alertHTTPError(error, data);
            return;
        }
        
//        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
//        if (error) {
//            lwError("Json error:%@", [error localizedDescription]);
//            [_alt dismissWithClickedButtonIndex:0 animated:YES];
//            _alt = nil;
//            return;
//        }

        [_alt dismissWithClickedButtonIndex:0 animated:YES];
        alert(@"发布成功", nil);
    }];
}

@end

//=============================
@interface SldMyMatchListController()

@property (nonatomic) NSMutableArray *matches;
@property (nonatomic) BOOL reachEnd;
@property (nonatomic) BOOL scrollUnderBottom;
@property (nonatomic) SldMyMatchFooter* footer;
@property (nonatomic) QBImagePickerController *imagePickerController;

@end

@implementation SldMyMatchListController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    _matches = [NSMutableArray array];
    
    UIEdgeInsets insets = self.collectionView.contentInset;
    insets.top = 64;
    insets.bottom = 50;
    
    self.collectionView.contentInset = insets;
    self.collectionView.scrollIndicatorInsets = insets;
    self.tabBarController.automaticallyAdjustsScrollViewInsets = NO;
    
    //
    if (_matches.count == 0) {
        NSDictionary *body = @{@"StartId": @(0), @"BeginTime":@(0), @"Limit": @(USER_PACK_LIST_LIMIT)};
        SldHttpSession *session = [SldHttpSession defaultSession];
        [session postToApi:@"match/listMine" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
            if (error) {
                alertHTTPError(error, data);
                return;
            }
            NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
            if (error) {
                lwError("Json error:%@", [error localizedDescription]);
                return;
            }
            
            if (array.count < USER_PACK_LIST_LIMIT) {
                _reachEnd = YES;
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
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
//    self.tabBarController.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addPack)];
    self.tabBarController.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"发布新游戏" style:UIBarButtonItemStylePlain target:self action:@selector(addPack)];
}

- (void)addPack {
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
    cell.match = match;
    return cell;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath {
    if (kind == UICollectionElementKindSectionFooter) {
        _footer = [collectionView dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter withReuseIdentifier:@"myMatchFooter" forIndexPath:indexPath];
        return _footer;
    }
    return nil;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (_matches.count == 0 || _reachEnd) {
        return;
    }
    
    if (scrollView.contentSize.height > scrollView.frame.size.height
        &&(scrollView.contentOffset.y + scrollView.frame.size.height) > scrollView.contentSize.height) {
        if (!_scrollUnderBottom) {
            _scrollUnderBottom = YES;
            if (![_footer.spin isAnimating]) {
                [_footer.spin startAnimating];
                
                SInt64 startId = 0;
                if (_matches.count > 0) {
                    Match *match = [_matches lastObject];
                    startId = match.id;
                }
//
//                NSDictionary *body = @{@"StartId": @(startId), @"Limit": @(ADVICE_LIMIT)};
//                SldHttpSession *session = [SldHttpSession defaultSession];
//                [session postToApi:@"etc/listAdvice" body:body completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
//                    [_bottomRefresh endRefreshing];
//                    if (error) {
//                        alertHTTPError(error, data);
//                        return;
//                    }
//                    NSArray *array = [NSJSONSerialization JSONObjectWithData:data options:0 error:&error];
//                    if (error) {
//                        lwError("Json error:%@", [error localizedDescription]);
//                        return;
//                    }
//                    
//                    if (array.count < ADVICE_LIMIT) {
//                        _reachEnd = YES;
//                    }
//                    
//                    NSMutableArray *insertIndexPathes = [NSMutableArray array];
//                    for (NSDictionary *dict in array) {
//                        AdviceData *adviceData = [AdviceData adviceDataWithDictionary:dict];
//                        [_adviceDatas addObject:adviceData];
//                        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:_adviceDatas.count-1 inSection:1];
//                        [insertIndexPathes addObject:indexPath];
//                    }
//                    [self.tableView insertRowsAtIndexPaths:insertIndexPathes withRowAnimation:UITableViewRowAnimationAutomatic];
//                }];
            }
        }
        
    } else {
        _scrollUnderBottom = NO;
    }
}

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    SldMyMatchCell *cell = sender;
    SldGameData *gd = [SldGameData getInstance];
    gd.match = cell.match;
}

@end
