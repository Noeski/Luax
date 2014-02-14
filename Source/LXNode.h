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

@class LXContext;
@interface LXNodeNew : NSObject
@property (nonatomic, assign) NSInteger line;
@property (nonatomic, assign) NSInteger column;
@property (nonatomic, assign) NSInteger location;
@property (nonatomic, assign) NSInteger length;
@property (nonatomic, readonly) NSArray *children;

- (id)initWithLine:(NSInteger)line column:(NSInteger)column location:(NSInteger)location;
- (void)resolveVariables:(LXContext *)context;
- (void)resolveTypes:(LXContext *)context;
- (void)verify;
- (void)print:(NSInteger)indent;
@end

@class LXToken;
@interface LXTokenNode : LXNodeNew
@property (nonatomic, strong) NSString *value;
+ (LXTokenNode *)tokenNodeWithToken:(LXToken *)token;
@end

@interface LXExpr : LXNodeNew
@property (nonatomic, assign) BOOL assignable;
@property (nonatomic, strong) LXVariable *resultType;
@end

@interface LXBoxedExpr : LXExpr
@property (nonatomic, strong) LXTokenNode *leftParenToken;
@property (nonatomic, strong) LXExpr *expr;
@property (nonatomic, strong) LXTokenNode *rightParenToken;
@end

@interface LXNumberExpr : LXExpr
@property (nonatomic, strong) LXTokenNode *token;
@end

@interface LXStringExpr : LXExpr
@property (nonatomic, strong) LXTokenNode *token;
@end

@interface LXNilExpr : LXExpr
@property (nonatomic, strong) LXTokenNode *nilToken;
@end

@interface LXBoolExpr : LXExpr
@property (nonatomic, strong) LXTokenNode *token;
@end

@interface LXDotsExpr : LXExpr
@property (nonatomic, strong) LXTokenNode *dotsToken;
@end

@interface LXVariableExpr : LXExpr
@property (nonatomic, strong) LXTokenNode *token;
@property (nonatomic, assign) BOOL isMember;
@end

@interface LXDeclarationNode : LXNodeNew
@property (nonatomic, strong) LXTokenNode *type;
@property (nonatomic, strong) LXTokenNode *var;
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
@property (nonatomic, strong) LXTokenNode *memberToken;
@property (nonatomic, strong) LXTokenNode *value;

+ (LXMemberExpr *)memberExpressionWithPrefix:(LXExpr *)prefix;
@end

@interface LXIndexExpr : LXExpr
@property (nonatomic, strong) LXExpr *prefix;
@property (nonatomic, strong) LXTokenNode *leftBracketToken;
@property (nonatomic, strong) LXExpr *expr;
@property (nonatomic, strong) LXTokenNode *rightBracketToken;

+ (LXIndexExpr *)indexExpressionWithPrefix:(LXExpr *)prefix;
@end

@interface LXFunctionCallExpr : LXExpr
@property (nonatomic, strong) LXExpr *prefix;
@property (nonatomic, strong) LXTokenNode *memberToken;
@property (nonatomic, strong) LXTokenNode *value;
@property (nonatomic, strong) LXTokenNode *leftParenToken;
@property (nonatomic, strong) NSArray *args;
@property (nonatomic, strong) LXTokenNode *rightParenToken;

+ (LXFunctionCallExpr *)functionCallWithPrefix:(LXExpr *)prefix;
@end

@interface LXUnaryExpr : LXExpr
@property (nonatomic, strong) LXTokenNode *opToken;
@property (nonatomic, strong) LXExpr *expr;
@end

@interface LXBinaryExpr : LXExpr
@property (nonatomic, strong) LXExpr *lhs;
@property (nonatomic, strong) LXTokenNode *opToken;
@property (nonatomic, strong) LXExpr *rhs;

+ (LXBinaryExpr *)binaryExprWithExpr:(LXExpr *)expr;
@end

@interface LXFunctionReturnTypes : LXNodeNew
@property (nonatomic, strong) LXTokenNode *leftParenToken;
@property (nonatomic, strong) NSArray *returnTypes;
@property (nonatomic, strong) LXTokenNode *rightParenToken;

+ (LXFunctionReturnTypes *)returnTypes:(NSArray *)types leftToken:(LXTokenNode *)leftToken rightToken:(LXTokenNode *)rightToken;
@end

@interface LXFunctionArguments : LXNodeNew
@property (nonatomic, strong) LXTokenNode *leftParenToken;
@property (nonatomic, strong) NSArray *args;
@property (nonatomic, strong) LXTokenNode *rightParenToken;

+ (LXFunctionArguments *)arguments:(NSArray *)args leftToken:(LXTokenNode *)leftToken rightToken:(LXTokenNode *)rightToken;
@end

@class LXBlock;
@interface LXFunctionExpr : LXExpr
@property (nonatomic, strong) LXTokenNode *scopeToken;
@property (nonatomic, strong) LXTokenNode *staticToken;
@property (nonatomic, strong) LXTokenNode *functionToken;
@property (nonatomic, strong) LXFunctionReturnTypes *returnTypes;
@property (nonatomic, strong) LXTokenNode *nameExpr;
@property (nonatomic, strong) LXFunctionArguments *args;
@property (nonatomic, strong) LXBlock *body;
@property (nonatomic, strong) LXTokenNode *endToken;
@property (nonatomic, assign) BOOL isStatic;
@property (nonatomic, assign) BOOL isGlobal;
@end

