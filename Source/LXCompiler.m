//
//  LXCompiler.m
//  LuaX
//
//  Created by Noah Hilt on 8/8/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXCompiler.h"
#import "LXParser.h"
#import "LXToken.h"

@implementation LXContext

- (id)initWithName:(NSString *)name {
    if(self = [super init]) {
        _name = [name copy];
        _parser = [[LXParser alloc] init];
    }
    
    return self;
}

@end

@interface LXCompiler() {
    NSMutableArray *scopeStack;
    NSMutableArray *errors;
    
    LXContext *currentContext;
    NSInteger currentTokenIndex;
}

@end

@implementation LXCompiler

- (id)init {
    if(self = [super init]) {
        _fileMap = [[NSMutableDictionary alloc] init];
        _baseTypeMap = [[NSMutableDictionary alloc] init];
        _typeMap = [[NSMutableDictionary alloc] init];
        
        errors = [[NSMutableArray alloc] init];
        
        _baseTypeMap[@"Number"] = [LXClassNumber classNumber];
        _baseTypeMap[@"Bool"] = [LXClassBool classBool];
        _baseTypeMap[@"String"] = [LXClassString classString];
        _baseTypeMap[@"Table"] = [LXClassTable classTable];
        
        self.globalScope = [self pushScope:nil openScope:NO];
    }
    
    return self;
}

- (void)compile:(NSString *)name string:(NSString *)string {
    currentContext = [[LXContext alloc] initWithName:name];
    [currentContext.parser parse:string];
    
    currentTokenIndex = 0;
    
    [_typeMap removeAllObjects];
    
    currentContext.block = [self parseBlock:self.globalScope];
    currentContext.scope = currentContext.block.scope;
    
    self.fileMap[name] = currentContext;
    
    for(NSString *error in errors)
        NSLog(@"%@", error);
    
    NSLog(@"%@", [currentContext.block toString]);
}

- (void)save {
    for(LXContext *context in [self.fileMap allValues]) {
        NSString *path = [context.name stringByDeletingLastPathComponent];
        NSString *fileName = [[context.name lastPathComponent] stringByDeletingPathExtension];
        
        [[context.block toString] writeToFile:[NSString stringWithFormat:@"%@/%@.lua", path, fileName] atomically:YES encoding:NSUTF8StringEncoding error:nil];
    }
}

- (LXToken *)token:(NSInteger *)index {
    while(YES) {
        if(*index >= [currentContext.parser.tokens count]) {
            LXToken *eofToken = [[LXToken alloc] init];
            eofToken.type = LX_TK_EOS;
            
            return eofToken;
        }
        
        LXToken *token = currentContext.parser.tokens[*index];
        if(token.type == LX_TK_COMMENT || token.type == LX_TK_LONGCOMMENT) {
            (*index)++;
            continue;
        }
        
        return token;
    }
}

- (LXToken *)currentToken {
    return [self token:&currentTokenIndex];
}

- (LXToken *)lastToken {
    NSInteger index = currentTokenIndex-1;
    return [self token:&index];
}

- (LXToken *)nextToken {
    NSInteger index = currentTokenIndex+1;
    return [self token:&index];
}

- (LXToken *)consumeToken {
    LXToken *token = [self token:&currentTokenIndex];
    token.scope = [self currentScope];
    
    ++currentTokenIndex;
    return token;
}

- (BOOL)consumeToken:(LXTokenType)type {
    NSInteger index = currentTokenIndex;
    
    LXToken *token = [self token:&index];
    
    if(token.type == type) {
        token.scope = [self currentScope];

        currentTokenIndex = index+1;
        
        return YES;
    }
    
    return NO;
}

- (void)matchToken:(LXTokenType)type {
    NSInteger index = currentTokenIndex;
    
    LXToken *token = [self token:&index];
    
    NSMutableArray *tokenStack = [NSMutableArray arrayWithObject:@(type)];
    
    while(token.type != LX_TK_EOS && [tokenStack count]) {
        NSInteger topToken = [[tokenStack lastObject] integerValue];
        
        if(topToken == '(') {
            if(token.type == '(') {
                [tokenStack addObject:@(token.type)];
            }
            else if(token.type == ')') {
                [tokenStack removeLastObject];
            }
        }
        else if(topToken == '[') {
            if(token.type == '[') {
                [tokenStack addObject:@(token.type)];
            }
            else if(token.type == ']') {
                [tokenStack removeLastObject];
            }
        }
        else if(topToken == '{') {
            if(token.type == '{') {
                [tokenStack addObject:@(token.type)];
            }
            else if(token.type == '}') {
                [tokenStack removeLastObject];
            }
        }
        
        ++index;
        
        token = [self token:&index];
    }
    
    currentTokenIndex = index;
}

- (void)closeBlock:(LXTokenType)type {
    static __strong NSArray *openTokens = nil;
    
    if(!openTokens)
        openTokens = @[
                       @(LX_TK_DO), @(LX_TK_FOR), @(LX_TK_FUNCTION), @(LX_TK_IF),
                       @(LX_TK_REPEAT), @(LX_TK_WHILE), @(LX_TK_CLASS)
                       ];
    
    NSInteger index = currentTokenIndex;
    
    LXToken *token = [self token:&index];
    
    NSMutableArray *tokenStack = [NSMutableArray arrayWithObject:@(type)];
    
    while(token.type != LX_TK_EOS && [tokenStack count]) {
        NSInteger topToken = [[tokenStack lastObject] integerValue];
        
        if(topToken == LX_TK_REPEAT) {
            if(token.type == LX_TK_UNTIL) {
                [tokenStack removeLastObject];
            }
        }
        else if(token.type == LX_TK_END) {
            [tokenStack removeLastObject];
        }
        else if([openTokens containsObject:@(token.type)]) {
            [tokenStack addObject:@(token.type)];
        }
        
        ++index;
        
        token = [self token:&index];
    }
    
    currentTokenIndex = index;
}


