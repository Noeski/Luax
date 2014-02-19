//
//  LXCompiler+Expression.m
//  Luax
//
//  Created by Noah Hilt on 2/2/14.
//  Copyright (c) 2014 Noah Hilt. All rights reserved.
//

#import "LXCompiler+Expression.h"
#import "LXCompiler+Statement.h"

@implementation LXContext(Expression)

- (LXExpr *)parseExpression {
    return [self parseSubExpression:0];
}

- (LXExpr *)parseSubExpression:(NSInteger)level {
    static __strong NSDictionary *unaryOps = nil;
    
    if(!unaryOps)
        unaryOps = @{@('-') : @YES, @('#') : @YES, @(LX_TK_NOT) : @YES};
    
    static __strong NSDictionary *priorityDict = nil;
    
    if(!priorityDict)
        priorityDict = @{
                         @('+') : [NSValue valueWithRange:NSMakeRange(6, 6)],
                         @('-') : [NSValue valueWithRange:NSMakeRange(6, 6)],
                         @('%') : [NSValue valueWithRange:NSMakeRange(7, 7)],
                         @('/') : [NSValue valueWithRange:NSMakeRange(7, 7)],
                         @('*') : [NSValue valueWithRange:NSMakeRange(7, 7)],
                         @('^') : [NSValue valueWithRange:NSMakeRange(10, 9)],
                         @(LX_TK_CONCAT) : [NSValue valueWithRange:NSMakeRange(5, 4)],
                         @(LX_TK_EQ) : [NSValue valueWithRange:NSMakeRange(3, 3)],
                         @('<') : [NSValue valueWithRange:NSMakeRange(3, 3)],
                         @(LX_TK_LE) : [NSValue valueWithRange:NSMakeRange(3, 3)],
                         @(LX_TK_NE) : [NSValue valueWithRange:NSMakeRange(3, 3)],
                         @('>') : [NSValue valueWithRange:NSMakeRange(3, 3)],
                         @(LX_TK_GE) : [NSValue valueWithRange:NSMakeRange(3, 3)],
                         @(LX_TK_AND) : [NSValue valueWithRange:NSMakeRange(2, 2)],
                         @(LX_TK_OR) : [NSValue valueWithRange:NSMakeRange(1, 1)]};
    
    if(unaryOps[@(_current.type)]) {
        LXUnaryExpr *expr = [self nodeWithType:[LXUnaryExpr class]];
        expr.opToken = [self consumeTokenNode];
        expr.expr = [self parseSubExpression:8];
        
        return [self finish:expr];
    }
    else {
        LXExpr *expr = [self parseSimpleExpression];
        
        do {
            NSValue *priority = priorityDict[@(_current.type)];
            
            if(priority && priority.rangeValue.location > level) {
                LXBinaryExpr *binaryExpr = [LXBinaryExpr binaryExprWithExpr:expr];
                binaryExpr.opToken = [self consumeTokenNode];
                binaryExpr.rhs = [self parseSubExpression:priority.rangeValue.length];
                
                expr = [self finish:binaryExpr];
            }
            else {
                break;
                
            }
        } while (YES);
        
        return expr;
    }
}

