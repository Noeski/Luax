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
#import "NSString+JSON.h"

@implementation LXCompilerError
@end

@implementation LXCompiler

- (id)init {
    if(self = [super init]) {
        _fileMap = [[NSMutableDictionary alloc] init];
        _baseTypeMap = [[NSMutableDictionary alloc] init];
        _typeMap = [[NSMutableDictionary alloc] init];
        
        _baseTypeMap[@"Number"] = [LXClassNumber classNumber];
        _baseTypeMap[@"Bool"] = [LXClassBool classBool];
        _baseTypeMap[@"String"] = [LXClassString classString];
        _baseTypeMap[@"Table"] = [LXClassTable classTable];
        _baseTypeMap[@"Function"] = [LXClassFunction classFunction];

        self.globalScope = [[LXScope alloc] initWithParent:nil openScope:NO];
    }
    
    return self;
}

- (LXContext *)compilerContext:(NSString *)name {
    return self.fileMap[name];
}

- (void)compile:(NSString *)name string:(NSString *)string {
    LXContext *context = self.fileMap[name];
    
    if(!context) {
        context = [[LXContext alloc] initWithName:name compiler:self];
        self.fileMap[name] = context;
    }
    
    [context compile:string];
}

- (void)save {
    for(LXContext *context in [self.fileMap allValues]) {
        if(context.errors) {
            [context reportErrors];
        }
        else {
            //NSString *path = [context.name stringByDeletingLastPathComponent];
            //NSString *fileName = [[context.name lastPathComponent] stringByDeletingPathExtension];
            
            //[[context.block toString] writeToFile:[NSString stringWithFormat:@"%@/%@.lua", path, fileName] atomically:YES encoding:NSUTF8StringEncoding error:nil];
        }
    }
}

//////////////////////////////////////////////////////////

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

- (LXClass *)declareType:(NSString *)name objectType:(LXClass *)objectType {
    if(!name)
        return nil;
    
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
    
    return type;
}

- (LXClass *)undeclareType:(NSString *)name {
    LXClass *type = self.baseTypeMap[name];
    
    if(!type) {
        type = self.typeMap[name];
    }
    
    if(type) {
        type.isDefined = NO;
        type.parent = nil;
        type.functions = nil;
        type.variables = nil;
    }

    return type;
}

@end

@interface LXContext() {
    NSMutableArray *scopeStack;
    NSMutableArray *definedTypes;
    NSMutableArray *definedVariables;
    NSInteger currentTokenIndex;
}

@end

@implementation LXContext

