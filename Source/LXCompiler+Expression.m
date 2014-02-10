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
        LXUnaryExpr *expr = [[LXUnaryExpr alloc] init];
        expr.op = nil;
        [self consumeToken:LXTokenCompletionFlagsVariables];
        expr.expr = [self parseSubExpression:8];
        
        return expr;
    }
    else {
        LXExpr *expr = [self parseSimpleExpression];
        
        do {
            NSValue *priority = priorityDict[@(_current.type)];
            
            if(priority && priority.rangeValue.location > level) {
                LXBinaryExpr *binaryExpr = [[LXBinaryExpr alloc] init];
                binaryExpr.lhs = expr;
                binaryExpr.op = nil;
                
                [self consumeToken:LXTokenCompletionFlagsVariables];
                
                binaryExpr.rhs = [self parseSubExpression:priority.rangeValue.length];
                
                expr = binaryExpr;
            }
            else {
                break;
                
            }
        } while (YES);
        
        return expr;
    }
}

- (LXTableCtorExpr *)parseTable {
    LXTableCtorExpr *expr = [[LXTableCtorExpr alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
    
    [self consumeToken:LXTokenCompletionFlagsVariables];
    
    NSMutableArray *mutableKeyValuePairs = [[NSMutableArray alloc] init];
    
    do {
        if(_current.type == '[') {
            [self consumeToken:LXTokenCompletionFlagsVariables];
            LXExpr *key = [self parseExpression];
            
            if(_current.type != ']') {
                [self addError:[NSString stringWithFormat:@"Expected ']' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
                break;
            }
            
            [self consumeToken];
            
            if(_current.type != '=') {
                [self addError:[NSString stringWithFormat:@"Expected '=' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
                break;
            }
            
            [self consumeToken:LXTokenCompletionFlagsVariables];
            
            LXExpr *value = [self parseExpression];
            
            [mutableKeyValuePairs addObject:[[LXKVP alloc] initWithKey:key value:value]];
        }
        else if(_current.type == LX_TK_NAME) {
            LXExpr *key = [self parseExpression];
            
            LXKVP *kvp = [[LXKVP alloc] initWithValue:key];

            if(_current.type == '=') {
                [self consumeToken:LXTokenCompletionFlagsVariables];
                
                kvp.value = [self parseExpression];
            }
            
            [mutableKeyValuePairs addObject:kvp];
        }
        else if(_current.type == '}') {
            [self consumeToken];
            break;
        }
        else {
            LXExpr *value = [self parseExpression];
            
            [mutableKeyValuePairs addObject:[[LXKVP alloc] initWithValue:value]];
        }
        
        if(_current.type ==';' || _current.type == ',') {
            [self consumeToken:LXTokenCompletionFlagsVariables];
        }
        else if(_current.type == '}') {
            [self consumeToken];
            break;
        }
        else {
            [self addError:[NSString stringWithFormat:@"Expected ';', ',' or '}' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
            break;
        }
    } while(YES);
    
    expr.keyValuePairs = mutableKeyValuePairs;
    
    return expr;
}

- (LXExpr *)parseSimpleExpression {
    switch((NSInteger)_current.type) {
        case LX_TK_NUMBER: {
            LXNumberExpr *expr = [[LXNumberExpr alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
            expr.value = [self tokenValue:_current];
            [self consumeToken];
            return expr;
        }
            
        case LX_TK_STRING: {
            LXStringExpr *expr = [[LXStringExpr alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
            expr.value = [self tokenValue:_current];
            [self consumeToken];
            return expr;
        }
            
        case LX_TK_NIL: {
            LXNilExpr *expr = [[LXNilExpr alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
            [self consumeToken];
            return expr;
        }
            
        case LX_TK_TRUE:
        case LX_TK_FALSE: {
            LXBoolExpr *expr = [[LXBoolExpr alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
            expr.value = [self tokenValue:_current];
            [self consumeToken];
            return expr;
        }
            
        case LX_TK_DOTS: {
            LXDotsExpr *expr = [[LXDotsExpr alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
            [self consumeToken];
            return expr;
        }
            
        case LX_TK_FUNCTION: {
            return [self parseFunction:YES isLocal:YES class:nil];
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

- (LXFunctionCallExpr *)parseFunctionCall {
    LXFunctionCallExpr *expr = [[LXFunctionCallExpr alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
    [expr setAssignable:NO];
    
    do {
        if(_current.type == ':') {
            [self consumeToken:LXTokenCompletionFlagsFunctions];
            
            if(_current.type != LX_TK_NAME) {
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
                [self skipLine];
                break;
            }
            
            NSString *name = [self tokenValue:_current];
            [expr setValue:name];
            
            /*LXClass *type = lastExpression.variable.type;
            
            if(type.isDefined) {
                for(LXVariable *v in type.variables) {
                    if([v.name isEqualToString:name]) {
                        _current.variable = v;
                        _current.isMember = YES;
                        [expr setVariable:v];
                        break;
                    }
                }
            }*/
            
            [self consumeToken];
        }
        
        if(_current.type == '(') {
            [self consumeToken:LXTokenCompletionFlagsVariables];
            
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
                    [self consumeToken:LXTokenCompletionFlagsVariables];
                }
            }
            
            [self consumeToken];
            
            [expr setArgs:mutableArgs];
            
            /*if(lastExpression.variable.isFunction) {
                LXVariable *function = lastExpression.variable;
                LXVariable *variable = [function.returnTypes count] ? function.returnTypes[0] : nil;
                
                expr.variable = variable;
                endParenToken.variable = variable;
            }*/
        }
        else if(_current.type == LX_TK_STRING) {
            [expr setArgs:[NSArray arrayWithObject:[self parseSimpleExpression]]];
            
            /*if(lastExpression.variable.isFunction) {
                LXVariable *function = lastExpression.variable;
                LXVariable *variable = [function.returnTypes count] ? function.returnTypes[0] : nil;
                
                expr.variable = variable;
                token.variable = variable;
            }*/
        }
        else if(_current.type == '{') {
            [expr setArgs:[NSArray arrayWithObject:[self parseTable]]];
            
            /*if(lastExpression.variable.isFunction) {
                LXVariable *function = lastExpression.variable;
                LXVariable *variable = [function.returnTypes count] ? function.returnTypes[0] : nil;
                
                expr.variable = variable;
                token.variable = variable;
            }*/
        }
    } while(NO);
    
    return expr;
}

- (LXExpr *)parseSuffixedExpression {
    id expression = [self parsePrimaryExpression];
    LXExpr *lastExpression = expression;
    
    do {
        if(_current.type == '.') {
            _current.variable = lastExpression.resultType;
            [self consumeToken:LXTokenCompletionFlagsMembers];
            
            if(_current.type != LX_TK_NAME) {
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
                [self skipLine];
                break;
            }
            
            NSString *name = [self tokenValue:_current];
            expression = [[LXMemberExpr alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
            [expression setPrefix:lastExpression];
            [expression setValue:name];
            [expression setAssignable:YES];
            
            LXClass *type = lastExpression.resultType.type;
            
            if(type.isDefined) {
                for(LXVariable *v in type.variables) {
                    if([v.name isEqualToString:name]) {
                        _current.variable = v;
                        _current.isMember = YES;
                        [expression setResultType:v];
                        break;
                    }
                }
            }
            
            [self consumeToken];
        }
        else if(_current.type == '[') {
            [self consumeToken:LXTokenCompletionFlagsVariables];
            
            expression = [[LXIndexExpr alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
            [expression setPrefix:lastExpression];
            [expression setExpr:[self parseExpression]];
            [expression setAssignable:YES];
            
            if(_current.type != ']') {
                [self addError:[NSString stringWithFormat:@"Expected ']' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
                [self skipLine];
                break;
            }
            
            [self consumeToken];
        }
        else if(_current.type == ':' ||
                _current.type == '(' ||
                _current.type == '{' ||
                _current.type == LX_TK_STRING) {
            LXFunctionCallExpr *functionCall = [self parseFunctionCall];
            functionCall.prefix = lastExpression;
            
            expression = functionCall;
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
        [self consumeToken:LXTokenCompletionFlagsVariables];
        
        LXExpr *expr = [self parseExpression];
        
        if(_current.type != ')') {
            [self addError:[NSString stringWithFormat:@"Expected ')' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
            [self skipLine];
            return expr;
        }
        
        _current.variable = expr.resultType;

        [self consumeToken:LXTokenCompletionFlagsControlStructures];
        
        expr.assignable = NO;
    }
    else if(_current.type == LX_TK_NAME) {
        NSString *name = [self tokenValue:_current];
        LXVariable *variable = [_currentScope variable:name];
        
        if(!variable) {
            variable = [self.compiler.globalScope createVariable:name type:nil];
            [definedVariables addObject:variable];
            
            [self addError:[NSString stringWithFormat:@"Global variable %@ not defined", variable.name] range:_current.range line:_current.line column:_current.column];
        }
        
        _current.variable = variable;

        LXVariableExpr *expr = [[LXVariableExpr alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
        expr.isMember = variable.isMember;
        expr.resultType = variable;
        expr.assignable = YES;

        [self consumeToken];
    }
    else {
        NSLog(@"%@", [self tokenValue:[self currentToken]]);
        [self addError:[NSString stringWithFormat:@"Expected 'name' or '(expression)' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        [self skipLine];
    }
    
    return nil;
}

- (LXTypeNode *)parseTypeNode {
    LXTypeNode *node = [[LXTypeNode alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
    
    if(![_current isType]) {
        [self addError:[NSString stringWithFormat:@"Expected 'type' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
    }
    
    NSString *type = [self tokenValue:_current];
    LXClass *variableType = [self findType:type];
    
    node.type = variableType;
    _current.variableType = variableType;
    
    [self consumeToken];
    
    return node;
}

- (LXVariableNode *)parseVariableNode:(LXClass *)type {
    LXVariableNode *node = [[LXVariableNode alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
    
    if(_current.type != LX_TK_NAME) {
        [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
    }

    NSString *name = [self tokenValue:_current];
    LXVariable *variable = [_currentScope createVariable:name type:type];
    
    node.variable = variable;
    _current.variable = variable;
    
    [self consumeToken];
    
    return node;
}

- (LXFunctionExpr *)parseFunction:(BOOL)anonymous isLocal:(BOOL)isLocal class:(NSString *)class {
    LXFunctionExpr *functionExpr = [[LXFunctionExpr alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
    
    functionExpr.isStatic = ([self consumeTokenType:LX_TK_STATIC] != nil);
    
    LXScope *functionScope = [self pushScope:_currentScope openScope:NO];
    functionScope.type = LXScopeTypeFunction;
    
    BOOL checkingReturnType = NO;
    BOOL hasReturnType = NO;
    BOOL hasEmptyReturnType = NO;
    
    NSMutableArray *returnTypes = [[NSMutableArray alloc] init];
    
    if(_current.type == '(') {
        checkingReturnType = YES;
        
        [self consumeToken:LXTokenCompletionFlagsTypes];
        
        if(_current.type == ')' ||
           (([_current isType] || _current.type == LX_TK_DOTS) &&
            (_next.type == ',' || _next.type == ')'))) {
               hasReturnType = YES;
               
               while(_current.type != ')') {
                   if([_current isType]) {
                       [returnTypes addObject:[self parseTypeNode]];
                       
                       if(_current.type == ',') {
                           [self consumeToken:LXTokenCompletionFlagsTypes];
                       }
                       else {
                           break;
                       }
                   }
                   else if(_current.type == LX_TK_DOTS) {
                       [self consumeToken];
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
               
               [self consumeToken];
           }
    }
    
    functionExpr.returnTypes = returnTypes;
    
    LXVariable *function = nil;
    
    if(!anonymous) {
        if(_current.type == LX_TK_NAME) {
            NSString *functionName = [self tokenValue:_current];

            if(class) {
                //[node addAnonymousChunk:[NSString stringWithFormat:@"%@%c", class, isStatic ? '.' : ':']];
            }
            
            if(isLocal) {
                function = [_currentScope localVariable:functionName];
                
                if(function) {
                    //ERROR
                }
                else {
                    function = [_currentScope createFunction:functionName];
                }
            }
            else {
                function = [self.compiler.globalScope createFunction:functionName];
                [definedVariables addObject:functionName];
            }
            
            _current.variable = function;
            
            [self consumeToken];
            
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
        }
        
        if(_current.type != '(') {
            [self addError:[NSString stringWithFormat:@"Expected '(' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        }
        
        [self consumeToken:LXTokenCompletionFlagsTypes];
    }
    else {
        if(checkingReturnType && hasReturnType) {
            if(_current.type != '(') {
                if([returnTypes count] == 0) {
                    hasEmptyReturnType = YES;
                }
                else {
                    [self addError:[NSString stringWithFormat:@"Expected '(' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
                }
            }
            else {
                [self consumeToken:LXTokenCompletionFlagsTypes];
            }
        }
    }
    
    BOOL isVarArg = NO;
    NSMutableArray *arguments = [NSMutableArray array];
    
    while(!hasEmptyReturnType && _current.type != ')') {
        if([_current isType]) {
            LXDeclarationNode *declarationNode = [[LXDeclarationNode alloc] initWithLine:_current.line column:_current.column location:_current.range.location];

            declarationNode.type = [self parseTypeNode];
            declarationNode.var = [self parseVariableNode:declarationNode.type.type];

            [arguments addObject:declarationNode];
            
            if(_current.type == ',') {
                [self consumeToken:LXTokenCompletionFlagsTypes];
            }
            else {
                break;
            }
        }
        else if(_current.type == LX_TK_DOTS) {
            isVarArg = YES;
            
            [self consumeToken];
            break;
        }
        else {
            [self addError:[NSString stringWithFormat:@"Expected 'type' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
            break;
        }
    }
    
    functionExpr.args = arguments;
    
    if(!hasEmptyReturnType) {
        if(_current.type != ')') {
            [self addError:[NSString stringWithFormat:@"Expected ')' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        }
        
        [self consumeToken:LXTokenCompletionFlagsBlock];
    }
    
    functionExpr.body = [self parseBlock];
    [self popScope];
    
    if(_current.type != LX_TK_END) {
        [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
    }
    
    [self consumeToken:LXTokenCompletionFlagsBlock];
    
    function.returnTypes = returnTypes;
    function.arguments = arguments;
    function.isStatic = functionExpr.isStatic;
    
    return functionExpr;
}

@end
