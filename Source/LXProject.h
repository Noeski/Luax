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
@property (nonatomic, readonly) NSString *uid;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *path;
@property (nonatomic, readonly) LXContext *context;
@property (nonatomic, strong) NSString *contents;

- (BOOL)isCompiled;
- (BOOL)hasErrors;
@end

@interface LXProjectFileReference : NSObject
@property (nonatomic, weak, readonly) LXProjectFile *file;
@property (nonatomic, weak, readonly) LXProjectGroup *parent;
@property (nonatomic, readonly) NSString *name;
@end

@interface LXProjectGroup : LXProjectFileReference
@property (nonatomic, readonly) NSArray *children;
@end

@interface LXProject : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *path;
@property (nonatomic, readonly) NSArray *files;
@property (nonatomic, readonly) LXProjectGroup *root;
@property (nonatomic, readonly) LXCompiler *compiler;

- (void)save;
- (void)load:(NSDictionary *)dictionary;
- (void)compile;
- (LXProjectGroup *)insertGroup:(LXProjectGroup *)parent atIndex:(NSInteger)index;
- (LXProjectFileReference *)insertFile:(LXProjectGroup *)parent atIndex:(NSInteger)index;
- (void)insertFile:(LXProjectFileReference *)file parent:(LXProjectGroup *)parent atIndex:(NSInteger)index;
- (void)removeFile:(LXProjectFileReference *)file;
- (void)setFileName:(LXProjectFileReference *)file name:(NSString *)name;

+ (LXProject *)createNewProject:(NSString *)name path:(NSString *)path error:(NSError **)error;
+ (LXProject *)loadProject:(NSString *)name path:(NSString *)path error:(NSError **)error;

@end
