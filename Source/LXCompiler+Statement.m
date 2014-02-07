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
    LXIfStmt *statement = [[LXIfStmt alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
    [self consumeToken:LXTokenCompletionFlagsVariables];

    statement.expr = [self parseExpression];
    
    if(_current.type != LX_TK_THEN) {
        [self addError:[NSString stringWithFormat:@"Expected 'then' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        [self skipLine];
    }
    
    [self consumeToken:LXTokenCompletionFlagsBlock];
    
    statement.body = [self parseBlock];
    
    NSMutableArray *mutableElseIfStmts = [[NSMutableArray alloc] init];
    
    while(_current.type == LX_TK_ELSEIF) {
        [mutableElseIfStmts addObject:[self parseElseIfStatement]];
    }
    
    statement.elseIfStmts = mutableElseIfStmts;
    
    if(_current.type == LX_TK_ELSE) {
        [self consumeToken:LXTokenCompletionFlagsBlock];

        statement.elseStmt = [self parseBlock];
    }
    
    if(_current.type != LX_TK_END) {
        [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        //[self skipLine];
    }
    
    [self consumeToken:LXTokenCompletionFlagsBlock];
    
    return statement;
}

- (LXElseIfStmt *)parseElseIfStatement {
    LXElseIfStmt *statement = [[LXElseIfStmt alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
    [self consumeToken:LXTokenCompletionFlagsVariables];
    
    statement.expr = [self parseExpression];
    
    if(_current.type != LX_TK_THEN) {
        [self addError:[NSString stringWithFormat:@"Expected 'then' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        [self skipLine];
    }
    
    [self consumeToken:LXTokenCompletionFlagsBlock];
    
    statement.body = [self parseBlock];
    
    return statement;
}

- (LXWhileStmt *)parseWhileStatement {
    LXWhileStmt *statement = [[LXWhileStmt alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
    [self consumeToken:LXTokenCompletionFlagsVariables];
    
    statement.expr = [self parseExpression];
    
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

- (LXDoStmt *)parseDoStatement {
    LXDoStmt *statement = [[LXDoStmt alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
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
    LXRepeatStmt *statement = [[LXRepeatStmt alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
    [self consumeToken:LXTokenCompletionFlagsBlock];
    
    statement.body = [self parseBlock];
    
    if(_current.type != LX_TK_UNTIL) {
        [self addError:[NSString stringWithFormat:@"Expected 'until' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        [self skipLine];
    }
    
    [self consumeToken:LXTokenCompletionFlagsVariables];
    
    statement.expr = [self parseExpression];
    
    return statement;
}

- (LXStmt *)parseDeclarationStatement {
}

- (LXStmt *)parseExpressionStatement {
    LXExpr *expr = [self parseSuffixedExpression];
    
    if(_current.type == ',' || [_current isAssignmentOperator]) {
        LXAssignmentStmt *statement = [[LXAssignmentStmt alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
        
        if(!expr.assignable) {
            [self addError:[NSString stringWithFormat:@"Unexpected assignment token near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        }
        
        NSMutableArray *mutableVars = [NSMutableArray arrayWithObject:expr];
        
        while(_current.type == ',') {
            [self consumeToken:LXTokenCompletionFlagsVariables];
            
            [mutableVars addObject:[self parseSuffixedExpression]];
        }
        
        statement.vars = mutableVars;
        
        if(![_current isAssignmentOperator]) {
            [self addError:[NSString stringWithFormat:@"Expected '=' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
            [self skipLine];
        }
        
        //Assignment Operator
        /*switch((NSInteger)_current.type) {
            case LX_TK_PLUS_EQ: {
                [statement addChunk:@"+" line:assignmentToken.startLine column:assignmentToken.column];
                break;
            }
                
            case LX_TK_MINUS_EQ: {
                [statement addChunk:@"-" line:assignmentToken.startLine column:assignmentToken.column];
                break;
            }
                
            case LX_TK_MULT_EQ: {
                [statement addChunk:@"*" line:assignmentToken.startLine column:assignmentToken.column];
                break;
            }
                
            case LX_TK_DIV_EQ: {
                [statement addChunk:@"/" line:assignmentToken.startLine column:assignmentToken.column];
                break;
            }
                
            case LX_TK_POW_EQ: {
                [statement addChunk:@"^" line:assignmentToken.startLine column:assignmentToken.column];
                break;
            }
                
            case LX_TK_MOD_EQ: {
                [statement addChunk:@"%" line:assignmentToken.startLine column:assignmentToken.column];
                break;
            }
                
            case LX_TK_CONCAT_EQ: {
                [statement addChunk:@".." line:assignmentToken.startLine column:assignmentToken.column];
                break;
            }
                
            default:
                break;
        }*/

        [self consumeToken:LXTokenCompletionFlagsVariables];
        
        NSInteger i = 0;
        
        NSMutableArray *mutableExprs = [[NSMutableArray alloc] init];

        do {
            [mutableExprs addObject:[self parseExpression]];
            
            if(_current.type == ',') {
                [self consumeToken:LXTokenCompletionFlagsVariables];
            }
            else {
                break;
            }
            
            ++i;
        } while(YES);
        
        statement.exprs = mutableExprs;
        
        return statement;
    }
    else {
        if(expr.assignable) {
            [self addError:[NSString stringWithFormat:@"Expected ',' or '=' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        }
        
        LXExprStmt *statement = [[LXExprStmt alloc] initWithLine:expr.line column:expr.column location:expr.range.location];
        statement.expr = expr;
        
        return statement;
    }
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
    
    [self popScope];
    
    return block;
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
        case LX_TK_FUNCTION:
            return [self parseFunctionStatement];
        case LX_TK_CLASS:
            return [self parseClassStatement];
        case LX_TK_DBCOLON: {
            [self consumeToken];
            
            if(_current.type != LX_TK_NAME) {
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
                //[self skipLine];
            }
            
            LXLabelStmt *statement = [[LXLabelStmt alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
            statement.value = [self tokenValue:_current];
            
            [self consumeToken];
            
            if(_current.type != LX_TK_DBCOLON) {
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
                //[self skipLine];
            }
            
            [self consumeToken:LXTokenCompletionFlagsBlock];

            return statement;
        }
        case LX_TK_GOTO: {
            [self consumeToken];
            
            if(_current.type != LX_TK_NAME) {
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
                //[self skipLine];
            }
            
            LXGotoStmt *statement = [[LXGotoStmt alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
            statement.value = [self tokenValue:_current];
            
            [self consumeToken:LXTokenCompletionFlagsBlock];
            return statement;
        }
        case LX_TK_BREAK:
            [self consumeToken:LXTokenCompletionFlagsBlock];
            return [[LXBreakStmt alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
        case LX_TK_RETURN: {
            [self consumeToken:LXTokenCompletionFlagsVariables];
            LXReturnStmt *statement = [[LXReturnStmt alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
            
            NSMutableArray *mutableExprs = [[NSMutableArray alloc] init];
            
            if(_current.type != LX_TK_END) {
                do {
                    [mutableExprs addObject:[self parseExpression]];
                    
                    if(_current.type == ',') {
                        [self consumeToken:LXTokenCompletionFlagsVariables];
                        continue;
                    }
                    
                    break;
                } while(YES);
            }

            statement.exprs = mutableExprs;
            
            return statement;
        }
        case ';':
            [self consumeToken:LXTokenCompletionFlagsBlock];
            return [[LXEmptyStmt alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
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
            [self consumeToken:LXTokenCompletionFlagsTypes | LXTokenCompletionFlagsVariables];
            
            [statement addChunk:@"for" line:current.startLine column:current.column];
            [statement addAnonymousChunk:@" "];
            
            LXScope *forScope = [self pushScope:scope openScope:NO];
            
            LXToken *nameToken = [self currentToken];
            
            if(![nameToken isType]) {
                [self addError:[NSString stringWithFormat:@"Expected 'name' or 'type' near: %@", [self tokenValue:nameToken]] range:nameToken.range line:nameToken.startLine column:nameToken.column];
                [self skipLine];
                break;
            }
            
            [self consumeToken];
            
            if([self currentToken].type == '=') {
                NSString *name = [self tokenValue:nameToken];
                
                [statement addNamedChunk:name line:nameToken.startLine column:nameToken.column];
                
                LXClass *variableType =  [LXClassNumber classNumber];
                LXVariable *variable = [forScope createVariable:name type:variableType];
                
                nameToken.variable = variable;
                
                [statement addChunk:@"=" line:current.startLine column:current.column];
                [self consumeToken];
                
                [statement addChild:[self parseExpression:scope]];
                
                LXToken *commaToken = [self currentToken];
                
                if(commaToken.type != ',') {
                    [self addError:[NSString stringWithFormat:@"Expected ',' near: %@", [self tokenValue:commaToken]] range:commaToken.range line:commaToken.startLine column:commaToken.column];
                    [self skipLine];
                    break;
                }
                
                [statement addChunk:@"," line:commaToken.startLine column:commaToken.column];
                [self consumeToken];
                
                [statement addChild:[self parseExpression:scope]];
                
                commaToken = [self currentToken];
                
                if(commaToken.type == ',') {
                    [statement addChunk:@"," line:commaToken.startLine column:commaToken.column];
                    [self consumeToken];
                    
                    [statement addChild:[self parseExpression:scope]];
                }
            }
            else {
                LXToken *typeToken = nameToken;
                NSString *type = [self tokenValue:nameToken];
                LXClass *variableType = [self findType:type];
                
                nameToken = [self currentToken];
                
                if(nameToken.type != LX_TK_NAME) {
                    [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:nameToken]] range:nameToken.range line:nameToken.startLine column:nameToken.column];
                    [self skipLine];
                    break;
                }
                
                NSString *name = [self tokenValue:nameToken];
                
                [statement addNamedChunk:name line:nameToken.startLine column:nameToken.column];
                
                LXVariable *variable = [forScope createVariable:name type:variableType];
                
                typeToken.variableType = variableType;
                nameToken.variable = variable;
                
                LXToken *commaToken = [self currentToken];
                
                while(commaToken.type == ',') {
                    [self consumeToken];
                    [statement addChunk:@"," line:commaToken.startLine column:commaToken.column];
                    
                    nameToken = [self currentToken];
                    
                    if(![nameToken isType]) {
                        [self addError:[NSString stringWithFormat:@"Expected 'name' or 'type' near: %@", [self tokenValue:nameToken]] range:nameToken.range line:nameToken.startLine column:nameToken.column];
                        break;
                    }
                    
                    if([self nextToken].type == LX_TK_NAME) {
                        typeToken = nameToken;
                        type = [self tokenValue:typeToken];
                        [self consumeToken];
                        
                        nameToken = [self currentToken];
                        name = [self tokenValue:nameToken];
                        [self consumeToken];
                        
                        variableType = [self findType:type];
                        variable = [forScope createVariable:name type:variableType];
                        
                        typeToken.variableType = variableType;
                        nameToken.variable = variable;
                        
                        [statement addNamedChunk:name line:nameToken.startLine column:nameToken.column];
                    }
                    else {
                        name = [self tokenValue:nameToken];
                        [self consumeToken];
                        
                        variable = [forScope createVariable:name type:variableType];
                        nameToken.variable = variable;
                    }
                }
                
                LXToken *inToken = [self currentToken];
                
                if(inToken.type != LX_TK_IN) {
                    [self addError:[NSString stringWithFormat:@"Expected 'in' near: %@", [self tokenValue:inToken]] range:inToken.range line:inToken.startLine column:inToken.column];
                    [self skipLine];
                    break;
                }
                
                [self consumeToken];
                [statement addAnonymousChunk:@" "];
                [statement addChunk:@"in" line:inToken.startLine column:inToken.column];
                [statement addAnonymousChunk:@" "];
                
                do {
                    [statement addChild:[self parseExpression:scope]];
                    
                    commaToken = [self currentToken];
                    
                    if(commaToken.type == ',') {
                        [self consumeToken];
                        
                        [statement addChunk:@"," line:commaToken.startLine column:commaToken.column];
                    }
                    else {
                        break;
                    }
                } while(YES);
            }
            
            LXToken *doToken = [self currentToken];
            
            if(doToken.type != LX_TK_DO) {
                [self addError:[NSString stringWithFormat:@"Expected 'do' near: %@", [self tokenValue:doToken]] range:doToken.range line:doToken.startLine column:doToken.column];
                [self skipLine];
                break;
            }
            
            [self consumeToken:LXTokenCompletionFlagsBlock];
            
            [statement addAnonymousChunk:@" "];
            [statement addChunk:@"do" line:doToken.startLine column:doToken.column];
            
            [statement addChild:[self parseBlock:scope]];
            
            [self popScope];
            
            LXToken *endToken = [self currentToken];
            
            if(endToken.type != LX_TK_END) {
                [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:endToken]] range:endToken.range line:endToken.startLine column:endToken.column];
                break;
            }
            
            [self consumeToken:LXTokenCompletionFlagsBlock];
            
            [statement addChunk:@"end" line:endToken.startLine column:endToken.column];
            
            break;
        }
     
        case LX_TK_FUNCTION:
            [statement addChild:[self parseFunction:scope anonymous:NO isLocal:isLocal function:NULL class:nil]];
            break;
            
        case LX_TK_CLASS:
            [statement addChild:[self parseClassStatement:scope]];
            break;
     
        default: {
            LXVariable *classVariable = [scope variable:[self tokenValue:current]];
            
            if([current isType] &&
               [self nextToken].type == LX_TK_NAME &&
               (!classVariable || classVariable.isClass)) {
                NSMutableArray *typeList = [NSMutableArray array];
                
                [self consumeToken];
                NSString *type = [self tokenValue:current];
                LXToken *nameToken = [self currentToken];
                
                [self consumeToken];
                NSString *name = [self tokenValue:nameToken];
                
                if(isLocal)
                    [statement addAnonymousChunk:@"local "];
                [statement addNamedChunk:name line:nameToken.startLine column:nameToken.column];
                
                LXVariable *variable = nil;
                LXClass *variableType = [self findType:type];
                
                [typeList addObject:variableType];
                
                if(isLocal) {
                    variable = [scope localVariable:name];
                    
                    if(variable) {
                        [self addError:[NSString stringWithFormat:@"Variable %@ is already defined.", name] range:nameToken.range line:nameToken.startLine column:nameToken.column];
                    }
                    else {
                        variable = [scope createVariable:name type:variableType];
                        variable.definedLocation = nameToken.range.location;
                    }
                }
                else {
                    variable = [self.compiler.globalScope localVariable:name];
                    
                    if(variable) {
                        if(variable.isDefined) {
                            [self addError:[NSString stringWithFormat:@"Variable %@ is already defined.", name] range:nameToken.range line:nameToken.startLine column:nameToken.column];
                        }
                        else {
                            variable.type = variableType;
                        }
                    }
                    else {
                        variable = [self.compiler.globalScope createVariable:name type:variableType];
                        [definedVariables addObject:variable];
                    }
                }
                
                current.variableType = variableType;
                nameToken.variable = variable;
                
                LXToken *commaToken = [self currentToken];
                
                while(commaToken.type == ',') {
                    [self consumeToken];
                    
                    [statement addChunk:@"," line:commaToken.startLine column:commaToken.column];
                    
                    nameToken = [self currentToken];
                    
                    if(nameToken.type != LX_TK_NAME) {
                        [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:nameToken]] range:nameToken.range line:nameToken.startLine column:nameToken.column];
                        break;
                    }
                    
                    [self consumeToken];
                    name = [self tokenValue:nameToken];
                    [statement addNamedChunk:name line:nameToken.startLine column:nameToken.column];
                    [typeList addObject:variableType];
                    
                    variable = nil;
                    
                    if(isLocal) {
                        variable = [scope localVariable:name];
                        
                        if(variable) {
                            [self addError:[NSString stringWithFormat:@"Variable %@ is already defined.", name] range:nameToken.range line:nameToken.startLine column:nameToken.column];
                        }
                        else {
                            variable = [scope createVariable:name type:variableType];
                            variable.definedLocation = nameToken.range.location;
                        }
                    }
                    else {
                        variable = [self.compiler.globalScope localVariable:name];
                        
                        if(variable) {
                            if(variable.isDefined) {
                                [self addError:[NSString stringWithFormat:@"Variable %@ is already defined.", name] range:nameToken.range line:nameToken.startLine column:nameToken.column];
                            }
                            else {
                                variable.type = variableType;
                            }
                        }
                        else {
                            variable = [self.compiler.globalScope createVariable:name type:variableType];
                            [definedVariables addObject:variable];
                        }
                    }
                    
                    nameToken.variable = variable;
                    
                    commaToken = [self currentToken]; //CONVERT TO DO WHILE LOOP
                }
                
                NSInteger index = 0;
                
                if(commaToken.type == '=') {
                    [self consumeToken:LXTokenCompletionFlagsVariables];
                    
                    [statement addChunk:@"=" line:commaToken.startLine column:commaToken.column];
                    
                    do {
                        [statement addChild:[self parseExpression:scope]];
                        
                        ++index;
                        commaToken = [self currentToken];
                        
                        if(commaToken.type == ',') {
                            [self consumeToken:LXTokenCompletionFlagsVariables];
                            
                            [statement addChunk:@"," line:commaToken.startLine column:commaToken.column];
                        }
                        else {
                            break;
                        }
                    } while(YES);
                }
                else {
                    [statement addAnonymousChunk:@"="];
                }
                
                for(NSInteger i = index; i < [typeList count]; ++i) {
                    if(i > 0)
                        [statement addAnonymousChunk:@","];
                    
                    LXClass *type = typeList[i];
                    
                    [statement addChild:type.defaultExpression];
                }
            }
            else {
                LXNode *declaration = [self parseSuffixedExpression:scope onlyDotColon:NO];
                
                [statement addChild:declaration];
                
                LXToken *assignmentToken = [self currentToken];
                
                if(assignmentToken.type == ',' || [assignmentToken isAssignmentOperator]) {
                    if(!declaration.assignable) {
                        [self addError:[NSString stringWithFormat:@"Unexpected assignment token near: %@", [self tokenValue:assignmentToken]] range:assignmentToken.range line:assignmentToken.startLine column:assignmentToken.column];
                    }
                    
                    NSMutableArray *declarations = [NSMutableArray array];
                    [declarations addObject:declaration];
                    
                    while(assignmentToken.type == ',') {
                        [self consumeToken:LXTokenCompletionFlagsVariables];
                        
                        [statement addChunk:@"," line:assignmentToken.startLine column:assignmentToken.column];
                        declaration = [self parseSuffixedExpression:scope onlyDotColon:NO];
                        [statement addChild:declaration];
                        [declarations addObject:declaration];
                        
                        assignmentToken = [self currentToken];
                    }
                    
                    if(![assignmentToken isAssignmentOperator]) {
                        [self addError:[NSString stringWithFormat:@"Expected '=' near: %@", [self tokenValue:assignmentToken]] range:assignmentToken.range line:assignmentToken.startLine column:assignmentToken.column];
                        [self skipLine];
                        break;
                    }
                    
                    [self consumeToken:LXTokenCompletionFlagsVariables];
                    [statement addChunk:@"=" line:assignmentToken.startLine column:assignmentToken.column];
                    
                    NSInteger i = 0;
                    
                    do {
                        LXNode *matchingDeclaration = i < [declarations count] ? declarations[i] : nil;
                        
                        switch((NSInteger)assignmentToken.type) {
                            case LX_TK_PLUS_EQ: {
                                [statement addChild:matchingDeclaration];
                                [statement addChunk:@"+" line:assignmentToken.startLine column:assignmentToken.column];
                                break;
                            }
                                
                            case LX_TK_MINUS_EQ: {
                                [statement addChild:matchingDeclaration];
                                [statement addChunk:@"-" line:assignmentToken.startLine column:assignmentToken.column];
                                break;
                            }
                                
                            case LX_TK_MULT_EQ: {
                                [statement addChild:matchingDeclaration];
                                [statement addChunk:@"*" line:assignmentToken.startLine column:assignmentToken.column];
                                break;
                            }
                                
                            case LX_TK_DIV_EQ: {
                                [statement addChild:matchingDeclaration];
                                [statement addChunk:@"/" line:assignmentToken.startLine column:assignmentToken.column];
                                break;
                            }
                                
                            case LX_TK_POW_EQ: {
                                [statement addChild:matchingDeclaration];
                                [statement addChunk:@"^" line:assignmentToken.startLine column:assignmentToken.column];
                                break;
                            }
                                
                            case LX_TK_MOD_EQ: {
                                [statement addChild:matchingDeclaration];
                                [statement addChunk:@"%" line:assignmentToken.startLine column:assignmentToken.column];
                                break;
                            }
                                
                            case LX_TK_CONCAT_EQ: {
                                [statement addChild:matchingDeclaration];
                                [statement addChunk:@".." line:assignmentToken.startLine column:assignmentToken.column];
                                break;
                            }
                                
                            default:
                                break;
                        }
                        
                        [statement addChild:[self parseExpression:scope]];
                        
                        assignmentToken = [self currentToken];
                        
                        if(assignmentToken.type == ',') {
                            [self consumeToken:LXTokenCompletionFlagsVariables];
                            
                            [statement addChunk:@"," line:assignmentToken.startLine column:assignmentToken.column];
                        }
                        else {
                            break;
                        }
                        
                        ++i;
                    } while(YES);
                }
                else if(declaration.assignable) {
                    [self addError:[NSString stringWithFormat:@"Expected ',' or '=' near: %@", [self tokenValue:assignmentToken]] range:assignmentToken.range line:assignmentToken.startLine column:assignmentToken.column];
                    break;
                }
            }
            
            break;
        }
    }
    
    return statement;
}*/

@end