- (NSString *)tokenValue:(LXToken *)token {
    return [currentContext.parser.string substringWithRange:token.range];
}

//////////////////////////////////////////////////////////

- (LXScope *)pushScope:(LXScope *)parent openScope:(BOOL)openScope {
    if(scopeStack == nil) {
        scopeStack = [[NSMutableArray alloc] init];
    }
    
    LXScope *scope = [[LXScope alloc] initWithParent:parent openScope:openScope];
    scope.range = NSMakeRange(NSMaxRange([self lastToken].range), 0);
    
    [scopeStack addObject:scope];
    
    return scope;
}

- (void)popScope {
    if([scopeStack count] == 0) {
        //error
    }
    
    LXScope *scope = [scopeStack lastObject];
    scope.range = NSMakeRange(scope.range.location, [self currentToken].range.location - scope.range.location);
    
    [scopeStack removeLastObject];
}

- (LXScope *)currentScope {
    return [scopeStack lastObject];
}

- (LXClass *)findType:(NSString *)name {
    LXClass *type = self.baseTypeMap[name];
    
    if(!type) {
        type = self.typeMap[name];
    }
    
    if(!type) {
        type = [[LXClassBase alloc] init];
        type.isDefined = NO;
        
        self.typeMap[name] = type;
    }
    
    return type;
}

- (void)declareType:(NSString *)name objectType:(LXClass *)objectType {
    if(!name)
        return;
    
    LXClass *type = self.baseTypeMap[name];

    if(!type) {
        type = self.typeMap[name];
    }
    
    if(!type) {
        type = [[LXClassBase alloc] init];
        self.typeMap[name] = type;
    }
    else if(type.isDefined) {
        //error already defined type
    }
    
    type.isDefined = YES;
    type.name = objectType.name;
    type.parent = objectType.parent;
    type.functions = objectType.functions;
    type.variables = objectType.variables;    
}

- (LXNode *)parseSimpleExpression:(LXScope *)scope {
    LXToken *token = [self currentToken];
    
    if([self consumeToken:LX_TK_NUMBER]) {
        LXNodeNumberExpression *numberExpression = [[LXNodeNumberExpression alloc] init];
        
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        [formatter setNumberStyle:NSNumberFormatterNoStyle];
        numberExpression.value = [formatter numberFromString:[self tokenValue:token]];
        
        return numberExpression;
    }
    else if([self consumeToken:LX_TK_STRING]) {
        LXNodeStringExpression *stringExpression = [[LXNodeStringExpression alloc] init];
        stringExpression.value = [self tokenValue:token];
        
        return stringExpression;
    }
    else if([self consumeToken:LX_TK_NIL]) {
        return [[LXNodeNilExpression alloc] init];
    }
    else if([self consumeToken:LX_TK_TRUE]) {
        LXNodeBoolExpression *boolExpression = [[LXNodeBoolExpression alloc] init];
        boolExpression.value = YES;
        
        return boolExpression;
    }
    else if([self consumeToken:LX_TK_FALSE]) {
        LXNodeBoolExpression *boolExpression = [[LXNodeBoolExpression alloc] init];
        boolExpression.value = NO;
        
        return boolExpression;
    }
    else if([self consumeToken:LX_TK_DOTS]) {
        return [[LXNodeVarArgExpression alloc] init];
    }
    else if([self consumeToken:'{']) {
        LXNodeTableConstructorExpression *tableConstructor = [[LXNodeTableConstructorExpression alloc] init];
        
        NSMutableArray *keyValuePairs = [NSMutableArray array];
        
        while(YES) {
            token = [self currentToken];
            
            if([self consumeToken:'[']) {
                LXNode *key = [self parseExpression:scope];
                
                if(!key) {
                    [self matchToken:'['];
                }
                else if(![self consumeToken:']']) {
                    [errors addObject:[NSString stringWithFormat:@"Expected ']' near: %@", [self tokenValue:[self currentToken]]]];
                }
                
                if(![self consumeToken:'=']) {
                    [errors addObject:[NSString stringWithFormat:@"Expected '=' near: %@", [self tokenValue:[self currentToken]]]];
                }
                
                LXNode *value = [self parseExpression:scope];
                
                if(!value) {
                    
                }
                
                KeyValuePair *kvp = [[KeyValuePair alloc] init];
                kvp.key = key;
                kvp.value = value;
                [keyValuePairs addObject:kvp];
            }
            else if(token.type == LX_TK_NAME) {
                LXToken *next = [self nextToken];
                
                LXNode *key = nil;
                
                if(next.type == '=') {
                    LXNodeVariableExpression *expression = [[LXNodeVariableExpression alloc] init];
                    expression.variable = [self tokenValue:[self currentToken]];
                    key = expression;
                    
                    [self consumeToken:'='];
                }
                
                LXNode *value = [self parseExpression:scope];
                
                if(!value) {
                    
                }
                
                KeyValuePair *kvp = [[KeyValuePair alloc] init];
                kvp.key = key;
                kvp.value = value;
                [keyValuePairs addObject:kvp];
            }
            else if([self consumeToken:'}']) {
                break;
            }
            else {
                LXNode *value = [self parseExpression:scope];
                
                if(!value) {
                    
                }
                
                KeyValuePair *kvp = [[KeyValuePair alloc] init];
                kvp.value = value;
                [keyValuePairs addObject:kvp];
            }
            
            if([self consumeToken:';'] || [self consumeToken:',']) {
            }
            else if([self consumeToken:'}']) {
                break;
            }
            else {
                [errors addObject:[NSString stringWithFormat:@"Expected ';', ',' or '}' near: %@", [self tokenValue:[self currentToken]]]];
                [self matchToken:'{'];
            }
        }
        
        tableConstructor.keyValuePairs = keyValuePairs;
        
        return tableConstructor;
    }
    else if([self consumeToken:LX_TK_FUNCTION]) {
        LXNodeFunctionExpression *function = [self parseFunction:scope anonymous:YES isLocal:YES];
        
        return function;
    }
    
    return [self parseSuffixedExpression:scope onlyDotColon:NO];
}

