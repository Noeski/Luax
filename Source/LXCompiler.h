//
//  LXCompiler.h
//  LuaX
//
//  Created by Noah Hilt on 8/8/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXParser.h"
#import "LXNode.h"
#import "LXToken.h"

@class LXContext;

@interface LXCompilerError : NSObject
@property (nonatomic, strong) NSString *error;
@property (nonatomic, assign) NSRange range;
@property (nonatomic, assign) NSInteger line;
@property (nonatomic, assign) NSInteger column;
@end

@interface LXCompiler : NSObject
@property (nonatomic, strong) LXScope *globalScope;
@property (nonatomic, strong) NSMutableDictionary *fileMap;
@property (nonatomic, strong) NSMutableDictionary *baseTypeMap;
@property (nonatomic, strong) NSMutableDictionary *typeMap;

- (LXContext *)compilerContext:(NSString *)name;

- (void)compile:(NSString *)name string:(NSString *)string;
- (void)save;

@end

@interface LXContext : NSObject
@property (nonatomic, strong) LXCompiler *compiler;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) LXParser *parser;
@property (nonatomic, strong) LXScope *scope;
@property (nonatomic, strong) LXNode *block;
@property (nonatomic, strong) NSMutableArray *errors;

- (id)initWithName:(NSString *)name compiler:(LXCompiler *)compiler;

- (void)compile:(NSString *)string;
- (void)reportErrors;
@end
