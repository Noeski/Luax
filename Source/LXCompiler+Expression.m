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
        expr.opToken = [LXTokenNode tokenNodeWithToken:_current];
        [self consumeToken:LXTokenCompletionFlagsVariables];
        expr.expr = [self parseSubExpression:8];
        
        return [self finish:expr];
    }
    else {
        LXExpr *expr = [self parseSimpleExpression];
        
        do {
            NSValue *priority = priorityDict[@(_current.type)];
            
            if(priority && priority.rangeValue.location > level) {
                //TODO: Test this!
                LXBinaryExpr *binaryExpr = [self nodeWithType:[LXBinaryExpr class]];
                binaryExpr.line = expr.line;
                binaryExpr.column = expr.column;
                binaryExpr.location = expr.location;
                
                binaryExpr.lhs = expr;
                binaryExpr.opToken = [LXTokenNode tokenNodeWithToken:_current];
                [self consumeToken:LXTokenCompletionFlagsVariables];
                
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
    
    return [self finish:expr];
}

- (LXExpr *)parseSimpleExpression {
    switch((NSInteger)_current.type) {
        case LX_TK_NUMBER: {
            LXNumberExpr *expr = [self nodeWithType:[LXNumberExpr class]];
            expr.token = [LXTokenNode tokenNodeWithToken:_current];
            [self consumeToken];
            return [self finish:expr];
        }
            
        case LX_TK_STRING: {
            LXStringExpr *expr = [self nodeWithType:[LXStringExpr class]];
            expr.token = [LXTokenNode tokenNodeWithToken:_current];
            [self consumeToken];
            return [self finish:expr];
        }
            
        case LX_TK_NIL: {
            LXNilExpr *expr = [self nodeWithType:[LXNilExpr class]];
            expr.nilToken = [LXTokenNode tokenNodeWithToken:_current];
            [self consumeToken];
            return [self finish:expr];
        }
            
        case LX_TK_TRUE:
        case LX_TK_FALSE: {
            LXBoolExpr *expr = [self nodeWithType:[LXBoolExpr class]];
            expr.token = [LXTokenNode tokenNodeWithToken:_current];
            [self consumeToken];
            return [self finish:expr];
        }
            
        case LX_TK_DOTS: {
            LXDotsExpr *expr = [self nodeWithType:[LXDotsExpr class]];
            expr.dotsToken = [LXTokenNode tokenNodeWithToken:_current];
            [self consumeToken];
            return [self finish:expr];
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

- (LXFunctionCallExpr *)parseFunctionCall:(LXExpr *)prefix {
    LXFunctionCallExpr *expr = [self nodeWithType:[LXFunctionCallExpr class]];
    expr.line = prefix.line;
    expr.column = prefix.column;
    expr.location = prefix.location;
    
    expr.prefix = prefix;
    expr.assignable = NO;
    
    LXVariable *function = nil;
    
    do {
        if(_current.type == ':') {
            _current.variable = prefix.resultType;
            
            [self consumeToken:LXTokenCompletionFlagsFunctions];
            
            if(_current.type != LX_TK_NAME) {
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
                [self skipLine];
                break;
            }
            
            NSString *name = [self tokenValue:_current];
            [expr setValue:name];
            
            LXClass *type = prefix.resultType.type;
            
            //TODO: It's possible that the type is not defined yet, so we should resolve this after compilation
            if(type.isDefined) {
                for(LXVariable *variable in type.variables) {
                    if([variable isFunction] && [variable.name isEqualToString:name]) {
                        _current.variable = variable;
                        _current.isMember = YES;
                        
                        function = variable;
                        break;
                    }
                }
            }
            
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
            
            expr.args = mutableArgs;
        }
        else if(_current.type == LX_TK_STRING) {
            expr.args = [NSArray arrayWithObject:[self parseSimpleExpression]];
        }
        else if(_current.type == '{') {
            expr.args = [NSArray arrayWithObject:[self parseTable]];
        }
        
        LXVariable *variable = [function.returnTypes count] ? function.returnTypes[0] : nil;
        
        expr.resultType = variable;
        _previous.variable = variable;
    } while(NO);
    
    return expr;
}

- (LXExpr *)parseSuffixedExpression {
    LXExpr *expression = [self parsePrimaryExpression];
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
            LXMemberExpr *memberExpression = [[LXMemberExpr alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
            memberExpression.prefix = lastExpression;
            memberExpression.value = name;
            memberExpression.assignable = YES;
            
            LXClass *type = lastExpression.resultType.type;
            
            if(type.isDefined) {
                for(LXVariable *variable in type.variables) {
                    if([variable.name isEqualToString:name]) {
                        _current.variable = variable;
                        _current.isMember = YES;
                        
                        memberExpression.resultType = variable;
                        break;
                    }
                }
            }
            
            [self consumeToken];
            
            expression = memberExpression;
        }
        else if(_current.type == '[') {
            [self consumeToken:LXTokenCompletionFlagsVariables];
            
            LXIndexExpr *indexExpression = [[LXIndexExpr alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
            indexExpression.prefix = lastExpression;
            indexExpression.expr = [self parseExpression];
            indexExpression.assignable = YES;
            
            if(_current.type != ']') {
                [self addError:[NSString stringWithFormat:@"Expected ']' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
                [self skipLine];
                break;
            }
            
            [self consumeToken];
            
            expression = indexExpression;
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
        return expr;
    }
    else if(_current.type == LX_TK_NAME) {
        NSString *name = [self tokenValue:_current];
        LXVariable *variable = [_currentScope variable:name];
        
        if(!variable) {
            variable = [self.compiler.globalScope createVariable:name type:nil];
            [definedVariables addObject:variable];
            
            [self addError:[NSString stringWithFormat:@"Global variable '%@' not defined", variable.name] range:_current.range line:_current.line column:_current.column];
        }
        
        _current.variable = variable;

        LXVariableExpr *expr = [[LXVariableExpr alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
        expr.isMember = variable.isMember;
        expr.resultType = variable;
        expr.assignable = YES;

        [self consumeToken];
        return expr;
    }
    else {
        LXExpr *emptyExpr = [[LXExpr alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
        NSLog(@"%@", [self tokenValue:[self currentToken]]);
        [self addError:[NSString stringWithFormat:@"Expected 'name' or '(expression)' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        [self skipLine];
        
        return emptyExpr;
    }
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

- (LXVariableNode *)parseVariableNode:(LXClass *)type isLocal:(BOOL)isLocal {
    LXVariableNode *node = [[LXVariableNode alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
    
    if(_current.type != LX_TK_NAME) {
        [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
    }

    NSString *name = [self tokenValue:_current];
    
    LXVariable *variable = nil;
    
    if(isLocal) {
        variable = [_currentScope localVariable:name];
        
        if(variable) {
            [self addError:[NSString stringWithFormat:@"Variable %@ is already defined.", name] range:_current.range line:_current.line column:_current.column];
        }
        else {
            variable = [_currentScope createVariable:name type:type];
            variable.definedLocation = _current.range.location;
        }
    }
    else {

        variable = [self.compiler.globalScope localVariable:name];
        
        if(variable) {
            if(variable.isDefined) {
                [self addError:[NSString stringWithFormat:@"Variable %@ is already defined.", name] range:_current.range line:_current.line column:_current.column];
            }
            else {
                variable.type = type;
            }
        }
        else {
            variable = [self.compiler.globalScope createVariable:name type:type];
            [definedVariables addObject:variable];
        }
    }
    
    node.variable = variable;
    _current.variable = variable;
    
    [self consumeToken];
    
    return node;
}

- (LXFunctionExpr *)parseFunction:(BOOL)anonymous isLocal:(BOOL)isLocal class:(NSString *)class {
    LXFunctionExpr *functionExpr = [[LXFunctionExpr alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
    
    functionExpr.isStatic = ([self consumeTokenType:LX_TK_STATIC] != nil);
    
    [self consumeToken];
    
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
                function = [functionScope.parent localVariable:functionName];
                
                if(function) {
                    //ERROR
                }
                else {
                    function = [functionScope.parent createFunction:functionName];
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
            declarationNode.var = [self parseVariableNode:declarationNode.type.type isLocal:YES];

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
    
    //Build Function    
    for(LXTypeNode *returnType in returnTypes) {
        LXClass *type = returnType.type;
    }
    
    for(LXDeclarationNode *argument in arguments) {
        LXVariable *variable = argument.var;
    }
    
    //function.returnTypes = returnTypes;
    //function.arguments = arguments;
    function.isStatic = functionExpr.isStatic;
    
    return functionExpr;
}

@end
