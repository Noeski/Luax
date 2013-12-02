//
//  LXProject.h
//  Luax
//
//  Created by Noah Hilt on 11/24/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LXCompiler.h"

@class LXProjectGroup;
@interface LXProjectFile : NSObject
@property (nonatomic, readonly, weak) LXProjectGroup *parent;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *path;
@property (nonatomic, readonly) LXContext *context;
@property (nonatomic, strong) NSString *contents;
@end

@interface LXProjectGroup : LXProjectFile
@property (nonatomic, readonly) NSArray *children;
@end

@interface LXProject : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *path;
@property (nonatomic, readonly) LXProjectGroup *root;
@property (nonatomic, readonly) LXCompiler *compiler;

- (void)save;
- (void)load:(NSDictionary *)dictionary;
- (LXProjectGroup *)insertGroup:(LXProjectGroup *)parent atIndex:(NSInteger)index;
- (LXProjectFile *)insertFile:(LXProjectGroup *)parent atIndex:(NSInteger)index;
- (void)insertFile:(LXProjectFile *)file parent:(LXProjectGroup *)parent atIndex:(NSInteger)index;
- (void)removeFile:(LXProjectFile *)file;
- (void)setFileName:(LXProjectFile *)file name:(NSString *)name;

+ (LXProject *)createNewProject:(NSString *)name path:(NSString *)path error:(NSError **)error;
+ (LXProject *)loadProject:(NSString *)name path:(NSString *)path error:(NSError **)error;

@end