- (id)initWithName:(NSString *)name compiler:(LXCompiler *)compiler {
    if(self = [super init]) {
        _name = [name copy];
        _compiler = compiler;
        _parser = [[LXParser alloc] init];
        _errors = [[NSMutableArray alloc] init];

        scopeStack = [[NSMutableArray alloc] init];
        definedTypes = [[NSMutableArray alloc] init];
        definedVariables = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void)compile:(NSString *)string {
    [self.errors removeAllObjects];

    for(LXClass *type in definedTypes) {
        [self.compiler undeclareType:type.name];
    }
    
    for(LXVariable *variable in definedVariables) {
        [self.compiler.globalScope removeVariable:variable];
    }
    
    [definedTypes removeAllObjects];
    
    [self.compiler.globalScope removeScope:self.scope];
    
    [self.parser parse:string];
    
    currentTokenIndex = 0;
        
    LXScope *blockScope;
    self.block = [self parseBlock:self.compiler.globalScope addNewLine:NO blockScope:&blockScope];
    self.scope = blockScope;
}

- (void)addError:(NSString *)error range:(NSRange)range line:(NSInteger)line column:(NSInteger)column {
    LXCompilerError *compilerError = [[LXCompilerError alloc] init];
    compilerError.error = error;
    compilerError.range = range;
    compilerError.line = line;
    compilerError.column = column;
    [self.errors addObject:compilerError];
}

- (void)reportErrors {
    NSArray *lines = [self.parser.string componentsSeparatedByString:@"\n"];
    
    for(LXCompilerError *error in self.errors) {
        NSString *line = lines[error.line];
        
        NSLog(@"%@", error.error);
        NSLog(@"%@", line);
        NSLog(@"%@", [NSString stringWithFormat:@"%@^", [@"" stringByPaddingToLength:error.column withString:@" " startingAtIndex:0]]);
    }
}

- (LXClass *)findType:(NSString *)name {
    if(name == nil)
        return nil;
    
    return [self.compiler findType:name];
}

- (LXClass *)declareType:(NSString *)name objectType:(LXClass *)objectType {
    if(name == nil)
        return nil;
    
    LXClass *type = [self.compiler declareType:name objectType:objectType];
    
    [definedTypes addObject:type];
    
    return type;
}

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

- (LXToken *)token:(NSInteger *)index {
    while(YES) {
        if(*index < 0) {
            //Not really eof, but bof ;)
            LXToken *eofToken = [[LXToken alloc] init];
            eofToken.type = LX_TK_EOS;
            eofToken.range = NSMakeRange(0, 0);
            
            return eofToken;
        }
        else if(*index >= [self.parser.tokens count]) {
            LXToken *eofToken = [[LXToken alloc] init];
            eofToken.type = LX_TK_EOS;
            eofToken.range = NSMakeRange([self.parser.string length], 0);
            
            return eofToken;
        }
        
        LXToken *token = self.parser.tokens[*index];
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

- (void)closeBlock:(LXTokenType)type {
    static __strong NSArray *openTokens = nil;
    
    if(!openTokens)
        openTokens = @[
                   @(LX_TK_DO), @(LX_TK_FOR), @(LX_TK_FUNCTION), @(LX_TK_IF),
                   @(LX_TK_WHILE), @(LX_TK_CLASS)
                   ];
    
    NSInteger index = currentTokenIndex;
    
    LXToken *token = [self token:&index];
    
    NSMutableArray *tokenStack = [NSMutableArray arrayWithObject:@(type)];
    
    while(token.type != LX_TK_EOS && [tokenStack count]) {
        if(token.type == LX_TK_END) {
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

- (void)skipLine {
    NSInteger index = currentTokenIndex;
    
    LXToken *token = [self token:&index];
    NSInteger line = token.endLine;
    
    while(token.type != LX_TK_EOS && token.endLine == line) {
        ++index;
        
        token = [self token:&index];
    }
    
    currentTokenIndex = index;
}

- (NSString *)tokenValue:(LXToken *)token {
    if(token.type == LX_TK_EOS) {
        return @"end of file";
    }
    
    return [self.parser.string substringWithRange:token.range];
}

#pragma mark - Expressions 

- (LXNode *)parseSimpleExpression:(LXScope *)scope {
    LXToken *token = [self currentToken];
    LXNode *expression = [[LXNode alloc] initWithLine:token.startLine column:token.column];
    
    switch((NSInteger)token.type) {
        case LX_TK_NUMBER: {
            [self consumeToken];
            [expression addChunk:[self tokenValue:token] line:token.startLine column:token.column];
            break;
        }
        
        case LX_TK_STRING: {
            [self consumeToken];
            [expression addChunk:[self tokenValue:token] line:token.startLine column:token.column];
            break;
        }
        
        case LX_TK_NIL: {
            [self consumeToken];
            [expression addChunk:@"nil" line:token.startLine column:token.column];
            break;
        }
        
        case LX_TK_TRUE: {
            [self consumeToken];
            [expression addChunk:@"true" line:token.startLine column:token.column];
            break;
        }
        
        case LX_TK_FALSE: {
            [self consumeToken];
            [expression addChunk:@"false" line:token.startLine column:token.column];
            break;
        }
        
        case LX_TK_DOTS: {
            [self consumeToken];
            [expression addChunk:@"..." line:token.startLine column:token.column];
            break;
        }
        
        case LX_TK_FUNCTION: {
            [expression addChild:[self parseFunction:scope anonymous:YES isLocal:YES function:NULL class:nil]];
            break;
        }
        
        case '{': {
            [self consumeToken];
            [expression addChunk:@"{" line:token.startLine column:token.column];

            do {
                token = [self currentToken];
                
                if(token.type == '[') {
                    [self consumeToken];
                    
                    [expression addChunk:@"[" line:token.startLine column:token.column];
                    [expression addChild:[self parseExpression:scope]];

                    LXToken *endBracketToken = [self currentToken];
                    
                    if(endBracketToken.type != ']') {
                        [self addError:[NSString stringWithFormat:@"Expected ']' near: %@", [self tokenValue:endBracketToken]] range:endBracketToken.range line:endBracketToken.startLine column:endBracketToken.column];
                        break;
                    }
                    
                    [self consumeToken];
                    
                    [expression addChunk:@"]" line:endBracketToken.startLine column:endBracketToken.column];

                    LXToken *equalsToken = [self currentToken];

                    if(equalsToken.type != '=') {
                        [self addError:[NSString stringWithFormat:@"Expected '=' near: %@", [self tokenValue:equalsToken]] range:equalsToken.range line:equalsToken.startLine column:equalsToken.column];
                        break;
                    }
                    
                    [self consumeToken];
                    
                    [expression addChunk:@"=" line:equalsToken.startLine column:equalsToken.column];
                    [expression addChild:[self parseExpression:scope]];
                }
                else if(token.type == LX_TK_NAME) {
                    [expression addChild:[self parseExpression:scope]];

                    LXToken *equalsToken = [self currentToken];
                    
                    if(equalsToken.type == '=') {
                        [self consumeToken];
                        
                        [expression addChunk:@"=" line:equalsToken.startLine column:equalsToken.column];
                        [expression addChild:[self parseExpression:scope]];
                    }
                }
                else if(token.type == '}') {
                    [self consumeToken];
                    
                    [expression addChunk:@"}" line:token.startLine column:token.column];
                    break;
                }
                else {
                    [expression addChild:[self parseExpression:scope]];
                }
                
                token = [self currentToken];

                if(token.type ==';' || token.type == ',') {
                    [self consumeToken];
                    
                    [expression addChunk:@"," line:token.startLine column:token.column];
                }
                else if(token.type == '}') {
                    [self consumeToken];
                    
                    [expression addChunk:@"}" line:token.startLine column:token.column];
                    break;
                }
                else {
                    [self addError:[NSString stringWithFormat:@"Expected ';', ',' or '}' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
                    break;
                }
            } while(YES);
            
            break;
        }
        
        default:
            [expression addChild:[self parseSuffixedExpression:scope onlyDotColon:NO]];
            break;
    }
    
    return expression;
}

- (LXNode *)parseSuffixedExpression:(LXScope *)scope onlyDotColon:(BOOL)onlyDotColon {
    LXNode *expression = [self parsePrimaryExpression:scope];
    LXNode *lastExpression = expression;
    
    do {
        LXToken *token = [self currentToken];
        LXNode *expression = [[LXNode alloc] initWithLine:token.startLine column:token.column];

        if(token.type == '.' ||
           token.type == ':') {
            token.completionFlags = LXTokenCompletionFlagsMembers;
            token.variableType = lastExpression.variable.type;
            [self consumeToken];
            
            [expression addChunk:token.type == ':' ? @":" : @"." line:token.startLine column:token.column];
            
            LXToken *nameToken = [self currentToken];
            NSString *name = [self tokenValue:nameToken];
            
            if(nameToken.type != LX_TK_NAME) {
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:nameToken]] range:nameToken.range line:nameToken.startLine column:nameToken.column];
                [self skipLine];
                break;
            }

            [self consumeToken];
            [expression addNamedChunk:name line:nameToken.startLine column:nameToken.column];
            expression.assignable = YES;
            
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
        else if(!onlyDotColon && token.type == '[') {
            [self consumeToken];
            
            [expression addChunk:@"[" line:token.startLine column:token.column];
            [expression addChild:[self parseExpression:scope]];
        
            LXToken *endBracketToken = [self currentToken];
            
            if(endBracketToken.type != ']') {
                [self addError:[NSString stringWithFormat:@"Expected ']' near: %@", [self tokenValue:endBracketToken]] range:endBracketToken.range line:endBracketToken.startLine column:endBracketToken.column];
                [self skipLine];
                break;
            }
            
            [self consumeToken];
            [expression addChunk:@"]" line:endBracketToken.startLine column:endBracketToken.column];
            expression.assignable = YES;
        }
        else if(!onlyDotColon && token.type == '(') {
            [self consumeToken];
            
            [expression addChunk:@"(" line:token.startLine column:token.column];
            
            LXToken *endParenToken = [self currentToken];
            
            while(endParenToken.type != ')') {
                [expression addChild:[self parseExpression:scope]];
                
                endParenToken = [self currentToken];
                
                if(endParenToken.type != ',') {
                    if(endParenToken.type != ')') {
                        [self addError:[NSString stringWithFormat:@"Expected ')' near: %@", [self tokenValue:endParenToken]] range:endParenToken.range line:endParenToken.startLine column:endParenToken.column];
                        break;
                    }
                }
                else {
                    [self consumeToken];
                    
                    [expression addChunk:@"," line:endParenToken.startLine column:endParenToken.column];
                }
            }
            
            [self consumeToken];
            
            [expression addChunk:@")" line:endParenToken.startLine column:endParenToken.column];
            expression.assignable = NO;
            
            if(lastExpression.variable.isFunction) {
                LXFunction *function = (LXFunction *)lastExpression.variable;
                
                expression.variable = [function.returnTypes count] ? function.returnTypes[0] : nil;
            }
        }
        else if(!onlyDotColon && token.type == LX_TK_STRING) {
            [self consumeToken];
            
            [expression addChunk:[self tokenValue:token] line:token.startLine column:token.column];
            expression.assignable = NO;

            if(lastExpression.variable.isFunction) {
                LXFunction *function = (LXFunction *)lastExpression.variable;
                
                expression.variable = [function.returnTypes count] ? function.returnTypes[0] : nil;
            }
        }
        else if(!onlyDotColon && token.type == '{') {
            [expression addChild:[self parseExpression:scope]];
            expression.assignable = NO;

            if(lastExpression.variable.isFunction) {
                LXFunction *function = (LXFunction *)lastExpression.variable;
                
                expression.variable = [function.returnTypes count] ? function.returnTypes[0] : nil;
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

- (LXNode *)parsePrimaryExpression:(LXScope *)scope {
    LXToken *token = [self currentToken];
    
    LXNode *expression = [[LXNode alloc] initWithLine:token.startLine column:token.column];
    
    if(token.type == '(') {
        [self consumeToken];
        
        [expression addChunk:@"(" line:token.startLine column:token.column];
        [expression addChild:[self parseExpression:scope]];
        
        LXToken *endParenToken = [self currentToken];
        
        if(endParenToken.type != ')') {
            [self addError:[NSString stringWithFormat:@"Expected ')' near: %@", [self tokenValue:endParenToken]] range:endParenToken.range line:endParenToken.startLine column:endParenToken.column];
            [self skipLine];
            return expression;
        }
        
        [self consumeToken];
        
        [expression addChunk:@")" line:endParenToken.startLine column:endParenToken.column];
        //TODO: find expression type?
        expression.assignable = NO;
    }
    else if(token.type == LX_TK_NAME) {
        [self consumeToken];
        
        NSString *name = [self tokenValue:token];
        LXVariable *variable = [scope variable:name];
        
        if(!variable) {
            variable = [self.compiler.globalScope createVariable:name type:nil];
            [definedVariables addObject:variable];
        }
        
        if(variable.isMember) {
            [expression addAnonymousChunk:@"self."];
        }
        
        [expression addNamedChunk:name line:token.startLine column:token.column];

        token.variable = variable;
        expression.variable = variable;
        expression.assignable = YES;
    }
    else {
        NSLog(@"%@", [self tokenValue:[self currentToken]]);
        [self addError:[NSString stringWithFormat:@"Expected 'name' or '(expression)' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
        [self skipLine];
    }
    
    return expression;
}

- (LXNode *)parseSubExpression:(LXScope *)scope level:(NSInteger)level {
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
    
    LXToken *currentToken = [self currentToken];
    LXNode *expression = [[LXNode alloc] initWithLine:currentToken.startLine column:currentToken.column];

    if(unaryOps[@(currentToken.type)]) {
        [self consumeToken];
        
        [expression addChunk:[self tokenValue:currentToken] line:currentToken.startLine column:currentToken.column];
        [expression addChild:[self parseSubExpression:scope level:8]];
    }
    else {
        [expression addChild:[self parseSimpleExpression:scope]];
        
        do {
            LXToken *operatorToken = [self currentToken];
            
            NSValue *priority = priorityDict[@(operatorToken.type)];
                
            if(priority && priority.rangeValue.location > level) {
                [self consumeToken];
                
                [expression addChunk:[self tokenValue:operatorToken] line:operatorToken.startLine column:operatorToken.column];
                [expression addChild:[self parseSubExpression:scope level:priority.rangeValue.length]];
            }
            else {
                break;
                
            }
        } while (YES);
    }
    
    return expression;
}

- (LXNode *)parseExpression:(LXScope *)scope {
    return [self parseSubExpression:scope level:0];
}

#pragma mark - Function

- (LXNode *)parseFunction:(LXScope *)scope anonymous:(BOOL)anonymous isLocal:(BOOL)isLocal function:(LXFunction **)functionPtr class:(NSString *)class {
    LXToken *functionToken = [self consumeToken];
    LXNode *node = [[LXNode alloc] initWithLine:functionToken.startLine column:functionToken.column];

    [node addChunk:@"function" line:functionToken.startLine column:functionToken.column];
    
    LXScope *functionScope = [self pushScope:scope openScope:NO];
    functionScope.type = LXScopeTypeFunction;
    
    BOOL checkingReturnType = NO;
    BOOL hasReturnType = NO;
    BOOL hasEmptyReturnType = NO;
    
    LXToken *leftParenToken, *rightParenToken;
    
    NSMutableArray *returnTypes = [NSMutableArray array];
    
    LXToken *current = [self currentToken];
    
    if(current.type == '(') {
        checkingReturnType = YES;

        leftParenToken = current;
        
        [self consumeToken];
        current = [self currentToken];
        
        if(current.type == ')' ||
           (([current isType] || current.type == LX_TK_DOTS) &&
            ([self nextToken].type == ',' || [self nextToken].type == ')'))) {
               hasReturnType = YES;
               
               while(current.type != ')') {
                   if([current isType]) {
                       [self consumeToken];
                       NSString *type = [self tokenValue:current];
                       LXClass *variableType = [self findType:type];
                       current.variableType = variableType;
                       
                       LXVariable *variable = [[LXVariable alloc] init];
                       variable.type = variableType;
                       variable.isGlobal = NO;
                       variable.isMember = NO;
                       
                       [returnTypes addObject:variable];
                       
                       current = [self currentToken];
                       
                       if(current.type == ',') {
                           [self consumeToken];
                       }
                       else {
                           break;
                       }
                       
                   }
                   else if(current.type == LX_TK_DOTS) {
                       [self consumeToken];
                   }
                   else {
                       [self addError:[NSString stringWithFormat:@"Expected 'type' near: %@", [self tokenValue:current]] range:current.range line:current.startLine column:current.column];
                       break;
                   }
                   
                   current = [self currentToken];
               }
               
               if(current.type != ')') {
                   [self addError:[NSString stringWithFormat:@"Expected ')' near: %@", [self tokenValue:current]] range:current.range line:current.startLine column:current.column];
               }
               
               rightParenToken = current;
               [self consumeToken];
           }
    }
    
    LXFunction *function = nil;
    
    if(!anonymous) {
        LXToken *nameToken = [self currentToken];
        
        if(nameToken.type == LX_TK_NAME) {
            [self consumeToken];
            
            NSString *functionName = [self tokenValue:nameToken];
            [node addAnonymousChunk:@" "];
            
            if(class) {
                [node addAnonymousChunk:[NSString stringWithFormat:@"%@:", class]];
            }
            
            [node addNamedChunk:functionName line:nameToken.startLine column:nameToken.column];
            
            if(isLocal) {
                function = (LXFunction *)[scope localVariable:functionName];
                
                if(function) {
                    //ERROR
                }
                else {
                    function = [scope createFunction:functionName];
                }
            }
            else {
                function = [self.compiler.globalScope createFunction:functionName];
                [definedVariables addObject:functionName];
            }
            
            nameToken.variable = function;
            
            LXToken *token = [self currentToken];
            
            while(token.type == '.' ||
                  token.type == ':') {
                [self consumeToken];
                
                [node addChunk:token.type == ':' ? @":" : @"." line:token.startLine column:token.column];
                
                nameToken = [self currentToken];
                functionName = [self tokenValue:nameToken];
                
                if(nameToken.type != LX_TK_NAME) {
                    [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:nameToken]] range:nameToken.range line:nameToken.startLine column:nameToken.column];
                    
                    break;
                }
                
                [self consumeToken];
                [node addNamedChunk:functionName line:nameToken.startLine column:nameToken.column];
                
                token = [self currentToken];
                
                /*if(variable.isDefined && variable.type.isDefined) {
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
                }*/
            }
        }
        
        current = [self currentToken];
        
        if(current.type != '(') {
            [self addError:[NSString stringWithFormat:@"Expected '(' near: %@", [self tokenValue:current]] range:current.range line:current.startLine column:current.column];
        }
        
        [self consumeToken];
        [node addChunk:@"(" line:current.startLine column:current.column];
    }
    else {
        if(checkingReturnType && hasReturnType) {
            current = [self currentToken];

            if(current.type != '(') {
                if([returnTypes count] == 0) {
                    hasEmptyReturnType = YES;
                    [node addChunk:@"(" line:leftParenToken.startLine column:leftParenToken.column];
                    [node addChunk:@")" line:rightParenToken.startLine column:rightParenToken.column];
                }
                else {
                    [self addError:[NSString stringWithFormat:@"Expected '(' near: %@", [self tokenValue:current]] range:current.range line:current.startLine column:current.column];
                }
            }
            else {
                [self consumeToken];
                [node addChunk:@"(" line:current.startLine column:current.column];
            }
        }
        else {
            [node addChunk:@"(" line:current.startLine column:current.column];
        }
    }
    
    current = [self currentToken];
    
    BOOL isVarArg = NO;
    NSMutableArray *arguments = [NSMutableArray array];
    
    while(!hasEmptyReturnType && current.type != ')') {
        if([current isType]) {
            LXToken *typeToken = [self currentToken];
            NSString *type = [self tokenValue:typeToken];
            LXClass *variableType = [self findType:type];
            typeToken.variableType = variableType;
            
            [self consumeToken];
            
            LXToken *nameToken = [self currentToken];
            
            if(nameToken.type != LX_TK_NAME) {
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:nameToken]] range:nameToken.range line:nameToken.startLine column:nameToken.column];
            }
            
            NSString *name = [self tokenValue:nameToken];
            LXVariable *variable = [functionScope createVariable:name type:variableType];
            nameToken.variable = variable;
            
            [arguments addObject:variable];
            
            [self consumeToken];
            [node addNamedChunk:name line:nameToken.startLine column:nameToken.column];

            current = [self currentToken];
            
            if(current.type == ',') {
                [self consumeToken];
                [node addChunk:@"," line:current.startLine column:current.column];
            }
            else {
                break;
            }
        }
        else if(current.type == LX_TK_DOTS) {
            isVarArg = YES;

            [self consumeToken];
            [node addChunk:@"..." line:current.startLine column:current.column];

            break;
        }
        else {
            [self addError:[NSString stringWithFormat:@"Expected 'type' near: %@", [self tokenValue:current]] range:current.range line:current.startLine column:current.column];
            break;
        }
        
        current = [self currentToken];
    }
    
    if(!hasEmptyReturnType) {
        if(current.type != ')') {
            [self addError:[NSString stringWithFormat:@"Expected ')' near: %@", [self tokenValue:current]] range:current.range line:current.startLine column:current.column];
        }
        
        [node addChunk:@")" line:current.startLine column:current.column];
        [self consumeToken];
    }
    
    [node addChild:[self parseBlock:functionScope]];
    [self popScope];
    
    LXToken *endToken = [self currentToken];
    
    if(endToken.type != LX_TK_END) {
        [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:endToken]] range:endToken.range line:endToken.startLine column:endToken.column];
    }
    
    [node addChunk:@"end" line:endToken.startLine column:endToken.column];
    [self consumeToken];

    function.returnTypes = returnTypes;
    function.arguments = arguments;
    
    if(functionPtr)
        *functionPtr = function;
    
    return node;
}

#pragma mark - Class

- (LXNode *)parseClassStatement:(LXScope *)scope {
    LXToken *classToken = [self consumeToken];
    LXNode *class = [[LXNode alloc] initWithLine:classToken.startLine column:classToken.column];
    
    NSMutableArray *functions = [NSMutableArray array];
    NSMutableArray *variables = [NSMutableArray array];
    
    NSMutableArray *functionIndices = [NSMutableArray array];
    
    LXToken *nameToken = [self currentToken];
    
    if(nameToken.type != LX_TK_NAME) {
        [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:nameToken]] range:nameToken.range line:nameToken.startLine column:nameToken.column];
    }

    NSString *name = [self tokenValue:nameToken];
    NSString *superclass = nil;
    
    [self consumeToken];
    
    LXToken *extendsToken = [self currentToken];
    
    if(extendsToken.type == LX_TK_EXTENDS) {
        [self consumeToken];
        
        LXToken *typeToken = [self currentToken];
        
        if(![typeToken isType]) {
            [self addError:[NSString stringWithFormat:@"Expected 'name' or 'type' near: %@", [self tokenValue:typeToken]] range:typeToken.range line:typeToken.startLine column:typeToken.column];
        }
        
        superclass = [self tokenValue:typeToken];
        [self consumeToken];
    }
    
    if(superclass) {
        [class addAnonymousChunk:[NSString stringWithFormat:@"%@ = %@ or setmetatable({}, {__call = function(class, ...)\n  local obj = setmetatable({class = \"%@\", super = %@}, {__index = class})\n  obj:init(...)\n  return obj\nend})\n", name, name, name, superclass]];
        [class addAnonymousChunk:[NSString stringWithFormat:@"for k, v in pairs(%@) do\n  %@[k] = v\nend\n", superclass, name]];
        [class addAnonymousChunk:[NSString stringWithFormat:@"function %@:init(...)\n  %@.init(self, ...)\n", name, superclass]];
    }
    else {
        [class addAnonymousChunk:[NSString stringWithFormat:@"%@ = %@ or setmetatable({}, {__call = function(class, ...)\n  local obj = setmetatable({class = \"%@\"}, {__index = class})\n  obj:init(...)\n  return obj\nend})\n", name, name, name]];
        [class addAnonymousChunk:[NSString stringWithFormat:@"function %@:init(...)\n", name]];
    }
    
    LXScope *classScope = [self pushScope:scope openScope:YES];
    classScope.type = LXScopeTypeClass;
    
    LXVariable *variable = [classScope createVariable:@"self" type:[self findType:name]];
    [variables addObject:variable];
    
    if(superclass) {
        LXVariable *variable = [classScope createVariable:@"super" type:[self findType:superclass]];
        variable.isMember = YES;
        [variables addObject:variable];
    }
    
    LXToken *current = [self currentToken];

    while(current.type != LX_TK_END) {
        if(current.type == LX_TK_FUNCTION) {
            [functionIndices addObject:@(currentTokenIndex)];
            
            [self consumeToken];
            [self closeBlock:LX_TK_FUNCTION];
        }
        else if([current isType]) {
            LXToken *typeToken = [self currentToken];
            NSString *type = [self tokenValue:typeToken];
            LXClass *variableType = [self findType:type];
            typeToken.variableType = variableType;
            [self consumeToken];
            
            LXToken *nameToken = [self currentToken];
            
            if(nameToken.type != LX_TK_NAME) {
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:nameToken]] range:nameToken.range line:nameToken.startLine column:nameToken.column];
            }
            
            NSString *name = [self tokenValue:nameToken];
            
            LXVariable *variable = [classScope createVariable:name type:variableType];
            variable.isMember = YES;
            nameToken.variable = variable;
            [variables addObject:variable];
            
            [self consumeToken];
            
            NSMutableArray *initList = [NSMutableArray array];
            
            current = [self currentToken];
            
            while(current.type == ',') {
                [self consumeToken];
                
                nameToken = [self currentToken];
                [self consumeToken];

                if(nameToken.type != LX_TK_NAME) {
                    [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:nameToken]] range:nameToken.range line:nameToken.startLine column:nameToken.column];
                }
                
                name = [self tokenValue:nameToken];
                LXVariable *variable = [classScope createVariable:name type:variableType];
                variable.isMember = YES;
                
                nameToken.variable = variable;
                [variables addObject:variable];
                
                current = [self currentToken];
            }
            
            if(current.type == '=') {
                [self consumeToken];
                
                do {
                    [initList addObject:[self parseExpression:scope]];
                    
                    current = [self currentToken];
                    if(current.type == ',') {
                        [self consumeToken];
                        continue;
                    }
                    
                    break;
                } while(YES);
            }
            
            NSInteger offset = superclass ? 2 : 1;
            
            for(NSInteger i = offset; i < [variables count]; ++i) {
                LXVariable *variable = variables[i];
                
                [class addAnonymousChunk:@"self."];
                [class addAnonymousChunk:variable.name];
                [class addAnonymousChunk:@"="];
                
                if(i-offset < [initList count]) {
                    [class addChild:initList[i-offset]];
                }
                else {
                    [class addChild:[variable.type defaultExpression]];
                }
                
                [class addAnonymousChunk:@"\n"];
            }
        }
        else {
            [self addError:[NSString stringWithFormat:@"Expected function or variable declaration near: %@", [self tokenValue:current]] range:current.range line:current.startLine column:current.column];
            break;
        }
        
        LXToken *endToken = [self currentToken];
        
        if(endToken.type == LX_TK_END) {
            [class addAnonymousChunk:@"end"];
            
            NSInteger endIndex = currentTokenIndex;
            
            for(NSNumber *index in functionIndices) {
                currentTokenIndex = index.integerValue;
                
                LXFunction *function;
                [class addAnonymousChunk:@"\n"];
                [class addChild:[self parseFunction:classScope anonymous:NO isLocal:YES function:&function class:name]];
                
                if(function)
                    [variables addObject:function];
            }
            
            currentTokenIndex = endIndex;
        }
        
        current = [self currentToken];
    }
    
    [self popScope];
    
    LXToken *endToken = [self currentToken];

    if(endToken.type != LX_TK_END) {
        [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:endToken]] range:endToken.range line:endToken.startLine column:endToken.column];
    }
    
    [self consumeToken];
    
    LXClass *scriptClass = [[LXClassBase alloc] init];
    scriptClass.name = name;
    if(superclass)
        scriptClass.parent = [self findType:superclass];
    scriptClass.variables = variables;
    scriptClass.functions = functions;
    
    [self declareType:name objectType:scriptClass];
    
    return class;
}