- (LXTableCtorExpr *)parseTable {
    LXTableCtorExpr *expr = [self nodeWithType:[LXTableCtorExpr class]];
    expr.leftBraceToken = [self consumeTokenNode];
    
    NSMutableArray *mutableKeyValuePairs = [[NSMutableArray alloc] init];
    
    do {
        if(_current.type == '[') {
            LXIndexedKVP *kvp = [self nodeWithType:[LXIndexedKVP class]];
            kvp.leftBracketToken = [self consumeTokenNode];
            kvp.key = [self parseExpression];
            
            if(_current.type != ']') {
                [self addError:[NSString stringWithFormat:@"Expected ']' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
                break;
            }
            
            kvp.rightBracketToken = [self consumeTokenNode];
            
            if(_current.type != '=') {
                [self addError:[NSString stringWithFormat:@"Expected '=' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
                break;
            }
            
            kvp.assignmentToken = [self consumeTokenNode];
            kvp.value = [self parseExpression];
            
            [mutableKeyValuePairs addObject:[self finish:kvp]];
        }
        else if(_current.type == LX_TK_NAME && _next.type == '=') {
            LXKVP *kvp = [self nodeWithType:[LXKVP class]];
            kvp.key = [self consumeTokenNode];
            kvp.assignmentToken = [self consumeTokenNode];
            kvp.value = [self parseExpression];
            [mutableKeyValuePairs addObject:[self finish:kvp]];
        }
        else if(_current.type == '}') {
            break;
        }
        else {
            [mutableKeyValuePairs addObject:[self parseExpression]];
        }
        
        if(_current.type ==';' || _current.type == ',') {
            [mutableKeyValuePairs addObject:[self consumeTokenNode]];
        }
        else {
            break;
        }
    } while(YES);

    expr.keyValuePairs = mutableKeyValuePairs;

    if(_current.type != '}') {
        [self addError:[NSString stringWithFormat:@"Expected ';', ',' or '}' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
    }

    expr.rightBraceToken = [self consumeTokenNode];
    
    return [self finish:expr];
}

- (LXExpr *)parseSimpleExpression {
    switch((NSInteger)_current.type) {
        case LX_TK_NUMBER: {
            LXNumberExpr *expr = [self nodeWithType:[LXNumberExpr class]];
            expr.token = [self consumeTokenNode];
            return [self finish:expr];
        }
            
        case LX_TK_STRING: {
            LXStringExpr *expr = [self nodeWithType:[LXStringExpr class]];
            expr.token = [self consumeTokenNode];
            return [self finish:expr];
        }
            
        case LX_TK_NIL: {
            LXNilExpr *expr = [self nodeWithType:[LXNilExpr class]];
            expr.nilToken = [self consumeTokenNode];
            return [self finish:expr];
        }
            
        case LX_TK_TRUE:
        case LX_TK_FALSE: {
            LXBoolExpr *expr = [self nodeWithType:[LXBoolExpr class]];
            expr.token = [self consumeTokenNode];
            return [self finish:expr];
        }
            
        case LX_TK_DOTS: {
            LXDotsExpr *expr = [self nodeWithType:[LXDotsExpr class]];
            expr.dotsToken = [self consumeTokenNode];
            return [self finish:expr];
        }
            
        case LX_TK_FUNCTION: {
            return [self parseFunction:YES];
            break;
        }
            
        case '{': {
            return [self parseTable];
        }
            
        default: {
            return [self parseSuffixedExpression];
        }
    }
    
    return nil;
}

- (LXFunctionCallExpr *)parseFunctionCall:(LXExpr *)prefix {
    LXFunctionCallExpr *expr = [LXFunctionCallExpr functionCallWithPrefix:prefix];
    expr.assignable = NO;
    
    do {
        if(_current.type == ':') {            
            expr.memberToken = [self consumeTokenNode];
            
            if(_current.type != LX_TK_NAME) {
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
                [self skipLine];
                break;
            }
            
            expr.value = [self consumeTokenNode];
        }
        
        if(_current.type == '(') {
            expr.leftParenToken = [self consumeTokenNode];
            
            NSMutableArray *mutableArgs = [[NSMutableArray alloc] init];
            
            while(_current.type != ')') {
                [mutableArgs addObject:[self parseExpression]];
                
                if(_current.type != ',') {
                    if(_current.type != ')') {
                        [self addError:[NSString stringWithFormat:@"Expected ')' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
                        break;
                    }
                }
                else {
                    [mutableArgs addObject:[self consumeTokenNode]];
                }
            }
            
            expr.args = mutableArgs;
            expr.rightParenToken = [self consumeTokenNode];
        }
        else if(_current.type == LX_TK_STRING) {
            expr.args = [NSArray arrayWithObject:[self parseSimpleExpression]];
        }
        else if(_current.type == '{') {
            expr.args = [NSArray arrayWithObject:[self parseTable]];
        }
    } while(NO);
    
    return [self finish:expr];
}

- (LXExpr *)parseSuffixedExpression {
    LXExpr *expression = [self parsePrimaryExpression];
    LXExpr *lastExpression = expression;
    
    do {
        if(_current.type == '.') {
            LXMemberExpr *memberExpression = [LXMemberExpr memberExpressionWithPrefix:lastExpression];
            memberExpression.memberToken = [self consumeTokenNode];
            
            if(_current.type != LX_TK_NAME) {
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
                //[self skipLine];
            }
            
            memberExpression.value = [self consumeTokenNode];
            memberExpression.assignable = YES;
            
            expression = [self finish:memberExpression];
        }
        else if(_current.type == '[') {
            LXIndexExpr *indexExpression = [LXIndexExpr indexExpressionWithPrefix:lastExpression];
            indexExpression.leftBracketToken = [self consumeTokenNode];
            indexExpression.expr = [self parseExpression];
            indexExpression.assignable = YES;
            
            if(_current.type != ']') {
                [self addError:[NSString stringWithFormat:@"Expected ']' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
                //[self skipLine];
            }
            
            indexExpression.rightBracketToken = [self consumeTokenNode];
            
            expression = [self finish:indexExpression];
        }
        else if(_current.type == ':' ||
                _current.type == '(' ||
                _current.type == '{' ||
                _current.type == LX_TK_STRING) {
            expression = [self parseFunctionCall:lastExpression];
        }
        else {
            break;
        }
        
        lastExpression = expression;
    }
    while(YES);
    
    return lastExpression;
}

- (LXExpr *)parsePrimaryExpression {
    if(_current.type == '(') {
        LXBoxedExpr *expr = [self nodeWithType:[LXBoxedExpr class]];
        expr.leftParenToken = [self consumeTokenNode];
        expr.expr = [self parseExpression];
        
        if(_current.type != ')') {
            [self addError:[NSString stringWithFormat:@"Expected ')' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
            [self skipLine];
        }
        
        expr.rightParenToken = [self consumeTokenNode];
        expr.assignable = NO;
        
        return [self finish:expr];
    }
    else if(_current.type == LX_TK_NAME) {
        LXVariableExpr *expr = [self nodeWithType:[LXVariableExpr class]];
        expr.token = [self consumeTokenNode];
        expr.assignable = YES;

        return [self finish:expr];
    }
    else {
        LXExpr *emptyExpr = [self nodeWithType:[LXExpr class]];
        [self addError:[NSString stringWithFormat:@"Expected 'name' or '(expression)' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        [self skipLine];
        
        return [self finish:emptyExpr];
    }
}

- (LXFunctionExpr *)parseFunction:(BOOL)anonymous {
    LXFunctionExpr *functionExpr = [self nodeWithType:[LXFunctionExpr class]];
    
    if(_current.type == LX_TK_LOCAL) {
        functionExpr.scopeToken = [self consumeTokenNode];
        functionExpr.isGlobal = NO;
    }
    else if(_current.type == LX_TK_GLOBAL) {
        functionExpr.scopeToken = [self consumeTokenNode];
        functionExpr.isGlobal = YES;
    }
    
    if(_current.type == LX_TK_STATIC) {
        functionExpr.staticToken = [self consumeTokenNode];
        functionExpr.isStatic = YES;
    }
    
    functionExpr.functionToken = [self consumeTokenNode];

    BOOL checkingReturnType = NO;
    BOOL hasReturnType = NO;
    BOOL hasEmptyReturnType = NO;
    
    LXTokenNode *leftParenToken = nil;
    LXTokenNode *rightParenToken = nil;
    NSMutableArray *mutableReturnTypes = [[NSMutableArray alloc] init];

    if(_current.type == '(') {
        checkingReturnType = YES;
        
        leftParenToken = [self consumeTokenNode];
        
        if(_current.type == ')' ||
           (([_current isType] || _current.type == LX_TK_DOTS) &&
            (_next.type == ',' || _next.type == ')'))) {
           hasReturnType = YES;

           while(_current.type != ')') {
               if([_current isType]) {
                   [mutableReturnTypes addObject:[self consumeTokenNode]];
                   
                   if(_current.type == ',') {
                       [mutableReturnTypes addObject:[self consumeTokenNode]];
                   }
                   else {
                       break;
                   }
               }
               else if(_current.type == LX_TK_DOTS) {
                   [mutableReturnTypes addObject:[self consumeTokenNode]];
                   break;
               }
               else {
                   [self addError:[NSString stringWithFormat:@"Expected 'type' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
                   break;
               }
           }
           
           if(_current.type != ')') {
               [self addError:[NSString stringWithFormat:@"Expected ')' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
           }
           
           rightParenToken = [self consumeTokenNode];
        }
    }
    
    if(!anonymous) {
        if(hasReturnType) {
            functionExpr.returnTypes = [LXFunctionReturnTypes returnTypes:mutableReturnTypes leftToken:leftParenToken rightToken:rightParenToken];
        }
        
        if(_current.type != LX_TK_NAME) {
            [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        }
        
        functionExpr.nameExpr = [self consumeTokenNode];
        
        /*while(token.type == '.' ||
              token.type == ':') {
            [self consumeToken];
            
            [node addChunk:token.type == ':' ? @":" : @"." line:token.line column:token.column];
            
            nameToken = [self currentToken];
            functionName = [self tokenValue:nameToken];
            
            if(nameToken.type != LX_TK_NAME) {
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:nameToken]] range:nameToken.range line:nameToken.line column:nameToken.column];
                
                break;
            }
            
            [self consumeToken];
            [node addNamedChunk:functionName line:nameToken.line column:nameToken.column];
            
            token = [self currentToken];
        }*/
        
        if(_current.type != '(') {
            [self addError:[NSString stringWithFormat:@"Expected '(' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        }
        
        leftParenToken = [self consumeTokenNode];
    }
    else {
        if(hasReturnType) {
            if(_current.type != '(') {
                if([functionExpr.returnTypes.returnTypes count] == 0) {
                    hasEmptyReturnType = YES;
                    functionExpr.args = [LXFunctionArguments arguments:@[] leftToken:leftParenToken rightToken:rightParenToken];
                }
                else {
                    [self addError:[NSString stringWithFormat:@"Expected '(' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
                }
            }
            else {
                functionExpr.returnTypes = [LXFunctionReturnTypes returnTypes:mutableReturnTypes leftToken:leftParenToken rightToken:rightParenToken];

                leftParenToken = [self consumeTokenNode];
            }
        }
    }
    
    functionExpr.scope = [self createScope:NO];

    if(!hasEmptyReturnType) {
        NSMutableArray *mutableArguments = [[NSMutableArray alloc] init];
        BOOL isVarArg = NO;

        while(_current.type != ')') {
            if([_current isType]) {
                LXDeclarationNode *declarationNode = [self nodeWithType:[LXDeclarationNode class]];

                declarationNode.type = [self consumeTokenNode];
                
                if(_current.type != LX_TK_NAME) {
                    [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
                }
                
                declarationNode.var = [self consumeTokenNode];
                
                [mutableArguments addObject:[self finish:declarationNode]];
                
                if(_current.type == ',') {
                    [mutableArguments addObject:[self consumeTokenNode]];
                }
                else {
                    break;
                }
            }
            else if(_current.type == LX_TK_DOTS) {
                isVarArg = YES;
                [mutableArguments addObject:[self consumeTokenNode]];
                break;
            }
            else {
                [self addError:[NSString stringWithFormat:@"Expected 'type' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
                break;
            }
        }
    
        if(_current.type != ')') {
            [self addError:[NSString stringWithFormat:@"Expected ')' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        }
        
        functionExpr.args = [LXFunctionArguments arguments:mutableArguments leftToken:leftParenToken rightToken:[self consumeTokenNode]];
    }
    
    functionExpr.body = [self parseBlock];
    
    if(_current.type != LX_TK_END) {
        [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
    }
    
    [self finishScope];
    functionExpr.endToken = [self consumeTokenNode];
    
    return [self finish:functionExpr];
}

@end
