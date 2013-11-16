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
@property (nonatomic, assign) LXScope *parent;
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
@property (nonatomic, retain) NSString *error;

- (NSString *)toString;
@end

//Statements
@interface LXNodeStatement : LXNode
@end

@interface LXNodeEmptyStatement : LXNodeStatement
@end

@interface LXNodeBlock : LXNode {
    
}

@property (nonatomic, retain) LXScope *scope;
@property (nonatomic, retain) NSArray *statements;
@end

@interface LXNodeIfStatement : LXNodeStatement {
    
}

@property (nonatomic, retain) LXNode *condition;
@property (nonatomic, retain) LXNodeBlock *body;
@property (nonatomic, retain) NSArray *elseIfStatements;
@property (nonatomic, retain) LXNodeBlock *elseStatement;
@end

@interface LXNodeElseIfStatement : LXNodeStatement {
    
}

@property (nonatomic, retain) LXNode *condition;
@property (nonatomic, retain) LXNodeBlock *body;
@end

@interface LXNodeWhileStatement : LXNodeStatement {
    
}

@property (nonatomic, retain) LXNode *condition;
@property (nonatomic, retain) LXNodeBlock *body;
@end

@interface LXNodeDoStatement : LXNodeStatement {
    
}

@property (nonatomic, retain) LXNodeBlock *body;
@end

@interface LXNodeNumericForStatement : LXNodeStatement {
    
}

@property (nonatomic, retain) NSString *variable;
@property (nonatomic, retain) LXNode *startExpression;
@property (nonatomic, retain) LXNode *endExpression;
@property (nonatomic, retain) LXNode *stepExpression;
@property (nonatomic, retain) LXNodeBlock *body;

@end

@interface LXNodeGenericForStatement : LXNodeStatement {
    
}

@property (nonatomic, retain) NSArray *variableList;
@property (nonatomic, retain) NSArray *generators;
@property (nonatomic, retain) LXNodeBlock *body;

@end

@interface LXNodeRepeatStatement : LXNodeStatement {
    
}
@property (nonatomic, retain) LXNode *condition;
@property (nonatomic, retain) LXNodeBlock *body;
@end

@interface LXNodeFunctionStatement : LXNodeStatement {
    
}

@property (nonatomic, retain) LXNode *expression;
@property (nonatomic) BOOL isLocal;

@end

@interface LXNodeClassStatement : LXNodeStatement {
    
}

@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSString *superclass;
@property (nonatomic, retain) NSArray *functions;
@property (nonatomic, retain) NSArray *variables;
@property (nonatomic, retain) NSArray *variableDeclarations;
@property (nonatomic) BOOL isLocal;

@end

@interface LXNodeLocalStatement : LXNodeStatement {
    
}

@property (nonatomic, retain) NSArray *varList;
@property (nonatomic, retain) NSArray *initList;

@end

@interface LXNodeLabelStatement : LXNodeStatement {
    
}

@property (nonatomic, retain) NSString *label;

@end

@interface LXNodeReturnStatement : LXNodeStatement {
    
}

@property (nonatomic, retain) NSArray *arguments;

@end

@interface LXNodeBreakStatement : LXNodeStatement {
    
}
@end

@interface LXNodeGotoStatement : LXNodeStatement {
    
}

@property (nonatomic, retain) NSString *label;

@end

@interface LXNodeAssignmentStatement : LXNodeStatement {
    
}

@property (nonatomic, retain) NSArray *varList;
@property (nonatomic, retain) NSArray *initList;

@end

@interface LXNodeDeclarationStatement : LXNodeStatement {
    
}

@property (nonatomic, retain) NSArray *varList;
@property (nonatomic, retain) NSArray *initList;

@end

@interface LXNodeExpressionStatement : LXNodeStatement {
    
}

@property (nonatomic, retain) LXNode *expression;

@end

//Expressions
@interface LXNodeExpression : LXNode {
    
}

@property (nonatomic, retain) LXVariable *scriptVariable;
@end

@interface LXNodeVariableExpression : LXNodeExpression {
    
}

@property (nonatomic, retain) NSString *variable;
@property (nonatomic) BOOL local;

@end

@interface LXNodeUnaryOpExpression : LXNodeExpression {
    
}

@property (nonatomic, retain) NSString *op;
@property (nonatomic, retain) LXNode *rhs;

@end

@interface LXNodeBinaryOpExpression : LXNodeExpression {
    
}

@property (nonatomic, retain) NSString *op;
@property (nonatomic, retain) LXNode *lhs;
@property (nonatomic, retain) LXNode *rhs;

@end

@interface LXNodeNumberExpression : LXNodeExpression {
    
}

@property (nonatomic, retain) NSNumber *value;

@end

@interface LXNodeStringExpression : LXNodeExpression {
    
}

@property (nonatomic, retain) NSString *value;

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

@interface KeyValuePair : NSObject
@property (nonatomic, retain) LXNode *key;
@property (nonatomic, retain) LXNode *value;
@end

@interface LXNodeTableConstructorExpression : LXNodeExpression {
    
}

@property (nonatomic, retain) NSArray *keyValuePairs;

@end

@interface LXNodeMemberExpression : LXNodeExpression {
    
}

@property (nonatomic, retain) LXNode *base;
@property (nonatomic, retain) NSString *value;
@property (nonatomic) BOOL useColon;

@end

@interface LXNodeIndexExpression : LXNodeExpression {
    
}

@property (nonatomic, retain) LXNode *base;
@property (nonatomic, retain) LXNode *index;

@end

@interface LXNodeCallExpression : LXNodeExpression {
    
}

@property (nonatomic, retain) LXNode *base;
@property (nonatomic, retain) NSArray *arguments;

@end

@interface LXNodeStringCallExpression : LXNodeExpression {
    
}

@property (nonatomic, retain) LXNode *base;
@property (nonatomic, retain) NSString *value;

@end

@interface LXNodeTableCallExpression : LXNodeExpression {
    
}

@property (nonatomic, retain) LXNode *base;
@property (nonatomic, retain) LXNode *table;

@end

@interface LXNodeFunctionExpression : LXNodeStatement {
    
}

@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) NSArray *returnTypes;
@property (nonatomic, retain) NSArray *arguments;
@property (nonatomic, retain) LXNodeBlock *body;
@property (nonatomic) BOOL isVarArg;

@end