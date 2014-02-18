//
//  LXNode.h
//  LuaX
//
//  Created by Noah Hilt on 8/11/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXVariable.h"

@class LXToken;
@class LXLuaWriter;
@class LXContext;
@class LXTokenNode;
@class LXBlock;

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
@property (nonatomic, weak) LXNode *parent;
@property (nonatomic, readonly) NSArray *children;
@property (nonatomic, assign) NSInteger line;
@property (nonatomic, assign) NSInteger column;
@property (nonatomic, assign) NSInteger location;
@property (nonatomic, assign) NSInteger length;
@property (nonatomic, readonly) NSRange range;

- (id)initWithLine:(NSInteger)line column:(NSInteger)column location:(NSInteger)location;
- (void)resolveVariables:(LXContext *)context;
- (void)resolveTypes:(LXContext *)context;
- (void)verify;
- (LXTokenNode *)closestCompletionNode:(NSInteger)location;
- (void)print:(NSInteger)indent;
- (void)compile:(LXLuaWriter *)writer;
@end


typedef enum {
    LXTokenCompletionFlagsTypes = 1,
    LXTokenCompletionFlagsVariables = 2,
    LXTokenCompletionFlagsMembers = 4,
    LXTokenCompletionFlagsFunctions = 8,
    LXTokenCompletionFlagsControlStructures = 16,
    LXTokenCompletionFlagsClass = /*LXTokenCompletionFlagsFunction |*/LXTokenCompletionFlagsTypes,
    LXTokenCompletionFlagsBlock = LXTokenCompletionFlagsControlStructures | LXTokenCompletionFlagsVariables | LXTokenCompletionFlagsTypes
} LXTokenCompletionFlags;

@interface LXTokenNode : LXNode
@property (nonatomic, assign) LXTokenNode *prev;
@property (nonatomic, strong) LXTokenNode *next;
@property (nonatomic, strong) NSString *value;
@property (nonatomic, strong) LXClass *type;
@property (nonatomic, assign) NSInteger tokenType;
@property (nonatomic, assign) NSInteger completionFlags;
@property (nonatomic, assign) BOOL isType;
@property (nonatomic, assign) BOOL isMember;
@property (nonatomic, readonly) BOOL isKeyword;
@property (nonatomic, readonly) BOOL isReserved;
@property (nonatomic, readonly) LXScope *scope;

+ (LXTokenNode *)tokenNodeWithToken:(LXToken *)token;
@end

@interface LXExpr : LXNode
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

@interface LXDeclarationNode : LXNode
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
@property (nonatomic, strong) LXTokenNode *leftBraceToken;
@property (nonatomic, strong) NSArray *keyValuePairs;
@property (nonatomic, strong) LXTokenNode *rightBraceToken;
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

@interface LXFunctionReturnTypes : LXNode
@property (nonatomic, strong) LXTokenNode *leftParenToken;
@property (nonatomic, strong) NSArray *returnTypes;
@property (nonatomic, strong) LXTokenNode *rightParenToken;

+ (LXFunctionReturnTypes *)returnTypes:(NSArray *)types leftToken:(LXTokenNode *)leftToken rightToken:(LXTokenNode *)rightToken;
@end

@interface LXFunctionArguments : LXNode
@property (nonatomic, strong) LXTokenNode *leftParenToken;
@property (nonatomic, strong) NSArray *args;
@property (nonatomic, strong) LXTokenNode *rightParenToken;

+ (LXFunctionArguments *)arguments:(NSArray *)args leftToken:(LXTokenNode *)leftToken rightToken:(LXTokenNode *)rightToken;
@end

@interface LXFunctionExpr : LXExpr
@property (nonatomic, strong) LXTokenNode *scopeToken;
@property (nonatomic, strong) LXTokenNode *staticToken;
@property (nonatomic, strong) LXTokenNode *functionToken;
@property (nonatomic, strong) LXFunctionReturnTypes *returnTypes;
@property (nonatomic, strong) LXTokenNode *nameExpr;
@property (nonatomic, strong) LXFunctionArguments *args;
@property (nonatomic, strong) LXBlock *body;
@property (nonatomic, strong) LXTokenNode *endToken;
@property (nonatomic, strong) LXScope *scope;
@property (nonatomic, assign) BOOL isStatic;
@property (nonatomic, assign) BOOL isGlobal;
@end

@interface LXStmt : LXNode
@end

@interface LXEmptyStmt : LXStmt
@property (nonatomic, strong) LXTokenNode *token;
@end

@interface LXBlock : LXNode
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
@property (nonatomic, strong) LXClass *type;

- (void)compileInitFunction:(LXLuaWriter *)writer;
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
@property (nonatomic, strong) LXScope *scope;

+ (instancetype)forStatementWithToken:(LXTokenNode *)forToken;
@end

@interface LXNumericForStmt : LXForStmt
@property (nonatomic, strong) LXTokenNode *nameToken;
@property (nonatomic, strong) LXTokenNode *equalsToken;
@property (nonatomic, strong) LXExpr *exprInit;
@property (nonatomic, strong) LXTokenNode *exprCondCommaToken;
@property (nonatomic, strong) LXExpr *exprCond;
@property (nonatomic, strong) LXTokenNode *exprIncCommaToken;
@property (nonatomic, strong) LXExpr *exprInc;
@end

@interface LXIteratorForStmt : LXForStmt
@property (nonatomic, strong) NSArray *vars;
@property (nonatomic, strong) LXTokenNode *inToken;
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
@property (nonatomic, strong) LXTokenNode *labelToken;
@property (nonatomic, strong) LXTokenNode *endLabelToken;
@end

@interface LXGotoStmt : LXStmt
@property (nonatomic, strong) LXTokenNode *gotoToken;
@property (nonatomic, strong) LXTokenNode *labelToken;
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