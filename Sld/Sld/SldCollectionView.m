//
//  SldCollectionView.m
//  Sld
//
//  Created by Wei Li on 14-5-6.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldCollectionView.h"

@implementation SldCollectionView

- (void)setContentInset:(UIEdgeInsets)contentInset {
    if (self.tracking) {
        CGFloat diff = contentInset.top - self.contentInset.top;
        CGPoint translation = [self.panGestureRecognizer translationInView:self];
        translation.y -= diff * 3.0 / 2.0;
        [self.panGestureRecognizer setTranslation:translation inView:self];
    }
    [super setContentInset:contentInset];
}

@end
