//
//  LXNode.h
//  LuaX
//
//  Created by Noah Hilt on 8/11/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXVariable.h"

@interface LXLuaWriter : NSObject
@property (nonatomic, assign) NSString *currentSource;
@property (nonatomic, assign) NSInteger currentLine;
@property (nonatomic, assign) NSInteger currentColumn;
@property (nonatomic, readonly) NSString *string;
@property (nonatomic, readonly) NSArray *mappings;

- (void)write:(NSString *)generated;
- (void)write:(NSString *)generated line:(NSInteger)line column:(NSInteger)column;
- (void)write:(NSString *)generated name:(NSString *)name line:(NSInteger)line column:(NSInteger)column;
- (NSDictionary *)generateSourceMap;
@end

typedef enum {
    LXScopeTypeBlock,
    LXScopeTypeFunction,
    LXScopeTypeClass
} LXScopeType;

@interface LXScope : NSObject

@property (nonatomic, assign) LXScopeType type;
@property (nonatomic, weak) LXScope *parent;
@property (nonatomic, readonly) NSMutableArray *children;
@property (nonatomic, readonly) NSMutableArray *localVariables;
@property (nonatomic, assign) NSRange range;
@property (nonatomic, readonly) NSInteger scopeLevel;

- (id)initWithParent:(LXScope *)parent openScope:(BOOL)openScope;
- (BOOL)isGlobalScope;
- (BOOL)isFileScope;
- (LXVariable *)localVariable:(NSString *)name;
- (LXVariable *)variable:(NSString *)name;
- (LXVariable *)createVariable:(NSString *)name type:(LXClass *)type;
- (LXVariable *)createFunction:(NSString *)name;
- (void)removeVariable:(LXVariable *)variable;
- (LXScope *)scopeAtLocation:(NSInteger)location;
- (void)removeScope:(LXScope *)scope;
@end

@interface LXNode : NSObject
@property (nonatomic, readonly) NSInteger line;
@property (nonatomic, readonly) NSInteger column;
@property (nonatomic, readonly) NSString *chunk;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSArray *children;
@property (nonatomic, strong) LXVariable *variable;
@property (nonatomic, assign) BOOL assignable;

- (id)initWithName:(NSString *)name line:(NSInteger)line column:(NSInteger)column;
- (id)initWithChunk:(NSString *)chunk line:(NSInteger)line column:(NSInteger)column;
- (id)initWithLine:(NSInteger)line column:(NSInteger)column;

- (void)addChild:(LXNode *)child;
- (void)addChunk:(NSString *)child line:(NSInteger)line column:(NSInteger)column;
- (void)addNamedChunk:(NSString *)child line:(NSInteger)line column:(NSInteger)column;
- (void)addAnonymousChunk:(NSString *)child;

- (void)compile:(LXLuaWriter *)writer;
@end

@interface LXExpr : NSObject
- (id)initWithLine:(NSInteger)line column:(NSInteger)column location:(NSInteger)location;
@end

@interface LXNumberExpression : LXExpr
@property (nonatomic, strong) NSString *value;
@end

@interface LXStringExpression : LXExpr
@property (nonatomic, strong) NSString *value;
@end

@interface LXNilExpression : LXExpr
@end

@interface LXBoolExpression : LXExpr
@property (nonatomic, strong) NSString *value;
@end

@interface LXDotsExpression : LXExpr
@end

@interface LXUnaryExpr : LXExpr
@property (nonatomic, strong) id op;
@property (nonatomic, strong) id expr;
@end

@interface LXBinaryExpr : LXExpr
@property (nonatomic, strong) id op;
@property (nonatomic, strong) id lhs;
@property (nonatomic, strong) id rhs;
@end


@interface LXStmt : NSObject
@property (nonatomic, readonly) NSInteger line;
@property (nonatomic, readonly) NSInteger column;
@property (nonatomic, readonly) NSRange range;

- (id)initWithLine:(NSInteger)line column:(NSInteger)column location:(NSInteger)location;
@end

@interface LXIfStmt : LXStmt
@property (nonatomic, strong) id expr;
@property (nonatomic, strong) id body;
@property (nonatomic, strong) id elseIfStmts;
@property (nonatomic, strong) id elseStmt;
@end