- (LXNode *)parseSuffixedExpression:(LXScope *)scope onlyDotColon:(BOOL)onlyDotColon {
    LXNode *expression = [self parsePrimaryExpression:scope];
    
    while(expression != nil) {
        LXToken *token = [self currentToken];
        
        if([self consumeToken:'.'] ||
           [self consumeToken:':']) {
            if([self currentToken].type != LX_TK_NAME) {
                [errors addObject:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:[self currentToken]]]];
                expression = nil;
            }
            else {
                LXNodeMemberExpression *memberExpression = [[LXNodeMemberExpression alloc] init];
                
                memberExpression.base = expression;
                memberExpression.useColon = token.type == ':' ? YES : NO;
                memberExpression.value = [self tokenValue:[self currentToken]];
                
                LXVariable *variable = ((LXNodeExpression *)expression).scriptVariable;
                
                if(variable.isDefined && variable.type.isDefined) {
                    for(LXVariable *v in variable.type.variables) {
                        if([v.name isEqualToString:memberExpression.value]) {
                            [self currentToken].variable = v;
                            [self currentToken].isMember = YES;
                            memberExpression.scriptVariable = v;
                            break;
                        }
                    }
                }
                else {
                }
                
                [self consumeToken];
                
                expression = memberExpression;
            }
        }
        else if(!onlyDotColon && [self consumeToken:'[']) {
            LXNode *index = [self parseExpression:scope];
            
            if(index == nil) {
                [self matchToken:'['];
                expression = nil;
            }
            else {
                LXNodeIndexExpression *indexExpression = [[LXNodeIndexExpression alloc] init];
                indexExpression.base = expression;
                indexExpression.index = index;
                
                if(![self consumeToken:']']) {
                    [errors addObject:[NSString stringWithFormat:@"Expected ']' near: %@", [self tokenValue:[self currentToken]]]];
                }
                
                expression = indexExpression;
            }
        }
        else if(!onlyDotColon && [self consumeToken:'(']) {
            LXNodeCallExpression *callExpression = [[LXNodeCallExpression alloc] init];
            callExpression.base = expression;
            
            NSMutableArray *arguments = [NSMutableArray array];
            
            while(![self consumeToken:')']) {
                LXNode *arg = [self parseExpression:scope];
                
                if(arg == nil) {
                    [self matchToken:'('];
                    break;
                }
                
                [arguments addObject:arg];
                
                if(![self consumeToken:',']) {
                    if(![self consumeToken:')']) {
                        [errors addObject:[NSString stringWithFormat:@"Expected ')' near: %@", [self tokenValue:[self currentToken]]]];
                    }
                    
                    break;
                }
            }
            
            callExpression.arguments = arguments;
            
            expression = callExpression;
        }
        else if(!onlyDotColon && [self currentToken].type == LX_TK_STRING) {
            LXNodeStringCallExpression *stringCallExpression = [[LXNodeStringCallExpression alloc] init];
            
            stringCallExpression.base = expression;
            stringCallExpression.value = [self tokenValue:[self consumeToken]];
            expression = stringCallExpression;
        }
        else if(!onlyDotColon && [self currentToken].type == '{') {
            LXNodeTableCallExpression *tableCallExpression = [[LXNodeTableCallExpression alloc] init];
            tableCallExpression.base = expression;
            tableCallExpression.table = [self parseExpression:scope];
            
            expression = tableCallExpression;
        }
        else {
            break;
        }
    }
    
    return expression;
}

- (LXNode *)parsePrimaryExpression:(LXScope *)scope {
    LXToken *token = [self currentToken];
    
    if([self consumeToken:'(']) {
        LXNode *expression = [self parseExpression:scope];
        
        if(expression == nil) {
            [self matchToken:'('];
        }
        else if(![self consumeToken:')']) {
            [errors addObject:[NSString stringWithFormat:@"Expected ')' near: %@", [self tokenValue:[self currentToken]]]];
        }
        
        //[expression setParenCount:+1];
        
        return expression;
    }
    else if([self consumeToken:LX_TK_NAME]) {        
        NSString *identifier = [self tokenValue:token];
        LXNodeVariableExpression *variableExpression = [[LXNodeVariableExpression alloc] init];
        variableExpression.variable = identifier;
        
        LXVariable *local = [scope variable:identifier];
        
        if(local) {
            //variableExpression.local = YES;
        }
        else {
            local = [self.globalScope createVariable:identifier type:nil];
        }
        
        token.variable = local;
        variableExpression.scriptVariable = local;
        
        return variableExpression;
    }
    else {
        [errors addObject:[NSString stringWithFormat:@"Expected 'name' or '(expression)' near: %@", [self tokenValue:[self currentToken]]]];
        
        NSLog(@"%@", [self tokenValue:[self currentToken]]);
        return nil;
    }
}

