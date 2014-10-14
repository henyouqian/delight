//
//  QBAssetsCollectionViewCell.m
//  QBImagePickerController
//
//  Created by Tanaka Katsuma on 2013/12/31.
//  Copyright (c) 2013年 Katsuma Tanaka. All rights reserved.
//

#import "QBAssetsCollectionViewCell.h"

// Views
#import "QBAssetsCollectionOverlayView.h"
#import "QBAssetsCollectionVideoIndicatorView.h"

@interface QBAssetsCollectionViewCell ()

@property (nonatomic, strong) UIImageView *imageView;
@property (nonatomic, strong) QBAssetsCollectionOverlayView *overlayView;
@property (nonatomic, strong) QBAssetsCollectionVideoIndicatorView *videoIndicatorView;

@property (nonatomic, strong) UIImage *blankImage;
@property (nonatomic) UILabel *gifLabel;
@property (nonatomic) UILabel *sizeLabel;

@end

@implementation QBAssetsCollectionViewCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    
    if (self) {
        self.showsOverlayViewWhenSelected = YES;
        
        // Create a image view
        UIImageView *imageView = [[UIImageView alloc] initWithFrame:self.contentView.bounds];
        //        imageView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        
        [self.contentView addSubview:imageView];
        self.imageView = imageView;
    }
    
    // gif label
    UIColor *bgColor = [UIColor colorWithRed:0.2 green:0.2 blue:0.2 alpha:0.5];
    _gifLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 30, 12)];
    [_imageView addSubview:_gifLabel];
    _gifLabel.backgroundColor = bgColor;
    _gifLabel.text = @"GIF";
    _gifLabel.font = [_gifLabel.font fontWithSize:12];
    _gifLabel.textColor = [UIColor whiteColor];
    _gifLabel.textAlignment = NSTextAlignmentCenter;
    _gifLabel.hidden = YES;
    
    
    _sizeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 12, 12)];
    [_imageView addSubview:_sizeLabel];
    _sizeLabel.backgroundColor = bgColor;
    _sizeLabel.text = @"横";
    _sizeLabel.font = [_sizeLabel.font fontWithSize:12];
    _sizeLabel.textColor = [UIColor whiteColor];
    _sizeLabel.textAlignment = NSTextAlignmentCenter;
    
    return self;
}

- (void)setSelected:(BOOL)selected
{
    [super setSelected:selected];
    
    // Show/hide overlay view
    if (selected && self.showsOverlayViewWhenSelected) {
        [self showOverlayView];
    } else {
        [self hideOverlayView];
    }
}


#pragma mark - Overlay View

- (void)showOverlayView
{
    [self hideOverlayView];
    
    QBAssetsCollectionOverlayView *overlayView = [[QBAssetsCollectionOverlayView alloc] initWithFrame:self.contentView.bounds];
    overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [self.contentView addSubview:overlayView];
    self.overlayView = overlayView;
}

- (void)hideOverlayView
{
    if (self.overlayView) {
        [self.overlayView removeFromSuperview];
        self.overlayView = nil;
    }
}


#pragma mark - Video Indicator View

- (void)showVideoIndicatorView
{
    CGFloat height = 19.0;
    CGRect frame = CGRectMake(0, CGRectGetHeight(self.bounds) - height, CGRectGetWidth(self.bounds), height);
    QBAssetsCollectionVideoIndicatorView *videoIndicatorView = [[QBAssetsCollectionVideoIndicatorView alloc] initWithFrame:frame];
    videoIndicatorView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    videoIndicatorView.duration = [[self.asset valueForProperty:ALAssetPropertyDuration] doubleValue];
    
    [self.contentView addSubview:videoIndicatorView];
    self.videoIndicatorView = videoIndicatorView;
}

- (void)hideVideoIndicatorView
{
    if (self.videoIndicatorView) {
        [self.videoIndicatorView removeFromSuperview];
        self.videoIndicatorView = nil;
    }
}


#pragma mark - Accessors

- (void)setAsset:(ALAsset *)asset
{
    _asset = asset;
    
    // Update view
    CGImageRef thumbnailImageRef = [asset thumbnail];
    
    if (thumbnailImageRef) {
        self.imageView.image = [UIImage imageWithCGImage:thumbnailImageRef];
    } else {
        self.imageView.image = [self blankImage];
    }
    
    // Show video indicator if the asset is video
    if ([[asset valueForProperty:ALAssetPropertyType] isEqualToString:ALAssetTypeVideo]) {
        [self showVideoIndicatorView];
    } else {
        [self hideVideoIndicatorView];
    }
    
    // check gif
    ALAssetRepresentation *repr = asset.defaultRepresentation;
    
    float width = 16;
    float x = self.frame.size.width - width;
    float y = self.frame.size.height - 12;
    _sizeLabel.frame = CGRectMake(x, y, width, 12);
    if (repr.dimensions.width > repr.dimensions.height) {
        _sizeLabel.hidden = NO;
    } else {
        _sizeLabel.hidden = YES;
    }
    
    _gifLabel.frame = CGRectMake(0, y, 26, 12);
    NSRange range = [repr.filename rangeOfString:@".GIF"];
    if (range.location == NSNotFound) {
        _gifLabel.hidden = YES;
    } else {
        _gifLabel.hidden = NO;
    }
//    NSLog(@"%@", repr.filename);
//    unsigned char bytes[4];
//    [repr getBytes:bytes fromOffset:0 length:4 error:nil];
//    if (bytes[0]=='G' && bytes[1]=='I' && bytes[2]=='F') {
//        _gifLabel.hidden = NO;
//    } else {
//        _gifLabel.hidden = YES;
//    }
}

- (UIImage *)blankImage
{
    if (_blankImage == nil) {
        CGSize size = CGSizeMake(100.0, 100.0);
        UIGraphicsBeginImageContextWithOptions(size, NO, 0.0);
        
        [[UIColor colorWithWhite:(240.0 / 255.0) alpha:1.0] setFill];
        UIRectFill(CGRectMake(0, 0, size.width, size.height));
        
        _blankImage = UIGraphicsGetImageFromCurrentImageContext();
        
        UIGraphicsEndImageContext();
    }
    
    return _blankImage;
}

@end
