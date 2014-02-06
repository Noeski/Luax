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

- (id)parseTable {
    return nil;
}

- (LXExpr *)parseSimpleExpression {
    switch((NSInteger)_current.type) {
        case LX_TK_NUMBER: {
            LXNumberExpression *expr = [[LXNumberExpression alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
            expr.value = [self tokenValue:_current];
            [self consumeToken];
            return expr;
        }
            
        case LX_TK_STRING: {
            LXStringExpression *expr = [[LXStringExpression alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
            expr.value = [self tokenValue:_current];
            [self consumeToken];
            return expr;
        }
            
        case LX_TK_NIL: {
            LXNilExpression *expr = [[LXNilExpression alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
            [self consumeToken];
            return expr;
        }
            
        case LX_TK_TRUE:
        case LX_TK_FALSE: {
            LXBoolExpression *expr = [[LXBoolExpression alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
            expr.value = [self tokenValue:_current];
            [self consumeToken];
            return expr;
        }
            
        case LX_TK_DOTS: {
            LXDotsExpression *expr = [[LXDotsExpression alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
            [self consumeToken];
            return expr;
        }
            
        case LX_TK_FUNCTION: {
            //[expression addChild:[self parseFunction:scope anonymous:YES isLocal:YES function:NULL class:nil]];
            break;
        }
            
        case '{': {
            return [self parseTable];
            
            /*[self consumeToken:LXTokenCompletionFlagsVariables];
            [expression addChunk:@"{" line:token.line column:token.column];
            
            do {
                token = [self currentToken];
                
                if(token.type == '[') {
                    [self consumeToken:LXTokenCompletionFlagsVariables];
                    
                    [expression addChunk:@"[" line:token.line column:token.column];
                    [expression addChild:[self parseExpression:scope]];
                    
                    LXToken *endBracketToken = [self currentToken];
                    
                    if(endBracketToken.type != ']') {
                        [self addError:[NSString stringWithFormat:@"Expected ']' near: %@", [self tokenValue:endBracketToken]] range:endBracketToken.range line:endBracketToken.line column:endBracketToken.column];
                        break;
                    }
                    
                    [self consumeToken];
                    
                    [expression addChunk:@"]" line:endBracketToken.line column:endBracketToken.column];
                    
                    LXToken *equalsToken = [self currentToken];
                    
                    if(equalsToken.type != '=') {
                        [self addError:[NSString stringWithFormat:@"Expected '=' near: %@", [self tokenValue:equalsToken]] range:equalsToken.range line:equalsToken.line column:equalsToken.column];
                        break;
                    }
                    
                    [self consumeToken:LXTokenCompletionFlagsVariables];
                    
                    [expression addChunk:@"=" line:equalsToken.line column:equalsToken.column];
                    [expression addChild:[self parseExpression:scope]];
                }
                else if(token.type == LX_TK_NAME) {
                    [expression addChild:[self parseExpression:scope]];
                    
                    LXToken *equalsToken = [self currentToken];
                    
                    if(equalsToken.type == '=') {
                        [self consumeToken:LXTokenCompletionFlagsVariables];
                        
                        [expression addChunk:@"=" line:equalsToken.line column:equalsToken.column];
                        [expression addChild:[self parseExpression:scope]];
                    }
                }
                else if(token.type == '}') {
                    [self consumeToken];
                    
                    [expression addChunk:@"}" line:token.line column:token.column];
                    break;
                }
                else {
                    [expression addChild:[self parseExpression:scope]];
                }
                
                token = [self currentToken];
                
                if(token.type ==';' || token.type == ',') {
                    [self consumeToken:LXTokenCompletionFlagsVariables];
                    
                    [expression addChunk:@"," line:token.line column:token.column];
                }
                else if(token.type == '}') {
                    [self consumeToken];
                    
                    [expression addChunk:@"}" line:token.line column:token.column];
                    break;
                }
                else {
                    [self addError:[NSString stringWithFormat:@"Expected ';', ',' or '}' near: %@", [self tokenValue:token]] range:token.range line:token.line column:token.column];
                    break;
                }
            } while(YES);
            
            break;*/
        }
            
        default: {
            return [self parseSuffixedExpression:NO];
        }
    }
    
    return nil;
}

- (LXExpr *)parseSuffixedExpression {
    /*LXExpr *expression = [self parsePrimaryExpression];
    LXExpr *lastExpression = expression;
    
    do {
        if(_current.type == '.' ||
           _current.type == ':') {
            //_current.variable = lastExpression.variable;
            //[self consumeToken:token.type == ':' ? LXTokenCompletionFlagsFunctions :LXTokenCompletionFlagsMembers];
            
            //[expression addChunk:token.type == ':' ? @":" : @"." line:token.line column:token.column];
            
            if(_current.type != LX_TK_NAME) {
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
                [self skipLine];
                break;
            }
            
            NSString *name = [self tokenValue:_current];
            
            [self consumeToken];
            //[expression addNamedChunk:name line:nameToken.line column:nameToken.column];
            //expression.assignable = YES;
            
            LXClass *type = lastExpression.variable.type;
            
            if(type.isDefined) {
                for(LXVariable *v in type.variables) {
                    if([v.name isEqualToString:name]) {
                        nameToken.variable = v;
                        nameToken.isMember = YES;
                        expression.variable = v;
                        break;
                    }
                }
            }
        }
        else if(_current.type == '[') {
            [self consumeToken:LXTokenCompletionFlagsVariables];
            
            [expression addChunk:@"[" line:token.line column:token.column];
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
    
    return expression;*/
}

- (LXExpr *)parsePrimaryExpression {
    if(_current.type == '(') {
        [self consumeToken:LXTokenCompletionFlagsVariables];
        
        [expression addChunk:@"(" line:token.line column:token.column];
        
        LXExpr *expr = [self parseExpression];
        
        if(_current.type != ')') {
            [self addError:[NSString stringWithFormat:@"Expected ')' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
            [self skipLine];
            return expr;
        }
        
        _current.variable = expr.variable;

        [self consumeToken:LXTokenCompletionFlagsControlStructures];
        
        expr.variable = subExpression.variable;
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
        
        if(variable.isMember) {
            //[expression addAnonymousChunk:@"self."];
        }
        
        [self consumeToken];
        
        token.variable = variable;
        expression.variable = variable;
        expression.assignable = YES;
    }
    else {
        NSLog(@"%@", [self tokenValue:[self currentToken]]);
        [self addError:[NSString stringWithFormat:@"Expected 'name' or '(expression)' near: %@", [self tokenValue:token]] range:token.range line:token.line column:token.column];
        [self skipLine];
    }
    
    return expression;
}

@end