- (LXNode *)parseSubExpression:(LXScope *)scope level:(NSInteger)level {
    static __strong NSDictionary *unaryOps = nil;
  
    if(!unaryOps)
        unaryOps =@{@('-') : @YES, @('#') : @YES, @(LX_TK_NOT) : @YES};
    
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
    
    LXNode *expression = nil;
    
    if(unaryOps[@([self currentToken].type)]) {
        LXToken *unaryOp = [self consumeToken];
        
        NSString *op = [self tokenValue:unaryOp];
        LXNode *rhs = [self parseSubExpression:scope level:8];
        
        if(rhs != nil) {
            LXNodeUnaryOpExpression *unaryOpExpression = [[LXNodeUnaryOpExpression alloc] init];
            unaryOpExpression.op = op;
            unaryOpExpression.rhs = rhs;
            
            expression = unaryOpExpression;
        }
    }
    else {
        expression = [self parseSimpleExpression:scope];
        
        while(expression != nil) {
            NSValue *priority = priorityDict[@([self currentToken].type)];
            
            if(priority && priority.rangeValue.location > level) {
                LXToken *binaryOp = [self consumeToken];
                
                NSString *op = [self tokenValue:binaryOp];
                LXNode *rhs = [self parseSubExpression:scope level:priority.rangeValue.length];
                
                if(rhs != nil) {
                    LXNodeBinaryOpExpression *binaryOpExpression = [[LXNodeBinaryOpExpression alloc] init];
                    binaryOpExpression.lhs = expression;
                    binaryOpExpression.op = op;
                    binaryOpExpression.rhs = rhs;
                    
                    expression = binaryOpExpression;
                }
                else {
                    expression = nil;
                }
            }
            else {
                break;
            }
        }
    }
    
    return expression;
}

- (LXNode *)parseExpression:(LXScope *)scope {
    return [self parseSubExpression:scope level:0];
}

- (LXNodeFunctionExpression *)parseFunction:(LXScope *)scope anonymous:(BOOL)anonymous isLocal:(BOOL)isLocal {
    LXNodeFunctionExpression *functionStatement = [[LXNodeFunctionExpression alloc] init];
    LXScope *functionScope = [self pushScope:scope openScope:NO];
    functionScope.type = LXScopeTypeFunction;

    BOOL checkingReturnType = NO;
    BOOL hasReturnType = NO;
    BOOL hasEmptyReturnType = NO;
    NSMutableArray *returnTypes = [NSMutableArray array];
    if([self consumeToken:'(']) {
        checkingReturnType = YES;
        if([self currentToken].type == ')' ||
           (([[self currentToken] isType] || [self currentToken].type == LX_TK_DOTS) &&
            ([self nextToken].type == ',' || [self nextToken].type == ')'))) {
               hasReturnType = YES;
               while(![self consumeToken:')']) {
                   if([[self currentToken] isType]) {
                       LXToken *typeToken = [self currentToken];
                       NSString *type = [self tokenValue:[self consumeToken]];
                       LXClass *variableType = [self findType:type];
                       typeToken.variableType = variableType;
                       
                       [returnTypes addObject:[self findType:type]];
                       
                       if(![self consumeToken:',']) {
                           if(![self consumeToken:')']) {
                               [errors addObject:[NSString stringWithFormat:@"Expected ')' near: %@", [self tokenValue:[self currentToken]]]];
                           }
                           
                           break;
                       }
                   }
                   else if([self consumeToken:LX_TK_DOTS]) {
                       //isVarArg = YES;
                       
                       if(![self consumeToken:')']) {
                           [errors addObject:[NSString stringWithFormat:@"Expected ')' near: %@", [self tokenValue:[self currentToken]]]];
                       }
                       
                       break;
                   }
                   else {
                       [errors addObject:[NSString stringWithFormat:@"Expected 'type' near: %@", [self tokenValue:[self currentToken]]]];
                       
                       [self matchToken:'('];
                       break;
                   }
               }
           }
    }
    
    if(!anonymous) {
        LXToken *token = [self currentToken];
        
        if([self consumeToken:LX_TK_NAME]) {
            NSString *identifier = [self tokenValue:token];
            LXNodeVariableExpression *variableExpression = [[LXNodeVariableExpression alloc] init];
            variableExpression.variable = identifier;
            
            LXVariable *local = [scope variable:identifier];
            
            if(local) {
                //variableExpression.local = YES;
            }
            else {
                local = [self.globalScope createVariable:identifier type:nil];
            }
            
            token.variable = local;
            variableExpression.scriptVariable = local;
            
            LXNodeExpression *expression = variableExpression;
            
            LXToken *token = [self currentToken];
            
            while([self consumeToken:'.'] ||
                  [self consumeToken:':']) {
                if([self currentToken].type != LX_TK_NAME) {
                    [errors addObject:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:[self currentToken]]]];
                    expression = nil;
                }
                else {
                    LXNodeMemberExpression *memberExpression = [[LXNodeMemberExpression alloc] init];
                    
                    memberExpression.base = expression;
                    memberExpression.useColon = token.type == ':' ? YES : NO;
                    memberExpression.value = [self tokenValue:[self currentToken]];
                    
                    LXVariable *variable = expression.scriptVariable;
                    
                    if(variable.isDefined && variable.type.isDefined) {
                        for(LXVariable *v in variable.type.variables) {
                            if([v.name isEqualToString:memberExpression.value]) {
                                [self currentToken].variable = v;
                                [self currentToken].isMember = YES;
                                memberExpression.scriptVariable = v;
                                break;
                            }
                        }
                    }
                    else {
                    }
                    
                    [self consumeToken];
                    
                    expression = memberExpression;
                }
                
                token = [self currentToken];
            }
            
            functionStatement.name = expression;
        }
        

        /*LXToken *token = [self currentToken];

        if([self consumeToken:LX_TK_NAME]) {
            NSString *identifier = [self tokenValue:token];
            
            LXScope *functionScope = isLocal ? scope : self.globalScope;
            
            LXVariable *variable = [functionScope variable:identifier];
            
            if(variable) {
                //?
                variable.type = [self findType:@"Function"];
            }
            else {
                variable = [functionScope createVariable:identifier type:[self findType:@"Function"]];
            }

            token.variable = variable;
            
            functionStatement.name = identifier;
        }*/
        
        if(![self consumeToken:'(']) {
            [errors addObject:[NSString stringWithFormat:@"Expected '(' near: %@", [self tokenValue:[self currentToken]]]];
        }
    }
    else {
        if(checkingReturnType && hasReturnType) {
            if(![self consumeToken:'(']) {
                if([returnTypes count] == 0) {
                    hasEmptyReturnType = YES;
                }
                else {
                    [errors addObject:[NSString stringWithFormat:@"Expected '(' near: %@", [self tokenValue:[self currentToken]]]];
                }
            }
        }
    }
    
    BOOL isVarArg = NO;
    NSMutableArray *arguments = [NSMutableArray array];
    
    while(!hasEmptyReturnType && ![self consumeToken:')']) {
        if([[self currentToken] isType]) {
            LXToken *typeToken = [self currentToken];
            NSString *type = [self tokenValue:[self consumeToken]];
            LXClass *variableType = [self findType:type];
            typeToken.variableType = variableType;
            
            LXToken *token = [self currentToken];

            if(![self currentToken].type == LX_TK_NAME) {
                [errors addObject:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:[self currentToken]]]];
            }
            else {
                NSString *identifier = [currentContext.parser.string substringWithRange:[self consumeToken].range];
                
                LXVariable *variable = [functionScope createVariable:identifier type:[self findType:type]];
                token.variable = variable;
                
                [arguments addObject:variable];
            }
            
            if(![self consumeToken:',']) {
                if(![self consumeToken:')']) {
                    [errors addObject:[NSString stringWithFormat:@"Expected ')' near: %@", [self tokenValue:[self currentToken]]]];
                }
                
                break;
            }
        }
        else if([self consumeToken:LX_TK_DOTS]) {
            isVarArg = YES;
            
            if(![self consumeToken:')']) {
                [errors addObject:[NSString stringWithFormat:@"Expected ')' near: %@", [self tokenValue:[self currentToken]]]];
            }
            
            break;
        }
        else {
            [errors addObject:[NSString stringWithFormat:@"Expected 'type' near: %@", [self tokenValue:[self currentToken]]]];
            [self matchToken:'('];
            
            break;
        }
    }
    
    functionStatement.returnTypes = returnTypes;
    functionStatement.arguments = arguments;
    functionStatement.isVarArg = isVarArg;
    functionStatement.body = [self parseBlock:functionScope];
    
    [self popScope];

    if(![self consumeToken:LX_TK_END]) {
        [errors addObject:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:[self currentToken]]]];
    }
    
    return functionStatement;
}

