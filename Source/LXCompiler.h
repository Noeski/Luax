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
@property (nonatomic, assign) BOOL isWarning;
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

@interface LXContext : NSObject {
    LXToken *_previous;
    LXToken *_current;
    LXToken *_next;
    
    LXScope *_currentScope;
    
    NSMutableArray *definedTypes;
    NSMutableArray *definedVariables;
}

@property (nonatomic, strong) LXCompiler *compiler;
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) LXParser *parser;
@property (nonatomic, strong) LXScope *scope;
@property (nonatomic, strong) LXNode *block;
@property (nonatomic, strong) NSMutableArray *errors;
@property (nonatomic, strong) NSMutableArray *warnings;
@property (nonatomic, assign) NSInteger currentTokenIndex;
@property (nonatomic, readonly) NSInteger nextTokenIndex;

- (id)initWithName:(NSString *)name compiler:(LXCompiler *)compiler;

- (void)compile:(NSString *)string;
- (NSArray *)completionsForLocation:(NSInteger)location range:(NSRangePointer)range;
- (LXTokenNode *)firstToken;
- (LXTokenNode *)tokenForLine:(NSInteger)line;
- (void)addError:(NSString *)error range:(NSRange)range line:(NSInteger)line column:(NSInteger)column;
- (void)addWarning:(NSString *)warning range:(NSRange)range line:(NSInteger)line column:(NSInteger)column;
- (void)reportErrors;
- (LXClass *)findType:(NSString *)name;
- (LXVariable *)createGlobalVariable:(NSString *)name type:(LXClass *)type;
- (LXVariable *)createGlobalFunction:(NSString *)name;
- (void)declareType:(LXClass *)type;
- (LXClass *)declareType:(NSString *)name objectType:(LXClass *)objectType;
- (LXScope *)createScope:(BOOL)openScope;
- (void)finishScope;
- (void)pushScope:(LXScope *)scope;
- (void)popScope;
- (LXScope *)currentScope;
- (LXToken *)currentToken;
- (LXToken *)previousToken;
- (LXToken *)nextToken;
- (LXToken *)consumeToken;
- (NSString *)tokenValue:(LXToken *)token;
- (void)closeBlock:(LXTokenType)type;
- (void)skipLine;
- (id)nodeWithType:(Class)class;
- (id)finish:(LXNode *)node;
- (LXTokenNode *)consumeTokenNode;
@end
