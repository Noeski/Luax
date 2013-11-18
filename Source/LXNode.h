//
//  LXNode.h
//  LuaX
//
//  Created by Noah Hilt on 8/11/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXVariable.h"

@class LXNode;

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
- (LXScope *)scopeAtLocation:(NSInteger)location;
@end

@interface LXNode : NSObject

@property (nonatomic) NSRange range;
@property (nonatomic) NSInteger startLine;
@property (nonatomic) NSInteger endLine;
@property (nonatomic, strong) NSString *error;

- (NSString *)toString;
@end

//Statements
@interface LXNodeStatement : LXNode
@end

@interface LXNodeEmptyStatement : LXNodeStatement
@end

@interface LXNodeBlock : LXNode {
    
}

@property (nonatomic, strong) LXScope *scope;
@property (nonatomic, strong) NSArray *statements;
@end

@interface LXNodeIfStatement : LXNodeStatement {
    
}

@property (nonatomic, strong) LXNode *condition;
@property (nonatomic, strong) LXNodeBlock *body;
@property (nonatomic, strong) NSArray *elseIfStatements;
@property (nonatomic, strong) LXNodeBlock *elseStatement;
@end

@interface LXNodeElseIfStatement : LXNodeStatement {
    
}

@property (nonatomic, strong) LXNode *condition;
@property (nonatomic, strong) LXNodeBlock *body;
@end

@interface LXNodeWhileStatement : LXNodeStatement {
    
}

@property (nonatomic, strong) LXNode *condition;
@property (nonatomic, strong) LXNodeBlock *body;
@end

@interface LXNodeDoStatement : LXNodeStatement {
    
}

@property (nonatomic, strong) LXNodeBlock *body;
@end

@interface LXNodeNumericForStatement : LXNodeStatement {
    
}

@property (nonatomic, strong) LXVariable *variable;
@property (nonatomic, strong) LXNode *startExpression;
@property (nonatomic, strong) LXNode *endExpression;
@property (nonatomic, strong) LXNode *stepExpression;
@property (nonatomic, strong) LXNodeBlock *body;

@end

@interface LXNodeGenericForStatement : LXNodeStatement {
    
}

@property (nonatomic, strong) NSArray *variableList;
@property (nonatomic, strong) NSArray *generators;
@property (nonatomic, strong) LXNodeBlock *body;

@end

@interface LXNodeRepeatStatement : LXNodeStatement {
    
}
@property (nonatomic, strong) LXNode *condition;
@property (nonatomic, strong) LXNodeBlock *body;
@end

@interface LXNodeFunctionStatement : LXNodeStatement {
    
}

@property (nonatomic, strong) LXNode *expression;
@property (nonatomic) BOOL isLocal;

@end

@interface LXNodeClassStatement : LXNodeStatement {
    
}

@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *superclass;
@property (nonatomic, strong) NSArray *functions;
@property (nonatomic, strong) NSArray *variables;
@property (nonatomic, strong) NSArray *variableDeclarations;
@property (nonatomic) BOOL isLocal;

@end

@interface LXNodeLabelStatement : LXNodeStatement {
    
}

@property (nonatomic, strong) NSString *label;

@end

@interface LXNodeReturnStatement : LXNodeStatement {
    
}

@property (nonatomic, strong) NSArray *arguments;

@end

@interface LXNodeBreakStatement : LXNodeStatement {
    
}
@end

@interface LXNodeGotoStatement : LXNodeStatement {
    
}

@property (nonatomic, strong) NSString *label;

@end

@interface LXNodeAssignmentStatement : LXNodeStatement {
    
}

@property (nonatomic, strong) NSArray *variables;
@property (nonatomic, strong) NSArray *initializers;
@property (nonatomic, strong) NSString *op;

@end

@interface LXNodeDeclarationStatement : LXNodeStatement {
    
}

@property (nonatomic, strong) NSArray *variables;
@property (nonatomic, strong) NSArray *initializers;
@property (nonatomic, assign) BOOL isLocal;
@end

@interface LXNodeExpressionStatement : LXNodeStatement {
    
}

@property (nonatomic, strong) LXNode *expression;

@end

//Expressions
@interface LXNodeExpression : LXNode {
    
}

@property (nonatomic, strong) LXVariable *scriptVariable;
@end

@interface LXNodeVariableExpression : LXNodeExpression {
    
}

@property (nonatomic, strong) NSString *variable;

@end

@interface LXNodeUnaryOpExpression : LXNodeExpression {
    
}

@property (nonatomic, strong) NSString *op;
@property (nonatomic, strong) LXNode *rhs;

@end

@interface LXNodeBinaryOpExpression : LXNodeExpression {
    
}

@property (nonatomic, strong) NSString *op;
@property (nonatomic, strong) LXNode *lhs;
@property (nonatomic, strong) LXNode *rhs;

@end

@interface LXNodeNumberExpression : LXNodeExpression {
    
}

@property (nonatomic, strong) NSNumber *value;

@end

@interface LXNodeStringExpression : LXNodeExpression {
    
}

@property (nonatomic, strong) NSString *value;

@end

@interface LXNodeBoolExpression : LXNodeExpression {
    
}

@property (nonatomic) BOOL value;

@end

@interface LXNodeNilExpression : LXNodeExpression {
    
}

@end

@interface LXNodeVarArgExpression : LXNodeExpression {
    
}

@end

@interface LXKeyValuePair : NSObject
@property (nonatomic, strong) LXNode *key;
@property (nonatomic, strong) LXNode *value;
@property (nonatomic, assign) BOOL isBoxed;
@end

@interface LXNodeTableConstructorExpression : LXNodeExpression {
    
}

@property (nonatomic, strong) NSArray *keyValuePairs;

@end

@interface LXNodeMemberExpression : LXNodeExpression {
    
}

@property (nonatomic, strong) LXNode *base;
@property (nonatomic, strong) NSString *value;
@property (nonatomic) BOOL useColon;

@end

@interface LXNodeIndexExpression : LXNodeExpression {
    
}

@property (nonatomic, strong) LXNode *base;
@property (nonatomic, strong) LXNode *index;

@end

@interface LXNodeCallExpression : LXNodeExpression {
    
}

@property (nonatomic, strong) LXNode *base;
@property (nonatomic, strong) NSArray *arguments;

@end

@interface LXNodeStringCallExpression : LXNodeExpression {
    
}

@property (nonatomic, strong) LXNode *base;
@property (nonatomic, strong) NSString *value;

@end

@interface LXNodeTableCallExpression : LXNodeExpression {
    
}

@property (nonatomic, strong) LXNode *base;
@property (nonatomic, strong) LXNode *table;

@end

@interface LXNodeFunctionExpression : LXNodeStatement {
    
}

@property (nonatomic, strong) LXNode *name;
@property (nonatomic, strong) NSArray *returnTypes;
@property (nonatomic, strong) NSArray *arguments;
@property (nonatomic, strong) LXNodeBlock *body;
@property (nonatomic) BOOL isVarArg;

@end