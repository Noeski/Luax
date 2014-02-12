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

- (id)nodeWithType:(Class)class {
    LXNodeNew *node = [[class alloc] init];
    node.line = _current.line;
    node.column = _current.column;
    node.location = _current.range.location;
    
    return node;
}

- (id)finish:(LXNodeNew *)node {
    node.length = NSMaxRange(_previous.range)-node.location;
    
    return node;
}

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
    [self consumeToken:LXTokenCompletionFlagsTypes | LXTokenCompletionFlagsVariables];
    
    LXScope *forScope = [self pushScope:_currentScope openScope:NO];
    
    if(![_current isType]) {
        [self addError:[NSString stringWithFormat:@"Expected 'name' or 'type' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        [self skipLine];
    }
    
    LXForStmt *statement = nil;
    
    if(_next.type == '=') {
        LXNumericForStmt *numericForStatement = [[LXNumericForStmt alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
        
        NSString *name = [self tokenValue:_current];
        
        LXClass *variableType =  [LXClassNumber classNumber];
        LXVariable *variable = [forScope createVariable:name type:variableType];
        
        _current.variable = variable;
        
        [self consumeToken];
        [self consumeToken];

        numericForStatement.exprInit = [self parseExpression];
        
        if(_current.type != ',') {
            [self addError:[NSString stringWithFormat:@"Expected ',' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
            [self skipLine];
        }
        
        [self consumeToken];
        
        numericForStatement.exprCond = [self parseExpression];
        
        if(_current.type == ',') {
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
    LXDeclarationStmt *statement = [[LXDeclarationStmt alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
    
    LXTypeNode *type = [self parseTypeNode];
    
    NSMutableArray *mutableVars = [[NSMutableArray alloc] init];

    do {
        LXDeclarationNode *declarationNode = [[LXDeclarationNode alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
        
        declarationNode.type = type;
        declarationNode.var = [self parseVariableNode:type.type isLocal:YES];
        
        [mutableVars addObject:declarationNode];
    } while([self consumeTokenType:','] != nil);
    
    statement.vars = mutableVars;
    
    NSMutableArray *mutableExprs = [[NSMutableArray alloc] init];
    
    NSInteger index = 0;
    
    if(_current.type == '=') {
        [self consumeToken:LXTokenCompletionFlagsVariables];
        
        do {
            [mutableExprs addObject:[self parseExpression]];
            
            ++index;
            
            if(_current.type == ',') {
                [self consumeToken:LXTokenCompletionFlagsVariables];
            }
            else {
                break;
            }
        } while(YES);
    }
    
    for(NSInteger i = index; i < [mutableVars count]; ++i) {
        [mutableExprs addObject:type.type.defaultExpression];
    }
    
    statement.exprs = mutableExprs;
    
    return statement;
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
        
        LXExprStmt *statement = [[LXExprStmt alloc] initWithLine:expr.line column:expr.column location:expr.location];
        statement.expr = expr;
        
        return statement;
    }
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
    LXClassStmt *statement = [[LXClassStmt alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
    
    [self consumeToken];
    
    NSMutableArray *functions = [NSMutableArray array];
    NSMutableArray *variables = [NSMutableArray array];
    
    NSMutableArray *functionIndices = [NSMutableArray array];
    
    if(_current.type != LX_TK_NAME) {
        [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
    }
    
    NSString *name = [self tokenValue:_current];
    NSString *superclass = nil;
    
    [self consumeToken:LXTokenCompletionFlagsClass];
    
    if(_current.type == LX_TK_EXTENDS) {
        [self consumeToken:LXTokenCompletionFlagsTypes];
        
        if(![_current isType]) {
            [self addError:[NSString stringWithFormat:@"Expected 'name' or 'type' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
        }
        
        superclass = [self tokenValue:_current];
        [self consumeToken:LXTokenCompletionFlagsClass];
    }
    
    if(superclass) {
        //[class addAnonymousChunk:[NSString stringWithFormat:@"%@ = %@ or setmetatable({}, {__call = function(class, ...)\n  local obj = setmetatable({class = \"%@\", super = %@}, {__index = class})\n  obj:init(...)\n  return obj\nend})\n", name, name, name, superclass]];
        //[class addAnonymousChunk:[NSString stringWithFormat:@"for k, v in pairs(%@) do\n  %@[k] = v\nend\n", superclass, name]];
        //[class addAnonymousChunk:[NSString stringWithFormat:@"function %@:init(...)\n  %@.init(self, ...)\n", name, superclass]];
    }
    else {
        //[class addAnonymousChunk:[NSString stringWithFormat:@"%@ = %@ or setmetatable({}, {__call = function(class, ...)\n  local obj = setmetatable({class = \"%@\"}, {__index = class})\n  obj:init(...)\n  return obj\nend})\n", name, name, name]];
        //[class addAnonymousChunk:[NSString stringWithFormat:@"function %@:init(...)\n", name]];
    }
    
    LXScope *classScope = [self pushScope:_currentScope openScope:YES];
    classScope.type = LXScopeTypeClass;
    
    LXVariable *variable = [classScope createVariable:@"self" type:[self findType:name]];
    [variables addObject:variable];
    
    if(superclass) {
        LXVariable *variable = [classScope createVariable:@"super" type:[self findType:superclass]];
        variable.isMember = YES;
        [variables addObject:variable];
    }
    
    while(_current.type != LX_TK_END) {
        if(_current.type == LX_TK_STATIC || _current.type == LX_TK_FUNCTION) {
            [functionIndices addObject:@(self.currentTokenIndex)];
            
            [self consumeTokenType:LX_TK_STATIC];
            [self consumeToken];
            [self closeBlock:LX_TK_FUNCTION];
        }
        else if([_current isType]) {
            NSString *type = [self tokenValue:_current];
            LXClass *variableType = [self findType:type];
            _current.variableType = variableType;
            [self consumeToken];
            
            if(_current.type != LX_TK_NAME) {
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
            }
            
            NSString *name = [self tokenValue:_current];
            
            LXVariable *variable = [classScope createVariable:name type:variableType];
            variable.isMember = YES;
            _current.variable = variable;
            [variables addObject:variable];
            
            [self consumeToken];
            
            NSMutableArray *initList = [NSMutableArray array];
            
            while(_current.type == ',') {
                [self consumeToken];
                
                if(_current.type != LX_TK_NAME) {
                    [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
                }
                
                name = [self tokenValue:_current];
                LXVariable *variable = [classScope createVariable:name type:variableType];
                variable.isMember = YES;
                
                _current.variable = variable;
                [variables addObject:variable];
                
                [self consumeToken];
            }
            
            if(_current.type == '=') {
                [self consumeToken:LXTokenCompletionFlagsVariables];
                
                do {
                    [initList addObject:[self parseExpression]];
                    
                    if(_current.type == ',') {
                        [self consumeToken:LXTokenCompletionFlagsVariables];
                        continue;
                    }
                    
                    break;
                } while(YES);
            }
        }
        else {
            [self addError:[NSString stringWithFormat:@"Expected function or variable declaration near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
            break;
        }
        
        if(_current.type == LX_TK_END) {
            NSInteger endIndex = self.currentTokenIndex;
            
            for(NSNumber *index in functionIndices) {
                self.currentTokenIndex = index.integerValue;
                
                LXFunctionExpr *function = [self parseFunction:NO isLocal:YES class:name];
                
                if(function.resultType) {
                    [variables addObject:function.resultType];
                }
            }
            
            self.currentTokenIndex = endIndex;
        }
    }
    
    [self popScope];
    
    if(_current.type != LX_TK_END) {
        [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:_current]] range:_current.range line:_current.line column:_current.column];
    }
    
    [self consumeToken:LXTokenCompletionFlagsBlock];
    
    LXClass *scriptClass = [[LXClassBase alloc] init];
    scriptClass.name = name;
    if(superclass)
        scriptClass.parent = [self findType:superclass];
    scriptClass.variables = variables;
    scriptClass.functions = functions;
    
    scriptClass = [self declareType:name objectType:scriptClass];
    
    LXVariable *classTable = [self.compiler.globalScope createVariable:name type:scriptClass];
    [definedVariables addObject:classTable];
    classTable.isFunction = YES;
    classTable.isClass = YES;
    classTable.returnTypes = @[[LXVariable variableWithType:scriptClass]];
    
    return statement;
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
            LXExprStmt *statement = [[LXExprStmt alloc] initWithLine:_current.line column:_current.column location:_current.range.location];
            statement.expr = [self parseFunction:NO isLocal:YES class:nil];
            
            return statement;
        }
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
     
        case LX_TK_FUNCTION:
            [statement addChild:[self parseFunction:scope anonymous:NO isLocal:isLocal function:NULL class:nil]];
            break;
            
        case LX_TK_CLASS:
            [statement addChild:[self parseClassStatement:scope]];
            break;
}*/

@end
