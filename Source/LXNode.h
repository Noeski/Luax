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

@interface LXNodeNew : NSObject
@property (nonatomic, readonly) NSInteger line;
@property (nonatomic, readonly) NSInteger column;
@property (nonatomic, readonly) NSRange range;

- (id)initWithLine:(NSInteger)line column:(NSInteger)column location:(NSInteger)location;
@end

@interface LXExpr : LXNodeNew
@property (nonatomic, assign) BOOL assignable;
@property (nonatomic, strong) LXVariable *variable;
@end

@interface LXNumberExpr : LXExpr
@property (nonatomic, strong) NSString *value;
@end

@interface LXStringExpr : LXExpr
@property (nonatomic, strong) NSString *value;
@end

@interface LXNilExpr : LXExpr
@end

@interface LXBoolExpr : LXExpr
@property (nonatomic, strong) NSString *value;
@end

@interface LXDotsExpr : LXExpr
@end

@interface LXVariableExpr : LXExpr
@property (nonatomic, strong) NSString *value;
@property (nonatomic, assign) BOOL isMember;
@end

@interface LXKVP : NSObject
@property (nonatomic, strong) LXExpr *key;
@property (nonatomic, strong) LXExpr *value;

- (id)initWithKey:(LXExpr *)key value:(LXExpr *)value;
- (id)initWithValue:(LXExpr *)value;
@end

@interface LXTableCtorExpr : LXExpr
@property (nonatomic, strong) NSArray *keyValuePairs;
@end

@interface LXMemberExpr : LXExpr
@property (nonatomic, strong) LXExpr *prefix;
@property (nonatomic, strong) NSString *value;
@end

@interface LXIndexExpr : LXExpr
@property (nonatomic, strong) LXExpr *prefix;
@property (nonatomic, strong) LXExpr *expr;
@end

@interface LXFunctionCall : LXExpr
@property (nonatomic, strong) LXExpr *prefix;
@property (nonatomic, strong) NSString *value;
@property (nonatomic, strong) NSArray *args;
@end

@interface LXUnaryExpr : LXExpr
@property (nonatomic, strong) id op;
@property (nonatomic, strong) LXExpr *expr;
@end

@interface LXBinaryExpr : LXExpr
@property (nonatomic, strong) id op;
@property (nonatomic, strong) LXExpr *lhs;
@property (nonatomic, strong) LXExpr *rhs;
@end


@interface LXStmt : LXNodeNew
@end

@interface LXEmptyStmt : LXStmt
@end

@interface LXBlock : LXNodeNew
@property (nonatomic, strong) NSArray *stmts;
@end

@interface LXIfStmt : LXStmt
@property (nonatomic, strong) LXExpr *expr;
@property (nonatomic, strong) LXBlock *body;
@property (nonatomic, strong) NSArray *elseIfStmts;
@property (nonatomic, strong) LXBlock *elseStmt;
@end

@interface LXElseIfStmt : LXStmt
@property (nonatomic, strong) LXExpr *expr;
@property (nonatomic, strong) LXBlock *body;
@end

@interface LXWhileStmt : LXStmt
@property (nonatomic, strong) LXExpr *expr;
@property (nonatomic, strong) LXBlock *body;
@end

@interface LXDoStmt : LXStmt
@property (nonatomic, strong) LXBlock *body;
@end

@interface LXRepeatStmt : LXStmt
@property (nonatomic, strong) LXExpr *expr;
@property (nonatomic, strong) LXBlock *body;
@end

@interface LXLabelStmt : LXStmt
@property (nonatomic, strong) NSString *value;
@end

@interface LXGotoStmt : LXStmt
@property (nonatomic, strong) NSString *value;
@end

@interface LXBreakStmt : LXStmt
@end

@interface LXReturnStmt : LXStmt
@property (nonatomic, strong) NSArray *exprs;
@end

@interface LXDeclarationStmt : LXStmt
@property (nonatomic, strong) NSArray *vars;
@property (nonatomic, strong) NSArray *exprs;
@end

@interface LXAssignmentStmt : LXStmt
@property (nonatomic, strong) NSArray *vars;
@property (nonatomic, strong) NSArray *exprs;
@end

@interface LXExprStmt : LXStmt
@property (nonatomic, strong) LXExpr *expr;
@end