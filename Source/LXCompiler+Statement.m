//
//  LXCompiler+Statement.m
//  Luax
//
//  Created by Noah Hilt on 2/3/14.
//  Copyright (c) 2014 Noah Hilt. All rights reserved.
//

#import "LXCompiler+Statement.h"
#import "LXCompiler+Expression.h"

@implementation LXContext(Statement)

- (LXIfStmt *)parseIfStatement {
    LXIfStmt *statement = [self nodeWithType:[LXIfStmt class]];
    
    statement.ifToken = [self consumeTokenNode];
    statement.expr = [self parseExpression];
    
    if(_current.type != LX_TK_THEN) {
        [self addError:[NSString stringWithFormat:@"Expected 'then' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        [self skipLine];
    }
    
    statement.thenToken = [self consumeTokenNode];
    statement.body = [self parseBlock];
    
    NSMutableArray *mutableElseIfStmts = [[NSMutableArray alloc] init];
    
    while(_current.type == LX_TK_ELSEIF) {
        [mutableElseIfStmts addObject:[self parseElseIfStatement]];
    }
    
    statement.elseIfStmts = mutableElseIfStmts;
    
    if(_current.type == LX_TK_ELSE) {
        statement.elseToken = [self consumeTokenNode];
        statement.elseStmt = [self parseBlock];
    }
    
    if(_current.type != LX_TK_END) {
        [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        //[self skipLine];
    }
    
    statement.endToken = [self consumeTokenNode];

    return [self finish:statement];
}

- (LXElseIfStmt *)parseElseIfStatement {
    LXElseIfStmt *statement = [self nodeWithType:[LXElseIfStmt class]];
    statement.elseIfToken = [self consumeTokenNode];
    statement.expr = [self parseExpression];
    
    if(_current.type != LX_TK_THEN) {
        [self addError:[NSString stringWithFormat:@"Expected 'then' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        [self skipLine];
    }
    
    statement.thenToken = [self consumeTokenNode];
    statement.body = [self parseBlock];
    
    return [self finish:statement];
}

- (LXWhileStmt *)parseWhileStatement {
    LXWhileStmt *statement = [self nodeWithType:[LXWhileStmt class]];
    statement.whileToken = [self consumeTokenNode];
    statement.expr = [self parseExpression];
    
    if(_current.type != LX_TK_DO) {
        [self addError:[NSString stringWithFormat:@"Expected 'do' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        [self skipLine];
    }
    
    statement.doToken = [self consumeTokenNode];
    statement.body = [self parseBlock];
    
    if(_current.type != LX_TK_END) {
        [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        //[self skipLine];
    }
    
    statement.endToken = [self consumeTokenNode];
    
    return [self finish:statement];
}

- (LXDoStmt *)parseDoStatement {
    LXDoStmt *statement = [self nodeWithType:[LXDoStmt class]];
    statement.doToken = [self consumeTokenNode];
    statement.body = [self parseBlock];
    
    if(_current.type != LX_TK_END) {
        [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        //[self skipLine];
    }
    
    statement.endToken = [self consumeTokenNode];
    
    return [self finish:statement];
}

- (LXForStmt *)parseForStatement {
    //TODO: We need to check 2 tokens ahead.. how can we do this?
    [self consumeToken:LXTokenCompletionFlagsTypes | LXTokenCompletionFlagsVariables];
    
    if(![_current isType]) {
        [self addError:[NSString stringWithFormat:@"Expected 'name' or 'type' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        [self skipLine];
    }
    
    LXForStmt *statement = nil;
    
    if(_next.type == '=') {
        LXNumericForStmt *numericForStatement = [self nodeWithType:[LXNumericForStmt class]];
        
        NSString *name = [self tokenValue:_current];
        [self consumeToken];
        
        numericForStatement.equalsToken = [self consumeTokenNode];
        numericForStatement.exprInit = [self parseExpression];
        
        if(_current.type != ',') {
            [self addError:[NSString stringWithFormat:@"Expected ',' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
            [self skipLine];
        }
        
        numericForStatement.exprCondCommaToken = [self consumeTokenNode];
        numericForStatement.exprCond = [self parseExpression];
        
        if(_current.type == ',') {
            numericForStatement.exprIncCommaToken = [self consumeTokenNode];
            numericForStatement.exprInc = [self parseExpression];
        }
        
        statement = numericForStatement;
    }
    else {
        LXIteratorForStmt *iteratorForStatement = [[LXIteratorForStmt alloc] initWithLine:_current.line column:_current.column location:_current.range.location];

        NSMutableArray *mutableVars = [[NSMutableArray alloc] init];
        
        do {
            if(![_current isType]) {
                [self addError:[NSString stringWithFormat:@"Expected 'name' or 'type' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
                [self skipLine];
            }
            
            if(_next.type != LX_TK_NAME) {
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:_next]] range:_next.range line:_next.line column:_next.column];
                [self skipLine];
            }
            
            [self consumeToken];
            [self consumeToken];
        } while([self consumeTokenType:','] != nil);
        
        iteratorForStatement.vars = mutableVars;
        
        if(_current.type != LX_TK_IN) {
            [self addError:[NSString stringWithFormat:@"Expected 'in' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
            [self skipLine];
        }
        
        [self consumeToken];
        
        NSMutableArray *mutableExprs = [[NSMutableArray alloc] init];
        
        do {
            [mutableExprs addObject:[self parseExpression]];
            
            if(_current.type == ',') {
                [self consumeToken];
            }
            else {
                break;
            }
        } while(YES);
        
        iteratorForStatement.exprs = mutableExprs;
        
        statement = iteratorForStatement;
    }
    
    if(_current.type != LX_TK_DO) {
        [self addError:[NSString stringWithFormat:@"Expected 'do' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        [self skipLine];
    }
    
    [self consumeToken:LXTokenCompletionFlagsBlock];
    
    statement.body = [self parseBlock];
    
    if(_current.type != LX_TK_END) {
        [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        //[self skipLine];
    }
    
    [self consumeToken:LXTokenCompletionFlagsBlock];
    
    return statement;
}

- (LXRepeatStmt *)parseRepeatStatement {
    LXRepeatStmt *statement = [self nodeWithType:[LXRepeatStmt class]];
    statement.repeatToken = [self consumeTokenNode];
    statement.body = [self parseBlock];
    
    if(_current.type != LX_TK_UNTIL) {
        [self addError:[NSString stringWithFormat:@"Expected 'until' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        [self skipLine];
    }
    
    statement.untilToken = [self consumeTokenNode];
    statement.expr = [self parseExpression];
    
    return [self finish:statement];
}

- (LXStmt *)parseDeclarationStatement {
    LXDeclarationStmt *statement = [self nodeWithType:[LXDeclarationStmt class]];
    
    if(_current.type == LX_TK_LOCAL) {
        statement.scopeToken = [self consumeTokenNode];
        statement.isGlobal = NO;
    }
    else if(_current.type == LX_TK_GLOBAL) {
        statement.scopeToken = [self consumeTokenNode];
        statement.isGlobal = YES;
    }
    
    statement.typeToken = [self consumeTokenNode];
    
    NSMutableArray *mutableVars = [[NSMutableArray alloc] init];

    do {
        if(_current.type != LX_TK_NAME) {
            [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
            break;
        }
        
        [mutableVars addObject:[self consumeTokenNode]];
        
        if(_current.type == ',') {
            [mutableVars addObject:[self consumeTokenNode]];
        }
        else {
            break;
        }
    } while(YES);
    
    statement.vars = mutableVars;
    
    NSMutableArray *mutableExprs = [[NSMutableArray alloc] init];
    
    if(_current.type == '=') {
        statement.equalsToken = [self consumeTokenNode];
        
        do {
            [mutableExprs addObject:[self parseExpression]];
            
            if(_current.type == ',') {
                [mutableExprs addObject:[self consumeTokenNode]];
            }
            else {
                break;
            }
        } while(YES);
    }
    
    statement.exprs = mutableExprs;
    
    return [self finish:statement];
}

- (LXStmt *)parseExpressionStatement {
    LXAssignmentStmt *statement = [self nodeWithType:[LXAssignmentStmt class]];
    
    NSMutableArray *mutableVars = [[NSMutableArray alloc] init];
    
    do {
        [mutableVars addObject:[self parseSuffixedExpression]];
        
        if(_current.type == ',') {
            [mutableVars addObject:[self consumeTokenNode]];
        }
        else {
            break;
        }
    } while(YES);
    
    statement.vars = mutableVars;
    
    NSMutableArray *mutableExprs = [[NSMutableArray alloc] init];
    
    if([_current isAssignmentOperator]) {
        statement.equalsToken = [self consumeTokenNode];
        
        do {
            [mutableExprs addObject:[self parseExpression]];
            
            if(_current.type == ',') {
                [mutableExprs addObject:[self consumeTokenNode]];
            }
            else {
                break;
            }
        } while(YES);
    }
    
    statement.exprs = mutableExprs;
    
    return [self finish:statement];
}

- (LXBlock *)parseBlock {
    static __strong NSDictionary *closeKeywords = nil;
  
    if(!closeKeywords)
        closeKeywords = @{@(LX_TK_END) : @YES, @(LX_TK_ELSE) : @YES, @(LX_TK_ELSEIF) : @YES, @(LX_TK_UNTIL) : @YES};
    
    LXBlock *block = [[LXBlock alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
    NSMutableArray *mutableStmts = [[NSMutableArray alloc] init];
    
    while(!closeKeywords[@(_current.type)] && _current.type != LX_TK_EOS) {
        [mutableStmts addObject:[self parseStatement]];
    }
    
    block.stmts = mutableStmts;
    
    return [self finish:block];
}

- (LXClassStmt *)parseClassStatement {
    LXClassStmt *statement = [self nodeWithType:[LXClassStmt class]];
    statement.classToken = [self consumeTokenNode];
    
    NSMutableArray *mutableFunctions = [[NSMutableArray alloc] init];
    NSMutableArray *mutableVariables = [[NSMutableArray alloc] init];
    
    if(_current.type != LX_TK_NAME) {
        [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
    }
    
    statement.nameToken = [self consumeTokenNode];
    
    if(_current.type == LX_TK_EXTENDS) {
        statement.extendsToken = [self consumeTokenNode];
        
        if(![_current isType]) {
            [self addError:[NSString stringWithFormat:@"Expected 'name' or 'type' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        }
        
        statement.superToken = [self consumeTokenNode];
    }
    
    while(_current.type != LX_TK_END) {
        if(_current.type == LX_TK_STATIC || _current.type == LX_TK_FUNCTION) {
            [mutableFunctions addObject:[self parseFunction:NO]];
        }
        else if([_current isType]) {
            [mutableVariables addObject:[self parseDeclarationStatement]];
        }
        else {
            [self addError:[NSString stringWithFormat:@"Expected function or variable declaration near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
            break;
        }
    }
    
    if(_current.type != LX_TK_END) {
        [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
    }
    
    statement.vars = mutableVariables;
    statement.functions = mutableFunctions;
    statement.endToken = [self consumeTokenNode];
    
    return [self finish:statement];
}

- (LXStmt *)parseStatement {
    switch(_current.type) {
        case LX_TK_IF:
            return [self parseIfStatement];
        case LX_TK_WHILE:
            return [self parseWhileStatement];
        case LX_TK_DO:
            return [self parseDoStatement];
        case LX_TK_FOR:
            return [self parseForStatement];
        case LX_TK_REPEAT:
            return [self parseRepeatStatement];
        case LX_TK_FUNCTION: {
            LXExprStmt *statement = [self nodeWithType:[LXExprStmt class]];
            statement.expr = [self parseFunction:NO];
            
            return [self finish:statement];
        }
        case LX_TK_CLASS:
            return [self parseClassStatement];
        case LX_TK_DBCOLON: {
            LXLabelStmt *statement = [self nodeWithType:[LXLabelStmt class]];
            statement.beginLabelToken = [self consumeTokenNode];
            
            if(_current.type != LX_TK_NAME) {
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
                //[self skipLine];
            }
            
            statement.value = [self tokenValue:_current];
            [self consumeToken];
            
            if(_current.type != LX_TK_DBCOLON) {
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
                //[self skipLine];
            }
            
            statement.endLabelToken = [self consumeTokenNode];

            return [self finish:statement];
        }
        case LX_TK_GOTO: {
            LXGotoStmt *statement = [self nodeWithType:[LXGotoStmt class]];
            statement.gotoToken = [self consumeTokenNode];
            
            if(_current.type != LX_TK_NAME) {
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
                //[self skipLine];
            }
            
            statement.value = [self tokenValue:_current];
            [self consumeToken:LXTokenCompletionFlagsBlock];
            
            return [self finish:statement];
        }
        case LX_TK_BREAK: {
            LXBreakStmt *statement = [self nodeWithType:[LXBreakStmt class]];
            statement.breakToken = [self consumeTokenNode];
            
            return [self finish:statement];
        }
        case LX_TK_RETURN: {
            LXReturnStmt *statement = [self nodeWithType:[LXReturnStmt class]];
            statement.returnToken = [self consumeTokenNode];
            
            NSMutableArray *mutableExprs = [[NSMutableArray alloc] init];
            
            if(_current.type != LX_TK_END) {
                do {
                    [mutableExprs addObject:[self parseExpression]];
                    
                    if(_current.type == ',') {
                        [mutableExprs addObject:[self consumeTokenNode]];
                    }
                    else {
                        break;
                    }
                } while(YES);
            }

            statement.exprs = mutableExprs;
            
            return [self finish:statement];
        }
        case ';': {
            LXEmptyStmt *statement = [self nodeWithType:[LXEmptyStmt class]];
            statement.token = [self consumeTokenNode];
            
            return [self finish:statement];
        }
        case LX_TK_LOCAL:
        case LX_TK_GLOBAL: {
            if(_next.type == LX_TK_FUNCTION) {
                LXExprStmt *statement = [self nodeWithType:[LXExprStmt class]];
                statement.expr = [self parseFunction:NO];
                
                return [self finish:statement];
            }
            else {
                return [self parseDeclarationStatement];
            }
        }
            
        default: {
            LXVariable *classVariable = [_currentScope variable:[self tokenValue:_current]];
            
            if([_current isType] && _next.type == LX_TK_NAME &&
               (!classVariable || classVariable.isClass)) {
                return [self parseDeclarationStatement];
            }
            else {
                return [self parseExpressionStatement];
            }
        }
    }
    
    return nil;
}

@end