- (LXNodeClassStatement *)parseClassStatement:(LXScope *)scope {
    LXNodeClassStatement *classStatement = [[LXNodeClassStatement alloc] init];
    
    if([self currentToken].type != LX_TK_NAME) {
        [errors addObject:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:[self currentToken]]]];
    }
    else {
        classStatement.name = [self tokenValue:[self consumeToken]];
    }
    
    if([self consumeToken:LX_TK_EXTENDS]) {
        if([self currentToken].type != LX_TK_NAME) {
            [errors addObject:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:[self currentToken]]]];
        }
        else {
            classStatement.superclass = [self tokenValue:[self consumeToken]];
        }
    }
    
    LXScope *classScope = [self pushScope:scope openScope:YES];
    classScope.type = LXScopeTypeClass;
    
    NSMutableArray *functions = [NSMutableArray array];
    NSMutableArray *variables = [NSMutableArray array];
    NSMutableArray *variableDeclarations = [NSMutableArray array];
    
    NSMutableArray *functionIndices = [NSMutableArray array];
    
    while([self currentToken].type != LX_TK_END) {
        if([self consumeToken:LX_TK_FUNCTION]) {
            [functionIndices addObject:@(currentTokenIndex)];
            
            [self closeBlock:LX_TK_FUNCTION];
        }
        else if([[self currentToken] isType]) {
            LXNodeDeclarationStatement *declarationStatement = [[LXNodeDeclarationStatement alloc] init];
            
            LXToken *typeToken = [self currentToken];
            NSString *type = [self tokenValue:[self consumeToken]];
            LXClass *variableType = [self findType:type];
            typeToken.variableType = variableType;
            
            if([self currentToken].type != LX_TK_NAME) {
                [errors addObject:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:[self currentToken]]]];
            }
            else {
                
            }
            
            LXToken *currentToken = [self currentToken];
            
            NSString *var = [self tokenValue:[self consumeToken]];
            
            LXVariable *variable = [classScope createVariable:var type:[self findType:type]];

            currentToken.variable = variable;
            [variables addObject:variable];
            
            NSMutableArray *varList = [NSMutableArray arrayWithObject:variable];
            NSMutableArray *initList = [NSMutableArray array];
            
            while([self consumeToken:',']) {
                if([self currentToken].type != LX_TK_NAME) {
                    [errors addObject:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:[self currentToken]]]];
                }
                
                LXToken *currentToken = [self currentToken];

                var = [self tokenValue:[self consumeToken]];
                
                LXVariable *variable = [classScope createVariable:var type:[self findType:type]];
                
                currentToken.variable = variable;
                [variables addObject:variable];

                [varList addObject:variable];
            }
            
            if([self consumeToken:'=']) {
                do {
                    [initList addObject:[self parseExpression:scope]];
                } while([self consumeToken:',']);
            }
            
            declarationStatement.variables = varList;
            declarationStatement.initializers = initList;
            
            [variableDeclarations addObject:declarationStatement];
        }
        else {
            [errors addObject:[NSString stringWithFormat:@"Expected function or variable declaration near: %@", [self tokenValue:[self currentToken]]]];
            
            [self matchToken:LX_TK_CLASS];
            break;
        }
        
        if([self currentToken].type == LX_TK_END) {
            NSInteger endIndex = currentTokenIndex;
            
            for(NSNumber *index in functionIndices) {
                currentTokenIndex = index.integerValue;
                
                LXNodeFunctionExpression *functionExpression = [self parseFunction:classScope anonymous:NO isLocal:NO];
                
                LXNode *functionName = functionExpression.name;
                
                //Kind of hacky
                if([functionName isKindOfClass:[LXNodeVariableExpression class]]) {
                    LXNodeVariableExpression *base = [[LXNodeVariableExpression alloc] init];
                    base.variable = classStatement.name;
                    
                    LXNodeMemberExpression *memberExpression = [[LXNodeMemberExpression alloc] init];
                    memberExpression.base = base;
                    memberExpression.useColon = YES;
                    memberExpression.value = ((LXNodeVariableExpression *)functionName).variable;
                    
                    functionExpression.name = memberExpression;
                }
                else {
                    //error?
                }
                
                LXNodeFunctionStatement *functionStatement = [[LXNodeFunctionStatement alloc] init];
                functionStatement.expression = functionExpression;
                
                //functionStatement.isLocal = YES;
                [functions addObject:functionStatement];
            }
            
            currentTokenIndex = endIndex;
        }
    }
    
    [self popScope];
    
    if(![self consumeToken:LX_TK_END]) {
        [errors addObject:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:[self currentToken]]]];
    }
    
    classStatement.functions = functions;
    classStatement.variables = variables;
    classStatement.variableDeclarations = variableDeclarations;
    
    LXClass *scriptClass = [[LXClassBase alloc] init];
    scriptClass.name = classStatement.name;
    if(classStatement.superclass)
        scriptClass.parent = [self findType:classStatement.superclass];
    scriptClass.variables = variables;
    scriptClass.functions = functions;
    
    [self declareType:classStatement.name objectType:scriptClass];
    
    return classStatement;
}

