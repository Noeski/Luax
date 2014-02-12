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
    
    statement.ifToken = [LXTokenNode tokenNodeWithToken:_current];
    
    [self consumeToken:LXTokenCompletionFlagsVariables];

    statement.expr = [self parseExpression];
    
    if(_current.type != LX_TK_THEN) {
        [self addError:[NSString stringWithFormat:@"Expected 'then' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        [self skipLine];
    }
    
    statement.thenToken = [LXTokenNode tokenNodeWithToken:_current];
    [self consumeToken:LXTokenCompletionFlagsBlock];
    
    statement.body = [self parseBlock];
    
    NSMutableArray *mutableElseIfStmts = [[NSMutableArray alloc] init];
    
    while(_current.type == LX_TK_ELSEIF) {
        [mutableElseIfStmts addObject:[self parseElseIfStatement]];
    }
    
    statement.elseIfStmts = mutableElseIfStmts;
    
    if(_current.type == LX_TK_ELSE) {
        statement.elseToken = [LXTokenNode tokenNodeWithToken:_current];

        [self consumeToken:LXTokenCompletionFlagsBlock];

        statement.elseStmt = [self parseBlock];
    }
    
    if(_current.type != LX_TK_END) {
        [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        //[self skipLine];
    }
    
    statement.endToken = [LXTokenNode tokenNodeWithToken:_current];
    [self consumeToken:LXTokenCompletionFlagsBlock];

    return [self finish:statement];
}

- (LXElseIfStmt *)parseElseIfStatement {
    LXElseIfStmt *statement = [self nodeWithType:[LXElseIfStmt class]];
    statement.elseIfToken = [LXTokenNode tokenNodeWithToken:_current];
    [self consumeToken:LXTokenCompletionFlagsVariables];
    
    statement.expr = [self parseExpression];
    
    if(_current.type != LX_TK_THEN) {
        [self addError:[NSString stringWithFormat:@"Expected 'then' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        [self skipLine];
    }
    
    statement.thenToken = [LXTokenNode tokenNodeWithToken:_current];
    [self consumeToken:LXTokenCompletionFlagsBlock];
    
    statement.body = [self parseBlock];
    
    return [self finish:statement];
}

- (LXWhileStmt *)parseWhileStatement {
    LXWhileStmt *statement = [self nodeWithType:[LXWhileStmt class]];
    statement.whileToken = [LXTokenNode tokenNodeWithToken:_current];
    [self consumeToken:LXTokenCompletionFlagsVariables];
    
    statement.expr = [self parseExpression];
    
    if(_current.type != LX_TK_DO) {
        [self addError:[NSString stringWithFormat:@"Expected 'do' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        [self skipLine];
    }
    
    statement.doToken = [LXTokenNode tokenNodeWithToken:_current];
    [self consumeToken:LXTokenCompletionFlagsBlock];
    
    statement.body = [self parseBlock];
    
    if(_current.type != LX_TK_END) {
        [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        //[self skipLine];
    }
    
    statement.endToken = [LXTokenNode tokenNodeWithToken:_current];
    [self consumeToken:LXTokenCompletionFlagsBlock];
    
    return [self finish:statement];
}

- (LXDoStmt *)parseDoStatement {
    LXDoStmt *statement = [self nodeWithType:[LXDoStmt class]];
    statement.doToken = [LXTokenNode tokenNodeWithToken:_current];
    [self consumeToken:LXTokenCompletionFlagsBlock];
    
    statement.body = [self parseBlock];
    
    if(_current.type != LX_TK_END) {
        [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        //[self skipLine];
    }
    
    statement.endToken = [LXTokenNode tokenNodeWithToken:_current];
    [self consumeToken:LXTokenCompletionFlagsBlock];
    
    return statement;
}

- (LXForStmt *)parseForStatement {
    //TODO: We need to check 2 tokens ahead.. how can we do this?
    [self consumeToken:LXTokenCompletionFlagsTypes | LXTokenCompletionFlagsVariables];
    
    LXScope *forScope = [self pushScope:_currentScope openScope:NO];
    
    if(![_current isType]) {
        [self addError:[NSString stringWithFormat:@"Expected 'name' or 'type' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        [self skipLine];
    }
    
    LXForStmt *statement = nil;
    
    if(_next.type == '=') {
        LXNumericForStmt *numericForStatement = [self nodeWithType:[LXNumericForStmt class]];
        
        NSString *name = [self tokenValue:_current];
        
        LXClass *variableType =  [LXClassNumber classNumber];
        LXVariable *variable = [forScope createVariable:name type:variableType];
        
        _current.variable = variable;
        
        [self consumeToken];
        
        numericForStatement.equalsToken = [LXTokenNode tokenNodeWithToken:_current];
        [self consumeToken];

        numericForStatement.exprInit = [self parseExpression];
        
        if(_current.type != ',') {
            [self addError:[NSString stringWithFormat:@"Expected ',' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
            [self skipLine];
        }
        
        numericForStatement.exprCondCommaToken = [LXTokenNode tokenNodeWithToken:_current];
        [self consumeToken];
        
        numericForStatement.exprCond = [self parseExpression];
        
        if(_current.type == ',') {
            numericForStatement.exprIncCommaToken = [LXTokenNode tokenNodeWithToken:_current];
            [self consumeToken];
            
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
            
            NSString *type = [self tokenValue:_current];
            LXClass *variableType = [self findType:type];
            
            NSString *name = [self tokenValue:_next];
            LXVariable *variable = [forScope createVariable:name type:variableType];
            
            _current.variableType = variableType;
            _next.variable = variable;
            
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
    
    [self popScope];
    
    if(_current.type != LX_TK_END) {
        [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        //[self skipLine];
    }
    
    [self consumeToken:LXTokenCompletionFlagsBlock];
    
    return statement;
}

- (LXRepeatStmt *)parseRepeatStatement {
    LXRepeatStmt *statement = [self nodeWithType:[LXRepeatStmt class]];
    statement.repeatToken = [LXTokenNode tokenNodeWithToken:_current];

    [self consumeToken:LXTokenCompletionFlagsBlock];
    
    statement.body = [self parseBlock];
    
    if(_current.type != LX_TK_UNTIL) {
        [self addError:[NSString stringWithFormat:@"Expected 'until' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        [self skipLine];
    }
    
    statement.untilToken = [LXTokenNode tokenNodeWithToken:_current];
    [self consumeToken:LXTokenCompletionFlagsVariables];
    
    statement.expr = [self parseExpression];
    
    return [self finish:statement];
}

- (LXStmt *)parseDeclarationStatement {
    LXDeclarationStmt *statement = [self nodeWithType:[LXDeclarationStmt class]];
    statement.typeToken = [LXTokenNode tokenNodeWithToken:_current];
    
    NSMutableArray *mutableVars = [[NSMutableArray alloc] init];

    do {
        if(_current.type != LX_TK_NAME) {
            [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
            break;
        }
        
        [mutableVars addObject:[LXTokenNode tokenNodeWithToken:_current]];
        
        if(_current.type == ',') {
            [mutableVars addObject:[LXTokenNode tokenNodeWithToken:_current]];
            [self consumeToken:LXTokenCompletionFlagsVariables];
        }
        else {
            break;
        }
    } while(YES);
    
    statement.vars = mutableVars;
    
    NSMutableArray *mutableExprs = [[NSMutableArray alloc] init];
    
    if(_current.type == '=') {
        statement.equalsToken = [LXTokenNode tokenNodeWithToken:_current];
        [self consumeToken:LXTokenCompletionFlagsVariables];
        
        do {
            [mutableExprs addObject:[self parseExpression]];
            
            if(_current.type == ',') {
                [mutableExprs addObject:[LXTokenNode tokenNodeWithToken:_current]];
                [self consumeToken:LXTokenCompletionFlagsVariables];
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
            [mutableVars addObject:[LXTokenNode tokenNodeWithToken:_current]];
            [self consumeToken:LXTokenCompletionFlagsVariables];
        }
        else {
            break;
        }
    } while(YES);
    
    statement.vars = mutableVars;
    
    NSMutableArray *mutableExprs = [[NSMutableArray alloc] init];
    
    if([_current isAssignmentOperator]) {
        statement.equalsToken = [LXTokenNode tokenNodeWithToken:_current];
        [self consumeToken:LXTokenCompletionFlagsVariables];
        
        do {
            [mutableExprs addObject:[self parseExpression]];
            
            if(_current.type == ',') {
                [mutableExprs addObject:[LXTokenNode tokenNodeWithToken:_current]];
                [self consumeToken:LXTokenCompletionFlagsVariables];
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
    
    [self pushScope:_currentScope openScope:YES];

    LXBlock *block = [[LXBlock alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
    NSMutableArray *mutableStmts = [[NSMutableArray alloc] init];
    
    while(!closeKeywords[@(_current.type)] && _current.type != LX_TK_EOS) {
        [mutableStmts addObject:[self parseStatement]];
    }
    
    block.stmts = mutableStmts;
    
    [self popScope];
    
    return block;
}

- (LXClassStmt *)parseClassStatement {
    LXClassStmt *statement = [self nodeWithType:[LXClassStmt class]];
    
    [self consumeToken];
    
    NSMutableArray *mutableFunctions = [[NSMutableArray alloc] init];
    NSMutableArray *mutableVariables = [[NSMutableArray alloc] init];
    
    if(_current.type != LX_TK_NAME) {
        [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
    }
    
    statement.nameToken = [LXTokenNode tokenNodeWithToken:_current];
    [self consumeToken:LXTokenCompletionFlagsClass];
    
    if(_current.type == LX_TK_EXTENDS) {
        statement.extendsToken = [LXTokenNode tokenNodeWithToken:_current];
        [self consumeToken:LXTokenCompletionFlagsTypes];
        
        if(![_current isType]) {
            [self addError:[NSString stringWithFormat:@"Expected 'name' or 'type' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        }
        
        statement.superToken = [LXTokenNode tokenNodeWithToken:_current];
        [self consumeToken:LXTokenCompletionFlagsClass];
    }
    
    while(_current.type != LX_TK_END) {
        if(_current.type == LX_TK_STATIC || _current.type == LX_TK_FUNCTION) {
            [mutableFunctions addObject:[self parseFunction:NO isLocal:YES class:nil]];
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
    
    statement.endToken = [LXTokenNode tokenNodeWithToken:_current];
    [self consumeToken:LXTokenCompletionFlagsBlock];
    
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
            statement.expr = [self parseFunction:NO isLocal:YES class:nil];
            
            return [self finish:statement];
        }
        case LX_TK_CLASS:
            return [self parseClassStatement];
        case LX_TK_DBCOLON: {
            LXLabelStmt *statement = [self nodeWithType:[LXLabelStmt class]];
            statement.beginLabelToken = [LXTokenNode tokenNodeWithToken:_current];
            [self consumeToken];
            
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
            
            statement.endLabelToken = [LXTokenNode tokenNodeWithToken:_current];
            [self consumeToken:LXTokenCompletionFlagsBlock];

            return [self finish:statement];
        }
        case LX_TK_GOTO: {
            LXGotoStmt *statement = [self nodeWithType:[LXGotoStmt class]];
            statement.gotoToken = [LXTokenNode tokenNodeWithToken:_current];
            [self consumeToken];
            
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
            statement.breakToken = [LXTokenNode tokenNodeWithToken:_current];
            [self consumeToken:LXTokenCompletionFlagsBlock];
            
            return [self finish:statement];
        }
        case LX_TK_RETURN: {
            LXReturnStmt *statement = [self nodeWithType:[LXReturnStmt class]];
            statement.returnToken = [LXTokenNode tokenNodeWithToken:_current];
            [self consumeToken:LXTokenCompletionFlagsVariables];
            
            NSMutableArray *mutableExprs = [[NSMutableArray alloc] init];
            
            if(_current.type != LX_TK_END) {
                do {
                    [mutableExprs addObject:[self parseExpression]];
                    
                    if(_current.type == ',') {
                        [mutableExprs addObject:[LXTokenNode tokenNodeWithToken:_current]];
                        [self consumeToken:LXTokenCompletionFlagsVariables];
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
            statement.token = [LXTokenNode tokenNodeWithToken:_current];
            [self consumeToken:LXTokenCompletionFlagsBlock];
            
            return [self finish:statement];
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
            break;
    }
    
    return nil;
}
    /*BOOL isLocal = ![scope isGlobalScope];
    
    if([self consumeTokenType:LX_TK_LOCAL] != nil) {
        isLocal = YES;
    }
    else if([self consumeTokenType:LX_TK_GLOBAL] != nil) {
        isLocal = NO;
    }
    
    LXToken *current = [self currentToken];
    LXNode *statement = [[LXNode alloc] initWithLine:current.startLine column:current.column];
    
    switch((NSInteger)current.type) {
        case LX_TK_FOR: {
     
        case LX_TK_FUNCTION:
            [statement addChild:[self parseFunction:scope anonymous:NO isLocal:isLocal function:NULL class:nil]];
            break;
            
        case LX_TK_CLASS:
            [statement addChild:[self parseClassStatement:scope]];
            break;
}*/

@end
