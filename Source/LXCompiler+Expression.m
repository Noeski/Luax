//
//  LXCompiler+Expression.m
//  Luax
//
//  Created by Noah Hilt on 2/2/14.
//  Copyright (c) 2014 Noah Hilt. All rights reserved.
//

#import "LXCompiler+Expression.h"

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

- (LXExpr *)parseTable {
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
            //[expression addChild:[self parseFunction:scope anonymous:YES isLocal:YES function:NULL class:nil]];
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

- (LXExpr *)parseSuffixedExpression {
    LXExpr *expression = [self parsePrimaryExpression];
    LXExpr *lastExpression = expression;
    
    do {
        if(_current.type == '.' ||
           _current.type == ':') {
            _current.variable = lastExpression.variable;
            [self consumeToken:_current.type == ':' ? LXTokenCompletionFlagsFunctions :LXTokenCompletionFlagsMembers];
            
            if(_current.type != LX_TK_NAME) {
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
                [self skipLine];
                break;
            }
            
            NSString *name = [self tokenValue:_current];
            expression = [[LXVariableExpr alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
            expression.value = name;
            expression.assignable = YES;
            
            LXClass *type = lastExpression.variable.type;
            
            if(type.isDefined) {
                for(LXVariable *v in type.variables) {
                    if([v.name isEqualToString:name]) {
                        _current.variable = v;
                        _current.isMember = YES;
                        expression.variable = v;
                        break;
                    }
                }
            }
            
            [self consumeToken];
        }
        else if(_current.type == '[') {
            [self consumeToken:LXTokenCompletionFlagsVariables];
            
            [expression addChild:[self parseExpression:scope]];
            
            LXToken *endBracketToken = [self currentToken];
            
            if(endBracketToken.type != ']') {
                [self addError:[NSString stringWithFormat:@"Expected ']' near: %@", [self tokenValue:endBracketToken]] range:endBracketToken.range line:endBracketToken.line column:endBracketToken.column];
                [self skipLine];
                break;
            }
            
            [self consumeToken];
            [expression addChunk:@"]" line:endBracketToken.line column:endBracketToken.column];
            expression.assignable = YES;
        }
        else if(_current.type == '(') {
            [self consumeToken:LXTokenCompletionFlagsVariables];
            
            [expression addChunk:@"(" line:token.line column:token.column];
            
            LXToken *endParenToken = [self currentToken];
            
            while(endParenToken.type != ')') {
                [expression addChild:[self parseExpression:scope]];
                
                endParenToken = [self currentToken];
                
                if(endParenToken.type != ',') {
                    if(endParenToken.type != ')') {
                        [self addError:[NSString stringWithFormat:@"Expected ')' near: %@", [self tokenValue:endParenToken]] range:endParenToken.range line:endParenToken.line column:endParenToken.column];
                        break;
                    }
                }
                else {
                    [self consumeToken:LXTokenCompletionFlagsVariables];
                    
                    [expression addChunk:@"," line:endParenToken.line column:endParenToken.column];
                }
            }
            
            [self consumeToken];
            
            [expression addChunk:@")" line:endParenToken.line column:endParenToken.column];
            expression.assignable = NO;
            
            if(lastExpression.variable.isFunction) {
                LXVariable *function = lastExpression.variable;
                LXVariable *variable = [function.returnTypes count] ? function.returnTypes[0] : nil;
                
                expression.variable = variable;
                endParenToken.variable = variable;
            }
        }
        else if(!onlyDotColon && token.type == LX_TK_STRING) {
            [self consumeToken];
            
            [expression addChunk:[self tokenValue:token] line:token.line column:token.column];
            expression.assignable = NO;
            
            if(lastExpression.variable.isFunction) {
                LXVariable *function = lastExpression.variable;
                LXVariable *variable = [function.returnTypes count] ? function.returnTypes[0] : nil;
                
                expression.variable = variable;
                token.variable = variable;
            }
        }
        else if(!onlyDotColon && token.type == '{') {
            [expression addChild:[self parseExpression:scope]];
            expression.assignable = NO;
            
            if(lastExpression.variable.isFunction) {
                expression.variable = [lastExpression.variable.returnTypes count] ? lastExpression.variable.returnTypes[0] : nil;
            }
        }
        else {
            break;
        }
        
        [lastExpression addChild:expression];
        lastExpression = expression;
    }
    while(YES);
    
    expression.assignable = lastExpression.assignable;
    
    return expression;
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
        
        _current.variable = expr.variable;

        [self consumeToken:LXTokenCompletionFlagsControlStructures];
        
        expr.assignable = NO;
    }
    else if(_current.type == LX_TK_NAME) {
        NSString *name = [self tokenValue:_current];
        LXVariable *variable = [scope variable:name];
        
        if(!variable) {
            variable = [self.compiler.globalScope createVariable:name type:nil];
            [definedVariables addObject:variable];
            
            [self addError:[NSString stringWithFormat:@"Global variable %@ not defined", variable.name] range:_current.range line:_current.line column:_current.column];
        }
        
        _current.variable = variable;

        LXVariableExpr *expr = [[LXVariableExpr alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
        expr.isMember = variable.isMember;
        expr.variable = variable;
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

@end
