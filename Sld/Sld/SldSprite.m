//
//  SldSprite.m
//  Sld
//
//  Created by Wei Li on 14-4-11.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldSprite.h"
#import "giflib/gif_lib.h"

@interface SldSprite()
@property (nonatomic) GifFileType *gifFile;
@property NSUInteger currFrame;
@property char *buff;
@property Float32 waitSec;
@property NSMutableArray *textures;
@property BOOL loaded;
@end

@implementation SldSprite

+(instancetype)spriteWithPath:(NSString*)path {
    return [[SldSprite alloc] initWithPath:path];
}

-(instancetype)initWithPath:(NSString*)path {
    self.gifFile = nil;
    if ([[path lowercaseString] hasSuffix:@".gif"]) {
        self.currFrame = -1;
        self.loaded = false;
        
        int err = GIF_OK;
        self.gifFile = DGifOpenFileName([path UTF8String], &err);
        err = DGifSlurp(self.gifFile);
        
        NSUInteger bufLen = self.gifFile->SWidth*self.gifFile->SHeight*4;
        self.buff = malloc(bufLen);
        memset(self.buff, 0, bufLen);
        
        self.waitSec = 0;
        self.textures = [NSMutableArray arrayWithCapacity:10];
        
        self.loaded = true;
        SKTexture *texture = [self updateBuff];
        
        self = [super initWithTexture:texture];
    } else {
        self = [super initWithImageNamed:path];
    }
    
    return self;
}

-(BOOL)update {
    if (self.gifFile && self.loaded) {
        self.waitSec -= 1.f/60.f;
        if (self.waitSec <= 0) {
            [self updateBuff];
            return YES;
        }
    }
    return NO;
}

-(void)dealloc {
    if (self.gifFile && self.loaded) {
        DGifCloseFile(self.gifFile);
        free(self.buff);
    }
}

-(SKTexture*)updateBuff {
    BOOL onInit = self.currFrame == -1;
    ++self.currFrame;
    if (self.currFrame >= self.gifFile->ImageCount) {
        self.currFrame = 0;
    }
    
    //    if (self.currFrame < [self.textures count]) {
    //        TextureInfo *texInfo = self.textures[self.currFrame];
    //        self.sprite.texture = texInfo.texture;
    //        self.waitSec += texInfo.duration;
    //        return;
    //    }
    
    SavedImage *img = self.gifFile->SavedImages + self.currFrame;
    GifImageDesc *imgDesc = &img->ImageDesc;
    ColorMapObject *colorMap = imgDesc->ColorMap;
    GifByteType *imgBuf = img->RasterBits;
    if (!colorMap) {
        colorMap = _gifFile->SColorMap;
    }
    
    //ext code
    Float32 currFrameDuration = 0;
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
    self.waitSec += currFrameDuration;
    int disposalMode = gcb.DisposalMode;
    
    //read pixel
    int i = 0;
    GifWord gifWidth = self.gifFile->SWidth;
    GifWord gifHeight = self.gifFile->SHeight;
    GifWord top = imgDesc->Top;
    GifWord height = imgDesc->Height;
    GifWord left = imgDesc->Left;
    GifWord width = imgDesc->Width;
    CGSize size = CGSizeMake(gifWidth, gifHeight);
    GifWord yMax = top + height;
    GifWord xMax = left + width;
    char *buf = self.buff;
    if (hasTrans) {
        for (int y = top; y < yMax; ++y) {
            int revY = gifHeight - y - 1;
            int offset = gifWidth*revY;
            for (GifWord x = left; x < xMax; ++x) {
                unsigned char colorIdx = imgBuf[i];
                if (colorIdx == transIdx) {
                    if (disposalMode == DISPOSE_BACKGROUND) {
                        GifColorType *bgColor = &(colorMap->Colors[_gifFile->SBackGroundColor]);
                        //GifByteType c[4] = {bgColor->Red, bgColor->Green, bgColor->Blue, 0xff};
                        //memcpy(self.buff+(offset+x)*4, c, colorSize);
                        char *p = self.buff+((offset+x)<<2);
                        p[0] = bgColor->Red;
                        p[1] = bgColor->Green;
                        p[2] = bgColor->Blue;
                        p[3] = 0xff;
                    }
                    ++i;
                    continue;
                }
                
                GifColorType *color = &(colorMap->Colors[colorIdx]);
                //                GifByteType c[4] = {color->Red, color->Green, color->Blue, 0xff};
                //                memcpy(self.buff+(offset+x)*4, c, colorSize);
                char *p = buf+((offset+x)<<2);
                p[0] = color->Red;
                p[1] = color->Green;
                p[2] = color->Blue;
                p[3] = 0xff;
                ++i;
            }
        }
    } else {
        for (GifWord y = top; y < yMax; ++y) {
            GifWord revY = gifHeight - y - 1;
            int offset = gifWidth*revY;
            for (GifWord x = left; x < xMax; ++x) {
                unsigned char colorIdx = imgBuf[i];
                GifColorType *color = &(colorMap->Colors[colorIdx]);
                char *p = buf+((offset+x)<<2);
                p[0] = color->Red;
                p[1] = color->Green;
                p[2] = color->Blue;
                p[3] = 0xff;
                ++i;
            }
        }
    }
    
    NSData *data = [NSData dataWithBytes:self.buff length:gifWidth*gifHeight*4];
    SKTexture *texture = [SKTexture textureWithData:data size:size];
    
    if (!onInit) {
        self.texture = texture;
    }
    return texture;
    
    //    TextureInfo *texInfo = [[TextureInfo alloc] init];
    //    texInfo.texture = self.sprite.texture;
    //    texInfo.duration = currFrameDuration;
    //    [self.textures addObject:texInfo];
}

@end
