//
//  SldDb.m
//  Sld
//
//  Created by Wei Li on 14-4-24.
//  Copyright (c) 2014年 Wei Li. All rights reserved.
//

#import "SldDb.h"

@implementation SldDb

+ (instancetype)defaultDb {
    static SldDb *inst = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        inst = [[self alloc] init];
        
        NSString *docsPath = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES)[0];
        NSString *dbFileName = @"db/sld.sqlite";
        NSString *dbPath   = [docsPath stringByAppendingPathComponent:dbFileName];
        NSFileManager *fileMgr = [NSFileManager defaultManager];
        [fileMgr createDirectoryAtPath:[docsPath stringByAppendingPathComponent:@"db"] withIntermediateDirectories:YES attributes:nil error:nil];
        
        BOOL dbExist = [fileMgr fileExistsAtPath:dbPath];
        
        inst.fmdb = [FMDatabase databaseWithPath:dbPath];
        if (![inst.fmdb open]) {
            lwError("fmdb open failed.%@", [inst.fmdb lastErrorMessage]);
        }
        
        BOOL needUpdate = NO;
        NSString *appVer = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
        if (dbExist) {
            FMResultSet *r = [inst.fmdb executeQuery:@"SELECT value FROM kv WHERE key=?", @"version"];
            if ([r next]) {
                NSString *dbVer = [r stringForColumnIndex:0];
                if ([dbVer compare:appVer] != 0) {
                    needUpdate = YES;
                }
            } else {
                needUpdate = YES;
            }
        } else {
            needUpdate = YES;
        }
        
        if (needUpdate) {
            NSString *createSqlPath = [[NSBundle mainBundle] pathForResource:@"db/create.sql" ofType:nil];
            NSString *fh = [NSString stringWithContentsOfFile:createSqlPath encoding:NSUTF8StringEncoding error:NULL];
            for (NSString *l in [fh componentsSeparatedByString:@";\n"]) {
                if ([l length] > 0) {
                    NSMutableString *line = [NSMutableString stringWithString:l];
                    [line appendString:@";"];
                    lwInfo("%@", line);
                    
                    [inst.fmdb executeUpdate:line];
                }
            }
            [inst.fmdb executeUpdate:@"REPLACE INTO kv VALUES (?, ?)", @"version", appVer];
        }
    });
    return inst;
}

- (NSData*)getValue:(NSString*)key {
    FMDatabase *db = [SldDb defaultDb].fmdb;
    FMResultSet *rs = [db executeQuery:@"SELECT value FROM kv WHERE key = ?", key];
    if ([rs next]) {
        NSData *data = [rs dataForColumnIndex:0];
        return data;
    }
    return nil;
}

- (BOOL)setKey:(NSString*)key value:(NSData*)value {
    FMDatabase *db = [SldDb defaultDb].fmdb;
    BOOL ok = [db executeUpdate:@"REPLACE INTO kv (key, value) VALUES(?, ?)", key, value];
    if (!ok) {
        lwError("set kv error: key=%@, value=%@", key, value);
    }
    return ok;
}

@end
