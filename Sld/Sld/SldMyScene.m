//
//  SldMyScene.m
//  Sld
//
//  Created by Wei Li on 14-4-5.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldMyScene.h"
#import "SldGamePlay.h"
#import "util.h"
#import "lw/lwLog.h"
#import "giflib/gif_lib.h"

@interface TextureInfo : NSObject
    @property SKTexture *texture;
    @property Float32 duration;
@end

@implementation TextureInfo
@end


@interface SldMyScene()
    @property (nonatomic) GifFileType *gifFile;
    @property NSUInteger currFrame;
    @property SKSpriteNode *sprite;
    @property char *buff;
    @property Float32 waitSec;
    @property NSMutableArray *textures;
    @property BOOL loaded;
    @property SldGamePlay *gamePlay;
@end

@implementation SldMyScene

-(id)initWithSize:(CGSize)size {
    if (self = [super initWithSize:size]) {
        /* Setup your scene here */
        self.currFrame = -1;
        self.loaded = false;
        
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            int err = GIF_OK;
            NSString *path = getResFullPath(@"img/b.gif");
            self.gifFile = DGifOpenFileName([path UTF8String], &err);
            err = DGifSlurp(self.gifFile);
            
            dispatch_async(dispatch_get_main_queue(), ^{
                //buf
                NSUInteger bufLen = self.gifFile->SWidth*self.gifFile->SHeight*4;
                self.buff = malloc(bufLen);
                memset(self.buff, 0, bufLen);
                
                //
                self.waitSec = 0;
                self.textures = [NSMutableArray arrayWithCapacity:10];
                
                self.loaded = true;
                [self updateBuff];
            });
        });
        
        NSMutableArray *files = [NSMutableArray arrayWithCapacity:6];
        [files addObject:getResFullPath(@"img/a.gif")];
        [files addObject:getResFullPath(@"img/b.gif")];
        [files addObject:getResFullPath(@"img/c.gif")];
        [files addObject:getResFullPath(@"img/x.gif")];
        [files addObject:getResFullPath(@"img/y.gif")];
        [files addObject:getResFullPath(@"img/z.gif")];
        
        self.gamePlay = [SldGamePlay gamePlayWithScene:self files:files];
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
    
    if (!self.sprite) {
        //self.sprite = [SKSpriteNode spriteNodeWithImageNamed:@"img/x.gif"];
        self.sprite = [SKSpriteNode spriteNodeWithTexture:texture];
        self.sprite.position = CGPointMake(self.size.width*.5f, self.size.height*.5f);
        //[self.sprite setScale:.5f];
        [self addChild:self.sprite];
    } else {
        self.sprite.texture = texture;
    }
    
//    TextureInfo *texInfo = [[TextureInfo alloc] init];
//    texInfo.texture = self.sprite.texture;
//    texInfo.duration = currFrameDuration;
//    [self.textures addObject:texInfo];
}

-(void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    /* Called when a touch begins */
    //[self updateBuff];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint ptPrev = [touch previousLocationInView:self.view];
    CGPoint pt = [touch locationInView:self.view];
    
    __weak SKSpriteNode *sprite = self.sprite;
    [sprite setPosition:CGPointMake(sprite.position.x+pt.x-ptPrev.x, sprite.position.y-pt.y+ptPrev.y)];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    
}

-(void)update:(CFTimeInterval)currentTime {
    if (self.loaded) {
        self.waitSec -= 1.f/60.f;
        if (self.waitSec <= 0) {
            [self updateBuff];
        }
    }
}

@end