- (LXNodeStatement *)parseStatement:(LXScope *)scope {
    BOOL isLocal = ![scope isGlobalScope];
    
    if([self consumeToken:LX_TK_LOCAL]) {
        isLocal = YES;
    }
    else if([self consumeToken:LX_TK_GLOBAL]) {
        isLocal = NO;
    }
    
    LXToken *current = [self currentToken];
    
    if([self consumeToken:LX_TK_IF]) {
        LXNodeIfStatement *ifStatement = [[LXNodeIfStatement alloc] init];
        ifStatement.condition = [self parseExpression:scope];
        
        if(ifStatement.condition == nil) {
            LXToken *token = [self currentToken];
            
            BOOL continueParsing = NO;
            
            while(token.endLine == current.endLine) {
                if(token.type == LX_TK_THEN) {
                    continueParsing = YES;
                    break;
                }
                else if(token.type == LX_TK_ELSE ||
                        token.type == LX_TK_ELSEIF ||
                        token.type == LX_TK_END) {
                    //escape..
                }
                
                [self consumeToken];
                token = [self currentToken];
            }
            
            if(!continueParsing) {
                [self matchToken:LX_TK_IF];
                return ifStatement;
            }
        }
        
        if(![self consumeToken:LX_TK_THEN]) {
            [errors addObject:[NSString stringWithFormat:@"Expected 'then' near: %@", [self tokenValue:[self currentToken]]]];
        }
        
        ifStatement.body = [self parseBlock:scope];
        
        NSMutableArray *elseIfStatements = [NSMutableArray array];
        
        while([self consumeToken:LX_TK_ELSEIF]) {
            LXNodeElseIfStatement *elseIfStatement = [[LXNodeElseIfStatement alloc] init];
            elseIfStatement.condition = [self parseExpression:scope];
            
            if(elseIfStatement.condition == nil) {
            }
            
            if(![self consumeToken:LX_TK_THEN]) {
                [errors addObject:[NSString stringWithFormat:@"Expected 'then' near: %@", [self tokenValue:[self currentToken]]]];
            }
            
            elseIfStatement.body = [self parseBlock:scope];
            [elseIfStatements addObject:elseIfStatement];
        }
        
        ifStatement.elseIfStatements = elseIfStatements;
        
        if([self consumeToken:LX_TK_ELSE]) {
            ifStatement.elseStatement = [self parseBlock:scope];
        }
        
        if(![self consumeToken:LX_TK_END]) {
            [errors addObject:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:[self currentToken]]]];
        }
        
        return ifStatement;
    }
    else if([self consumeToken:LX_TK_WHILE]) {
        LXNodeWhileStatement *whileStatement = [[LXNodeWhileStatement alloc] init];
        whileStatement.condition = [self parseExpression:scope];
        
        if(whileStatement.condition == nil) {
            
        }
        
        if(![self consumeToken:LX_TK_DO]) {
            [errors addObject:[NSString stringWithFormat:@"Expected 'do' near: %@", [self tokenValue:[self currentToken]]]];
        }
        
        whileStatement.body = [self parseBlock:scope];
        
        if(![self consumeToken:LX_TK_END]) {
            [errors addObject:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:[self currentToken]]]];
        }
        
        return whileStatement;
    }
    else if([self consumeToken:LX_TK_DO]) {
        LXNodeDoStatement *doStatement = [[LXNodeDoStatement alloc] init];
        
        doStatement.body = [self parseBlock:scope];
        
        if(![self consumeToken:LX_TK_END]) {
            [errors addObject:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:[self currentToken]]]];
        }
        
        return doStatement;
    }
    else if([self consumeToken:LX_TK_FOR]) {
        if([self currentToken].type != LX_TK_NAME) {
            [errors addObject:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:[self currentToken]]]];
        }
        
        NSString *baseVarName = [self tokenValue:[self consumeToken]];
        if([self consumeToken:'=']) {
            LXNodeNumericForStatement *forStatement = [[LXNodeNumericForStatement alloc] init];
            
            LXScope *forScope = [self pushScope:scope openScope:NO];
            [forScope createVariable:baseVarName type:[self findType:@"Number"]];
            
            forStatement.variable = baseVarName;
            forStatement.startExpression = [self parseExpression:scope];
            
            if(![self consumeToken:',']) {
                [errors addObject:[NSString stringWithFormat:@"Expected ',' near: %@", [self tokenValue:[self currentToken]]]];
            }
            
            forStatement.endExpression = [self parseExpression:scope];
            
            if([self consumeToken:',']) {
                forStatement.stepExpression = [self parseExpression:scope];
            }
            
            if(![self consumeToken:LX_TK_DO]) {
                [errors addObject:[NSString stringWithFormat:@"Expected 'do' near: %@", [self tokenValue:[self currentToken]]]];
            }
            
            forStatement.body = [self parseBlock:forScope];
            
            [self popScope];
            
            if(![self consumeToken:LX_TK_END]) {
                [errors addObject:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:[self currentToken]]]];
            }
            
            return forStatement;
        }
        else {
            LXNodeGenericForStatement *forStatement = [[LXNodeGenericForStatement alloc] init];
            
            LXScope *forScope = [self pushScope:scope openScope:NO];
            [forScope createVariable:baseVarName type:nil];
            
            NSMutableArray *varList = [NSMutableArray arrayWithObject:baseVarName];
            
            while([self consumeToken:',']) {
                if([self currentToken].type != LX_TK_NAME) {
                    [errors addObject:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:[self currentToken]]]];
                }
                
                NSString *varName = [self tokenValue:[self consumeToken]];
                [varList addObject:varName];
            }
            
            forStatement.variableList = varList;
            
            if(![self consumeToken:LX_TK_IN]) {
                [errors addObject:[NSString stringWithFormat:@"Expected 'in' near: %@", [self tokenValue:[self currentToken]]]];
            }
            
            NSMutableArray *generators = [NSMutableArray array];
            
            do {
                LXNode *generator = [self parseExpression:scope];
                [generators addObject:generator];
            } while([self consumeToken:',']);
            
            forStatement.generators = generators;
            
            if(![self consumeToken:LX_TK_DO]) {
                [errors addObject:[NSString stringWithFormat:@"Expected 'do' near: %@", [self tokenValue:[self currentToken]]]];
            }
            
            forStatement.body = [self parseBlock:forScope];
            
            [self popScope];
            
            if(![self consumeToken:LX_TK_END]) {
                [errors addObject:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:[self currentToken]]]];
            }
            
            return forStatement;
        }
    }
    else if([self consumeToken:LX_TK_REPEAT]) {
        LXNodeRepeatStatement *repeatStatement = [[LXNodeRepeatStatement alloc] init];
        
        repeatStatement.body = [self parseBlock:scope];
        
        if(![self consumeToken:LX_TK_UNTIL]) {
            [errors addObject:[NSString stringWithFormat:@"Expected 'until' near: %@", [self tokenValue:[self currentToken]]]];
        }
        
        repeatStatement.condition = [self parseExpression:scope];
        
        return repeatStatement;
    }
    else if([self consumeToken:LX_TK_FUNCTION]) {
        LXNodeFunctionExpression *functionExpression = [self parseFunction:scope anonymous:NO isLocal:isLocal];
        LXNodeFunctionStatement *functionStatement = [[LXNodeFunctionStatement alloc] init];
        functionStatement.expression = functionExpression;
        functionStatement.isLocal = isLocal && [functionExpression.name class] == [LXNodeVariableExpression class]; //Hacky
        
        return functionStatement;
    }
    else if([self consumeToken:LX_TK_CLASS]) {
        LXNodeClassStatement *classStatement = [self parseClassStatement:scope];
        classStatement.isLocal = isLocal;
        
        return classStatement;
    }
    else if([self consumeToken:LX_TK_DBCOLON]) {
        LXNodeLabelStatement *labelStatement = [[LXNodeLabelStatement alloc] init];
        
        if([self currentToken].type != LX_TK_NAME) {
            [errors addObject:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:[self currentToken]]]];
        }
        else {
            labelStatement.label = [self tokenValue:[self currentToken]];
        }
        
        if(![self consumeToken:LX_TK_DBCOLON]) {
            [errors addObject:[NSString stringWithFormat:@"Expected '::' near: %@", [self tokenValue:[self currentToken]]]];
        }
        
        return labelStatement;
    }
    else if([self consumeToken:LX_TK_RETURN]) {
        LXNodeReturnStatement *returnStatement = [[LXNodeReturnStatement alloc] init];
        
        NSMutableArray *arguments = [NSMutableArray array];
        if([self currentToken].type != LX_TK_END) {
            do {
                LXNode *expression = [self parseExpression:scope];
                
                if(expression != nil)
                    [arguments addObject:expression];
            } while([self consumeToken:',']);
        }
        
        returnStatement.arguments = arguments;
        
        return returnStatement;
    }
    else if([self consumeToken:LX_TK_BREAK]) {
        LXNodeBreakStatement *breakStatement = [[LXNodeBreakStatement alloc] init];
        
        return breakStatement;
    }
    else if([self consumeToken:LX_TK_GOTO]) {
        LXNodeGotoStatement *gotoStatement = [[LXNodeGotoStatement alloc] init];
        
        if([self currentToken].type != LX_TK_NAME) {
            [errors addObject:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:[self currentToken]]]];
        }
        else {
            gotoStatement.label = [self tokenValue:[self currentToken]];
        }
        
        return gotoStatement;
    }
    else if([self consumeToken:';']) {
        LXNodeEmptyStatement *emptyStatement = [[LXNodeEmptyStatement alloc] init];
        
        return emptyStatement;
    }
    else {
        if([[self currentToken] isType] && [self nextToken].type == LX_TK_NAME && [self currentToken].startLine == [self nextToken].endLine) {
            LXNodeDeclarationStatement *declarationStatement = [[LXNodeDeclarationStatement alloc] init];
            
            LXToken *typeToken = [self currentToken];
            NSString *type = [self tokenValue:[self consumeToken]];
            
            LXToken *variableToken = [self currentToken];
            NSString *var = [self tokenValue:[self consumeToken]];
            
            LXVariable *variable = nil;
            LXClass *variableType = [self findType:type];
            
            if(isLocal) {
                variable = [scope localVariable:var];
                
                if(variable) {
                    [errors addObject:@"Variable already defined."];
                }
                else {
                    variable = [scope createVariable:var type:variableType];
                }
            }
            else {
                variable = [self.globalScope localVariable:var];
                
                if(variable) {
                    if(variable.isDefined) {
                        [errors addObject:@"Variable already defined."];
                    }
                    else {
                        variable.type = variableType;
                    }
                }
                else {
                    variable = [self.globalScope createVariable:var type:variableType];
                }
            }
            
            typeToken.variableType = variableType;
            variableToken.variable = variable;
            
            NSMutableArray *varList = [NSMutableArray arrayWithObject:variable];
            NSMutableArray *initList = [NSMutableArray array];
            
            while([self consumeToken:',']) {
                if([self currentToken].type != LX_TK_NAME) {
                    [errors addObject:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:[self currentToken]]]];
                }
                else {
                    LXToken *currentToken = [self currentToken];
                    NSString *var = [self tokenValue:[self consumeToken]];

                    LXVariable *variable = nil;
                    
                    if(isLocal) {
                        variable = [scope localVariable:var];
                        
                        if(variable) {
                            [errors addObject:@"Variable already defined."];
                        }
                        else {
                            variable = [scope createVariable:var type:[self findType:type]];
                        }
                    }
                    else {
                        variable = [self.globalScope localVariable:var];
                        
                        if(variable) {
                            if(variable.isDefined) {
                                [errors addObject:@"Variable already defined."];
                            }
                            else {
                                variable.type = [self findType:type];
                            }
                        }
                        else {
                            variable = [self.globalScope createVariable:var type:[self findType:type]];
                        }
                    }
                    
                    currentToken.variable = variable;
                    [varList addObject:variable];
                }
            }
            
            if([self consumeToken:'=']) {
                do {
                    LXNode *expression = [self parseExpression:scope];
                    
                    if(expression != nil)
                        [initList addObject:expression];
                } while([self consumeToken:',']);
            }
            
            declarationStatement.variables = varList;
            declarationStatement.initializers = initList;
            declarationStatement.isLocal = isLocal;
            
            return declarationStatement;
        }
        else {
            LXNode *expression = [self parseSuffixedExpression:scope onlyDotColon:NO];
            
            if(expression && ([self currentToken].type == ',' || [self currentToken].type == '=')) {
                LXNodeAssignmentStatement *assignmentStatement = [[LXNodeAssignmentStatement alloc] init];
                NSMutableArray *varList = [NSMutableArray arrayWithObject:expression];
                NSMutableArray *initList = [NSMutableArray array];
                
                while([self consumeToken:',']) {
                    LXNode *expression = [self parseSuffixedExpression:scope onlyDotColon:NO];
                    
                    if(expression != nil)
                        [varList addObject:expression];
                }
                
                if(![self consumeToken:'=']) {
                    [errors addObject:[NSString stringWithFormat:@"Expected '=' near: %@", [self tokenValue:[self currentToken]]]];
                }
                
                do {
                    LXNode *expression = [self parseExpression:scope];
                    
                    if(expression != nil)
                        [initList addObject:expression];
                } while([self consumeToken:',']);
                
                assignmentStatement.variables = varList;
                assignmentStatement.initializers = initList;
                
                return assignmentStatement;
            }
            else {
                if(![expression isKindOfClass:[LXNodeCallExpression class]] &&
                   ![expression isKindOfClass:[LXNodeTableCallExpression class]] &&
                   ![expression isKindOfClass:[LXNodeStringCallExpression class]]) {
                    [errors addObject:@"Expected call expression"];
                }
                
                LXNodeExpressionStatement *expressionStatement = [[LXNodeExpressionStatement alloc] init];
                
                expressionStatement.expression = expression;
                return expressionStatement;
            }
        }
    }
}

- (LXNodeBlock *)parseBlock:(LXScope *)scope {
    NSDictionary *closeKeywords = @{@(LX_TK_END) : @YES, @(LX_TK_ELSE) : @YES, @(LX_TK_ELSEIF) : @YES, @(LX_TK_UNTIL) : @YES};
    
    LXNodeBlock *block = [[LXNodeBlock alloc] init];
    
    LXScope *blockScope = [self pushScope:scope openScope:YES];
    block.scope = blockScope;
    
    NSMutableArray *statements = [NSMutableArray array];
    while(!closeKeywords[@([self currentToken].type)] &&
          [self currentToken].type != LX_TK_EOS) {
        LXNodeStatement *statement = [self parseStatement:block.scope];
        
        [statements addObject:statement];
    }
    
    block.statements = statements;
    
    [self popScope];
    
    return block;
}

@end
