//
//  LXProject.h
//  Luax
//
//  Created by Noah Hilt on 11/24/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "LXCompiler.h"

@class LXProject;
@class LXProjectFile;
@protocol LXProjectDelegate<NSObject>
@optional
- (void)project:(LXProject *)project file:(LXProjectFile *)file didBreakAtLine:(NSInteger)line error:(BOOL)error;
- (void)projectFinishedRunning:(LXProject *)project;
@end

@class LXProjectGroup;
@interface LXProjectFile : NSObject
@property (nonatomic, readonly) NSString *uid;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *path;
@property (nonatomic, readonly) LXContext *context;
@property (nonatomic, readonly) NSDictionary *breakpoints;
@property (nonatomic, strong) NSString *contents;
@property (nonatomic, strong) NSString *compiledContents;

- (BOOL)isCompiled;
- (BOOL)hasErrors;
- (void)addBreakpoint:(NSInteger)line;
- (void)removeBreakpoint:(NSInteger)line;
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
@property (nonatomic, weak) id<LXProjectDelegate> delegate;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *path;
@property (nonatomic, readonly) NSArray *files;
@property (nonatomic, readonly) LXProjectGroup *root;
@property (nonatomic, readonly) LXCompiler *compiler;

- (void)save;
- (void)load:(NSDictionary *)dictionary;
- (void)compile;
- (void)clean;
- (void)run;
- (void)stopExecution;
- (void)continueExecution;
- (void)pauseExecution;
- (void)stepInto;
- (void)stepOver;
- (void)stepOut;
- (BOOL)isRunning;
- (LXProjectGroup *)insertGroup:(LXProjectGroup *)parent atIndex:(NSInteger)index;
- (LXProjectFileReference *)insertFile:(LXProjectGroup *)parent atIndex:(NSInteger)index;
- (void)insertFile:(LXProjectFileReference *)file parent:(LXProjectGroup *)parent atIndex:(NSInteger)index;
- (void)removeFile:(LXProjectFileReference *)file;
- (void)setFileName:(LXProjectFileReference *)file name:(NSString *)name;

+ (LXProject *)createNewProject:(NSString *)name path:(NSString *)path error:(NSError **)error;
+ (LXProject *)loadProject:(NSString *)name path:(NSString *)path error:(NSError **)error;

@end