@interface LXStmt : LXNodeNew
@end

@interface LXEmptyStmt : LXStmt
@property (nonatomic, strong) LXTokenNode *token;
@end

@interface LXBlock : LXNodeNew
@property (nonatomic, strong) NSArray *stmts;
@property (nonatomic, strong) LXScope *scope;
@end

@interface LXClassStmt : LXStmt
@property (nonatomic, strong) LXTokenNode *classToken;
@property (nonatomic, strong) LXTokenNode *nameToken;
@property (nonatomic, strong) LXTokenNode *extendsToken;
@property (nonatomic, strong) LXTokenNode *superToken;
@property (nonatomic, strong) NSArray *vars;
@property (nonatomic, strong) NSArray *functions;
@property (nonatomic, strong) LXTokenNode *endToken;
@property (nonatomic, strong) LXScope *scope;
@end

@interface LXIfStmt : LXStmt
@property (nonatomic, strong) LXTokenNode *ifToken;
@property (nonatomic, strong) LXExpr *expr;
@property (nonatomic, strong) LXTokenNode *thenToken;
@property (nonatomic, strong) LXBlock *body;
@property (nonatomic, strong) NSArray *elseIfStmts;
@property (nonatomic, strong) LXTokenNode *elseToken;
@property (nonatomic, strong) LXBlock *elseStmt;
@property (nonatomic, strong) LXTokenNode *endToken;
@end

@interface LXElseIfStmt : LXStmt
@property (nonatomic, strong) LXTokenNode *elseIfToken;
@property (nonatomic, strong) LXExpr *expr;
@property (nonatomic, strong) LXTokenNode *thenToken;
@property (nonatomic, strong) LXBlock *body;
@end

@interface LXWhileStmt : LXStmt
@property (nonatomic, strong) LXTokenNode *whileToken;
@property (nonatomic, strong) LXExpr *expr;
@property (nonatomic, strong) LXTokenNode *doToken;
@property (nonatomic, strong) LXBlock *body;
@property (nonatomic, strong) LXTokenNode *endToken;
@end

@interface LXDoStmt : LXStmt
@property (nonatomic, strong) LXTokenNode *doToken;
@property (nonatomic, strong) LXBlock *body;
@property (nonatomic, strong) LXTokenNode *endToken;
@end

@interface LXForStmt : LXStmt
@property (nonatomic, strong) LXTokenNode *forToken;
@property (nonatomic, strong) LXTokenNode *doToken;
@property (nonatomic, strong) LXBlock *body;
@property (nonatomic, strong) LXTokenNode *endToken;
@end

@interface LXNumericForStmt : LXForStmt
@property (nonatomic, strong) LXTokenNode *equalsToken;
@property (nonatomic, strong) LXExpr *exprInit;
@property (nonatomic, strong) LXTokenNode *exprCondCommaToken;
@property (nonatomic, strong) LXExpr *exprCond;
@property (nonatomic, strong) LXTokenNode *exprIncCommaToken;
@property (nonatomic, strong) LXExpr *exprInc;
@end

@interface LXIteratorForStmt : LXForStmt
@property (nonatomic, strong) NSArray *vars;
@property (nonatomic, strong) NSArray *exprs;
@end

@interface LXRepeatStmt : LXStmt
@property (nonatomic, strong) LXTokenNode *repeatToken;
@property (nonatomic, strong) LXBlock *body;
@property (nonatomic, strong) LXTokenNode *untilToken;
@property (nonatomic, strong) LXExpr *expr;
@end

@interface LXLabelStmt : LXStmt
@property (nonatomic, strong) LXTokenNode *beginLabelToken;
@property (nonatomic, strong) NSString *value;
@property (nonatomic, strong) LXTokenNode *endLabelToken;
@end

@interface LXGotoStmt : LXStmt
@property (nonatomic, strong) LXTokenNode *gotoToken;
@property (nonatomic, strong) NSString *value;
@end

@interface LXBreakStmt : LXStmt
@property (nonatomic, strong) LXTokenNode *breakToken;
@end

@interface LXReturnStmt : LXStmt
@property (nonatomic, strong) LXTokenNode *returnToken;
@property (nonatomic, strong) NSArray *exprs;
@end

@interface LXDeclarationStmt : LXStmt
@property (nonatomic, strong) LXTokenNode *scopeToken;
@property (nonatomic, strong) LXTokenNode *typeToken;
@property (nonatomic, strong) NSArray *vars;
@property (nonatomic, strong) LXTokenNode *equalsToken;
@property (nonatomic, strong) NSArray *exprs;
@property (nonatomic, assign) BOOL isGlobal;
@end

@interface LXAssignmentStmt : LXStmt
@property (nonatomic, strong) NSArray *vars;
@property (nonatomic, strong) LXTokenNode *equalsToken;
@property (nonatomic, strong) NSArray *exprs;
@end

@interface LXExprStmt : LXStmt
@property (nonatomic, strong) LXExpr *expr;
@end