#pragma mark - Statements

- (LXNode *)parseStatement:(LXScope *)scope {
    BOOL isLocal = ![scope isGlobalScope];
    
    if([self consumeToken:LX_TK_LOCAL]) {
        isLocal = YES;
    }
    else if([self consumeToken:LX_TK_GLOBAL]) {
        isLocal = NO;
    }
    
    LXToken *current = [self currentToken];
    LXNode *statement = [[LXNode alloc] initWithLine:current.startLine column:current.column];
    
    switch((NSInteger)current.type) {
        case LX_TK_IF: {
            current.completionFlags = LXTokenCompletionFlagsVariables;

            [self consumeToken];
            
            [statement addChunk:@"if" line:current.startLine column:current.column];
            [statement addAnonymousChunk:@" "];
            [statement addChild:[self parseExpression:scope]];
        
            LXToken *thenToken = [self currentToken];
    
            if(thenToken.type != LX_TK_THEN) {
                [self addError:[NSString stringWithFormat:@"Expected 'then' near: %@", [self tokenValue:thenToken]] range:thenToken.range line:thenToken.startLine column:thenToken.column];
                [self skipLine];
            }
        
            thenToken.completionFlags = LXTokenCompletionFlagsBlock;

            [self consumeToken];
        
            [statement addAnonymousChunk:@" "];
            [statement addChunk:@"then" line:thenToken.startLine column:thenToken.column];
            [statement addChild:[self parseBlock:scope]];

            LXToken *elseIfToken = [self currentToken];
        
            while(elseIfToken.type == LX_TK_ELSEIF) {
                elseIfToken.completionFlags = LXTokenCompletionFlagsVariables;

                [self consumeToken];

                [statement addChunk:@"elseif" line:elseIfToken.startLine column:elseIfToken.column];
                [statement addAnonymousChunk:@" "];
                [statement addChild:[self parseExpression:scope]];
                
                thenToken = [self currentToken];
                
                if(thenToken.type != LX_TK_THEN) {
                    [self addError:[NSString stringWithFormat:@"Expected 'then' near: %@", [self tokenValue:thenToken]] range:thenToken.range line:thenToken.startLine column:thenToken.column];
                    [self skipLine];
                    break;
                }
                
                thenToken.completionFlags = LXTokenCompletionFlagsBlock;
                
                [self consumeToken];
                
                [statement addAnonymousChunk:@" "];
                [statement addChunk:@"then" line:thenToken.startLine column:thenToken.column];
                [statement addChild:[self parseBlock:scope]];

                elseIfToken = [self currentToken];
            }
        
            LXToken *elseToken = [self currentToken];

            if(elseToken.type == LX_TK_ELSE) {
                elseToken.completionFlags = LXTokenCompletionFlagsBlock;

                [self consumeToken];
                
                [statement addChunk:@"else" line:elseToken.startLine column:elseToken.column];
                [statement addChild:[self parseBlock:scope]];
            }
        
            LXToken *endToken = [self currentToken];

            if(endToken.type != LX_TK_END) {
                [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:endToken]] range:endToken.range line:endToken.startLine column:endToken.column];
                break;
            }
        
            endToken.completionFlags = LXTokenCompletionFlagsBlock;

            [self consumeToken];

            [statement addChunk:@"end" line:endToken.startLine column:endToken.column];
        
            break;
        }
        
        case LX_TK_WHILE: {
            current.completionFlags = LXTokenCompletionFlagsVariables;

            [self consumeToken];
            
            [statement addChunk:@"while" line:current.startLine column:current.column];
            [statement addAnonymousChunk:@" "];
            [statement addChild:[self parseExpression:scope]];

            LXToken *doToken = [self currentToken];
            
            if(doToken.type != LX_TK_DO) {
                [self addError:[NSString stringWithFormat:@"Expected 'do' near: %@", [self tokenValue:doToken]] range:doToken.range line:doToken.startLine column:doToken.column];
                [self skipLine];
                break;
            }
            
            doToken.completionFlags = LXTokenCompletionFlagsBlock;

            [self consumeToken];
            
            [statement addAnonymousChunk:@" "];
            [statement addChunk:@"do" line:doToken.startLine column:doToken.column];
            [statement addChild:[self parseBlock:scope]];

            LXToken *endToken = [self currentToken];
            
            if(endToken.type != LX_TK_END) {
                [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:endToken]] range:endToken.range line:endToken.startLine column:endToken.column];
                break;
            }
            
            endToken.completionFlags = LXTokenCompletionFlagsBlock;

            [self consumeToken];

            [statement addChunk:@"end" line:endToken.startLine column:endToken.column];
            
            break;
        }
        
        case LX_TK_DO: {
            current.completionFlags = LXTokenCompletionFlagsBlock;

            [self consumeToken];

            [statement addChunk:@"do" line:current.startLine column:current.column];
            [statement addChild:[self parseBlock:scope]];

            LXToken *endToken = [self currentToken];
            
            if(endToken.type != LX_TK_END) {
                [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:endToken]] range:endToken.range line:endToken.startLine column:endToken.column];
                break;
            }
            
            endToken.completionFlags = LXTokenCompletionFlagsBlock;
            
            [self consumeToken];
            
            [statement addChunk:@"end" line:endToken.startLine column:endToken.column];
            
            break;
        }
        
        case LX_TK_FOR: {
            current.completionFlags = LXTokenCompletionFlagsTypes | LXTokenCompletionFlagsVariables;

            [self consumeToken];
            
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
            
            doToken.completionFlags = LXTokenCompletionFlagsBlock;
            [self consumeToken];
            
            [statement addAnonymousChunk:@" "];
            [statement addChunk:@"do" line:doToken.startLine column:doToken.column];
            
            [statement addChild:[self parseBlock:scope]];
            
            [self popScope];
            
            LXToken *endToken = [self currentToken];
            
            if(endToken.type != LX_TK_END) {
                [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:endToken]] range:endToken.range line:endToken.startLine column:endToken.column];
                break;
            }
            
            endToken.completionFlags = LXTokenCompletionFlagsBlock;
            
            [self consumeToken];
            
            [statement addChunk:@"end" line:endToken.startLine column:endToken.column];
            
            break;
        }
        
        case LX_TK_REPEAT: {
            current.completionFlags = LXTokenCompletionFlagsBlock;
            
            [self consumeToken];

            [statement addChunk:@"repeat" line:current.startLine column:current.column];
            [statement addChild:[self parseBlock:scope]];

            LXToken *untilToken = [self currentToken];

            if(untilToken.type != LX_TK_UNTIL) {
                [self addError:[NSString stringWithFormat:@"Expected 'until' near: %@", [self tokenValue:untilToken]] range:untilToken.range line:untilToken.startLine column:untilToken.column];
                [self skipLine];
                break;
            }
            
            untilToken.completionFlags = LXTokenCompletionFlagsVariables;
            
            [statement addChunk:@"until" line:untilToken.startLine column:untilToken.column];
            [statement addAnonymousChunk:@" "];
            [self consumeToken];
            
            [statement addChild:[self parseExpression:scope]];

            break;
        }
        
        case LX_TK_FUNCTION:
            [statement addChild:[self parseFunction:scope anonymous:NO isLocal:isLocal function:NULL class:nil]];
            break;
        
        case LX_TK_CLASS:
            [statement addChild:[self parseClassStatement:scope]];
            break;
        
        case LX_TK_DBCOLON: {
            [self consumeToken];
            [statement addChunk:@"::" line:current.startLine column:current.column];

            LXToken *nameToken = [self currentToken];
            
            if(nameToken.type != LX_TK_NAME) {
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:nameToken]] range:nameToken.range line:nameToken.startLine column:nameToken.column];
                [self skipLine];
                break;
            }
            
            [statement addChunk:[self tokenValue:nameToken] line:nameToken.startLine column:nameToken.column];
            [self consumeToken];
            
            LXToken *endLabelToken = [self currentToken];

            if(endLabelToken.type != LX_TK_DBCOLON) {
                [self addError:[NSString stringWithFormat:@"Expected '::' near: %@", [self tokenValue:endLabelToken]] range:endLabelToken.range line:endLabelToken.startLine column:endLabelToken.column];
                [self skipLine];
                break;
            }
            
            [self consumeToken];
            [statement addChunk:@"::" line:current.startLine column:current.column];
            
            break;
        }
        
        case LX_TK_RETURN: {
            current.completionFlags = LXTokenCompletionFlagsVariables;
            
            [self consumeToken];
            [statement addChunk:@"return" line:current.startLine column:current.column];
            [statement addAnonymousChunk:@" "];

            if([self currentToken].type != LX_TK_END) {
                do {
                    [statement addChild:[self parseExpression:scope]];
                    
                    LXToken *commaToken = [self currentToken];
                    
                    if(commaToken.type == ',') {
                        [self consumeToken];
                        [statement addChunk:@"," line:commaToken.startLine column:commaToken.column];

                        continue;
                    }
                    
                    break;
                } while(YES);
            }
            
            break;
        }
        
        case LX_TK_BREAK: {
            current.completionFlags = LXTokenCompletionFlagsBlock;
            
            [self consumeToken];
            [statement addChunk:@"break" line:current.startLine column:current.column];
            break;
        }
        
        case LX_TK_GOTO: {
            [self consumeToken];
            [statement addChunk:@"goto" line:current.startLine column:current.column];
            [statement addAnonymousChunk:@" "];

            LXToken *nameToken = [self currentToken];
            
            if(nameToken.type != LX_TK_NAME) {
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:nameToken]] range:nameToken.range line:nameToken.startLine column:nameToken.column];
                [self skipLine];
                break;
            }
            
            [statement addChunk:[self tokenValue:nameToken] line:nameToken.startLine column:nameToken.column];
            [self consumeToken];
            
            break;
        }
        
        case ';': {
            current.completionFlags = LXTokenCompletionFlagsBlock;
            
            [self consumeToken];
            [statement addChunk:@";" line:current.startLine column:current.column];
            break;
        }
        
        default: {
            if([current isType] &&
               [self nextToken].type == LX_TK_NAME &&
               current.startLine == [self nextToken].endLine) {
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
                    [self consumeToken];
                    
                    [statement addChunk:@"=" line:commaToken.startLine column:commaToken.column];

                    do {
                        [statement addChild:[self parseExpression:scope]];

                        ++index;
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
                        [self consumeToken];
                        
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
                    
                    [self consumeToken];
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
                            [self consumeToken];
                            
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
}

- (LXNode *)parseBlock:(LXScope *)scope {
    return [self parseBlock:scope addNewLine:YES];
}

- (LXNode *)parseBlock:(LXScope *)scope addNewLine:(BOOL)addNewLine {
    LXScope *blockScope = nil;
    
    return [self parseBlock:scope addNewLine:YES blockScope:&blockScope];
}

- (LXNode *)parseBlock:(LXScope *)scope addNewLine:(BOOL)addNewLine blockScope:(LXScope **)blockScope {
    LXToken *token = [self currentToken];
    NSDictionary *closeKeywords = @{@(LX_TK_END) : @YES, @(LX_TK_ELSE) : @YES, @(LX_TK_ELSEIF) : @YES, @(LX_TK_UNTIL) : @YES};
    
    LXNode *block = [[LXNode alloc] initWithLine:token.startLine column:token.endLine];
    
    *blockScope = [self pushScope:scope openScope:YES];
    
    BOOL firstStatement = !addNewLine;
    
    while(!closeKeywords[@([self currentToken].type)] && [self currentToken].type != LX_TK_EOS) {
        if(!firstStatement)
            [block addAnonymousChunk:@"\n"];

        LXNode *statement = [self parseStatement:*blockScope];
        
        [block addChild:statement];
        
        firstStatement = NO;
    }
    
    if(!firstStatement && addNewLine)
        [block addAnonymousChunk:@"\n"];
    
    [self popScope];
    
    return block;
}

@end