//
//  SldMyScene.m
//  Sld
//
//  Created by Wei Li on 14-4-5.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldMyScene.h"
#import "giflib/gif_lib.h"

@interface SldMyScene()

@property GifFileType *gifFile;
@property NSUInteger currFrame;
@property SKSpriteNode *sprite;
@property char *buff;
@property Float32 waitSec;

@end

@implementation SldMyScene

//static int pwr2Size(int in) {
//    int out = 2;
//    while (1) {
//        if (out >= in)
//            return out;
//        out *= 2;
//    }
//}

-(id)initWithSize:(CGSize)size {
    if (self = [super initWithSize:size]) {
        /* Setup your scene here */
        self.currFrame = -1;
        int err = GIF_OK;
        NSString *path = [[NSBundle mainBundle] pathForResource:@"img/y.gif" ofType:nil];
        self.gifFile = DGifOpenFileName([path UTF8String], &err);
        err = DGifSlurp(self.gifFile);
        
        //buf
        NSUInteger bufLen = self.gifFile->SWidth*self.gifFile->SHeight*4;
        self.buff = malloc(bufLen);
        memset(self.buff, 0, bufLen);
        
        self.waitSec = 0;
        
        [self updateBuff];
    }
    return self;
}

-(void)dealloc {
    DGifCloseFile(self.gifFile);
    free(self.buff);
}

-(void)updateBuff {
    ++self.currFrame;
    if (self.currFrame >= self.gifFile->ImageCount) {
        self.currFrame = 0;
    }
    
    SavedImage *img = self.gifFile->SavedImages + self.currFrame;
    GifImageDesc *imgDesc = &img->ImageDesc;
    ColorMapObject *colorMap = imgDesc->ColorMap;
    GifByteType *imgBuf = img->RasterBits;
    if (!colorMap) {
        colorMap = _gifFile->SColorMap;
    }
    
    //ext code
    double currFrameDuration = 0;
    bool hasTrans = false;
    unsigned char transIdx = 0;
    GraphicsControlBlock gcb;
    for (int i = 0; i < img->ExtensionBlockCount; ++i) {
        ExtensionBlock *extBlk = img->ExtensionBlocks + i;
        if (extBlk->Function == GRAPHICS_EXT_FUNC_CODE) {
            GifByteType *ext = extBlk->Bytes;
            if( ext[0] & 1 ) {
                hasTrans = true;
                transIdx = ext[3];
            }
            DGifExtensionToGCB(extBlk->ByteCount, extBlk->Bytes, &gcb);
            currFrameDuration = gcb.DelayTime * 0.01;
            break;
        }
    }
    self.waitSec += (Float32)currFrameDuration;
    
    //read pixel
    int i = 0;
    
    for (GifWord y = imgDesc->Top; y < imgDesc->Top + imgDesc->Height; ++y) {
        for (GifWord x = imgDesc->Left; x < imgDesc->Left+imgDesc->Width; ++x) {
            unsigned char colorIdx = imgBuf[i];
            GifWord revY = self.gifFile->SHeight - y;
            
            if (hasTrans && colorIdx == transIdx) {
                if (gcb.DisposalMode == DISPOSE_BACKGROUND) {
                    GifColorType *bgColor = &(colorMap->Colors[_gifFile->SBackGroundColor]);
                    GifByteType c[4] = {bgColor->Red, bgColor->Green, bgColor->Blue, 0xff};
                    //NSRange range = {(self.gifFile->SWidth*y+x)*4, sizeof(GifByteType)*4};
                    //[self.buf replaceBytesInRange:range withBytes:c length:sizeof(GifByteType)*4];
                    memcpy(self.buff+(self.gifFile->SWidth*revY+x)*4, c, sizeof(GifByteType)*4);
                }
                ++i;
                continue;
            }
            
            GifColorType *color = &(colorMap->Colors[imgBuf[i]]);
            GifByteType c[4] = {color->Red, color->Green, color->Blue, 0xff};
            //NSRange range = {(self.gifFile->SWidth*y+x)*4, sizeof(GifByteType)*4};
            //[self.buf replaceBytesInRange:range withBytes:c length:sizeof(GifByteType)*4];
            memcpy(self.buff+(self.gifFile->SWidth*revY+x)*4, c, sizeof(GifByteType)*4);
            ++i;
        }
    }
    
    NSData *buf = [NSData dataWithBytes:self.buff length:self.gifFile->SWidth*self.gifFile->SHeight*4];
    SKTexture *texture = [SKTexture textureWithData:buf size:CGSizeMake(self.gifFile->SWidth, self.gifFile->SHeight)];
    
    if (!self.sprite) {
        //self.sprite = [SKSpriteNode spriteNodeWithImageNamed:@"img/x.gif"];
        self.sprite = [SKSpriteNode spriteNodeWithTexture:texture];
        self.sprite.position = CGPointMake(self.size.width*.5f, self.size.height*.5f);
        [self addChild:self.sprite];
    } else {
        self.sprite.texture = texture;
    }
    
    //action
//    SKAction *wait = [SKAction waitForDuration:currFrameDuration];
//    SKAction *act = [SKAction runBlock:^{
//        [self updateBuff];
//    }];
//    SKAction *seq = [SKAction sequence:@[wait, act]];
//    [self removeAllActions];
//    [self runAction:seq];
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    /* Called when a touch begins */
    //[self updateBuff];
}

-(void)update:(CFTimeInterval)currentTime {
    self.waitSec -= 1.f/60.f;
    if (self.waitSec <= 0) {
        [self updateBuff];
    }
}

@end
