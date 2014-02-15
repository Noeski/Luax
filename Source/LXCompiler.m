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
#import "LXCompiler+Expression.h"
#import "LXCompiler+Statement.h"

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

        _globalScope = [[LXScope alloc] initWithParent:nil openScope:NO];
        
        [_globalScope createVariable:@"_VERSION" type:[LXClassString classString]];
        [_globalScope createFunction:@"assert"];
        [_globalScope createFunction:@"collectgarbage"];
        [_globalScope createFunction:@"dofile"];
        [_globalScope createFunction:@"error"];
        [_globalScope createFunction:@"getmetatable"];
        [_globalScope createFunction:@"ipairs"];
        [_globalScope createFunction:@"load"];
        [_globalScope createFunction:@"loadfile"];
        [_globalScope createFunction:@"next"];
        [_globalScope createFunction:@"pairs"];
        [_globalScope createFunction:@"pcall"];
        [_globalScope createFunction:@"print"];
        [_globalScope createFunction:@"rawequal"];
        [_globalScope createFunction:@"rawget"];
        [_globalScope createFunction:@"rawlen"];
        [_globalScope createFunction:@"rawset"];
        [_globalScope createFunction:@"require"];
        [_globalScope createFunction:@"select"];
        [_globalScope createFunction:@"setmetatable"];
        [_globalScope createFunction:@"tonumber"];
        [_globalScope createFunction:@"tostring"];
        [_globalScope createFunction:@"type"];
        [_globalScope createFunction:@"xpcall"];
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
        type.name = name;
        type.isDefined = NO;
        
        self.typeMap[name] = type;
    }
    
    return type;
}

- (LXClass *)declareType:(NSString *)name objectType:(LXClass *)objectType {
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
    [definedVariables removeAllObjects];
    
    [self.compiler.globalScope removeScope:self.scope];
    
    [self.parser parse:string];
    
    self.currentTokenIndex = 0;
    
    _currentScope = self.compiler.globalScope;
    
    LXBlock *block = [self parseBlock];
    [block verify];
    [block resolveVariables:self];
    [block resolveTypes:self];
    
    self.block = block;
    self.scope = block.scope;
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
    return [self.compiler findType:name];
}

- (void)declareType:(LXClass *)type {
    type.isDefined = YES;
    
    [definedTypes addObject:type];
}

- (LXClass *)declareType:(NSString *)name objectType:(LXClass *)objectType {
    LXClass *type = [self.compiler declareType:name objectType:objectType];
    
    [definedTypes addObject:type];
    
    return type;
}

- (LXScope *)pushScope:(LXScope *)parent openScope:(BOOL)openScope {
    if(scopeStack == nil) {
        scopeStack = [[NSMutableArray alloc] init];
    }
    
    _currentScope = [[LXScope alloc] initWithParent:parent openScope:openScope];
    _currentScope.range = NSMakeRange(NSMaxRange([self previousToken].range), 0);
    
    [scopeStack addObject:_currentScope];
    
    return _currentScope;
}

- (LXScope *)createScope:(BOOL)openScope {
    if(scopeStack == nil) {
        scopeStack = [[NSMutableArray alloc] init];
    }
    
    _currentScope = [[LXScope alloc] initWithParent:_currentScope openScope:openScope];
    _currentScope.range = NSMakeRange(NSMaxRange([self previousToken].range), 0);
    
    [scopeStack addObject:_currentScope];
    
    return _currentScope;
}

- (void)pushScope:(LXScope *)scope {
    if(scopeStack == nil) {
        scopeStack = [[NSMutableArray alloc] init];
    }
    
    _currentScope = scope;
    
    [scopeStack addObject:_currentScope];
}

- (void)popScope {
    if([scopeStack count] == 0) {
        //error
    }
    
    _currentScope.range = NSMakeRange(_currentScope.range.location, [self currentToken].range.location - _currentScope.range.location);
    [scopeStack removeLastObject];
    _currentScope = [scopeStack lastObject];
}

- (LXScope *)currentScope {
    return _currentScope;
}

- (void)setCurrentTokenIndex:(NSInteger)index {
    _nextTokenIndex = index;
    _current = [self previousToken:_nextTokenIndex];
    _next = [self token:&_nextTokenIndex];
    
    [self advance];
}

- (LXToken *)previousToken:(NSInteger)index {
    if(index >= [self.parser.tokens count]) {
        index = [self.parser.tokens count]-1;
    }
    
    while(YES) {
        if(index < 0) {
            //Not really eof, but bof ;)
            LXToken *eofToken = [[LXToken alloc] init];
            eofToken.type = LX_TK_EOS;
            eofToken.range = NSMakeRange(0, 0);
            
            return eofToken;
        }
        
        LXToken *token = self.parser.tokens[index];
        if(token.type == LX_TK_COMMENT || token.type == LX_TK_LONGCOMMENT) {
            --index;
            continue;
        }
        
        return token;
    }
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
    return _current;
}

- (LXToken *)previousToken {
    return _previous;
}

- (LXToken *)nextToken {
    return _next;
}

- (LXToken *)consumeToken {
    return [self consumeToken:0];
}

- (LXToken *)consumeToken:(LXTokenCompletionFlags)completionFlags {
    LXToken *token = _current;
    //token.scope = [self currentScope];
    token.completionFlags = completionFlags;
    
    [self advance];
    return token;
}

- (LXToken *)consumeTokenType:(LXTokenType)type {
    LXToken *token = _current;
    
    if(token.type == type) {
        //token.scope = [self currentScope];
        
        [self advance];
        
        return token;
    }
    
    return nil;
}

- (void)advance {
    _previous = _current;
    _current = _next;
    
    _currentTokenIndex = _nextTokenIndex;
    _nextTokenIndex++;
    _next = [self token:&_nextTokenIndex];
}

- (NSString *)tokenValue:(LXToken *)token {
    if(token.type == LX_TK_EOS) {
        return @"end of file";
    }
    
    return [self.parser.string substringWithRange:token.range];
}

- (void)closeBlock:(LXTokenType)type {
    static __strong NSArray *openTokens = nil;
    
    if(!openTokens)
        openTokens = @[
                       @(LX_TK_DO), @(LX_TK_FOR), @(LX_TK_FUNCTION), @(LX_TK_IF),
                       @(LX_TK_WHILE), @(LX_TK_CLASS)
                       ];
    
    NSInteger index = self.currentTokenIndex;
    
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
    
    self.currentTokenIndex = index;
}

- (void)skipLine {
    NSInteger index = self.currentTokenIndex;
    
    LXToken *token = [self token:&index];
    NSInteger line = token.endLine;
    
    while(token.type != LX_TK_EOS && token.endLine == line) {
        ++index;
        
        token = [self token:&index];
    }
    
    self.currentTokenIndex = index;
}

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

- (LXTokenNode *)consumeTokenNode {
    LXTokenNode *tokenNode = [LXTokenNode tokenNodeWithToken:_current];
    tokenNode.value = [self tokenValue:_current];
    [self advance];
    
    return tokenNode;
}

#pragma mark - Expressions 

- (LXNode *)parseSimpleExpression:(LXScope *)scope {
    LXToken *token = [self currentToken];
    LXNode *expression = [[LXNode alloc] initWithLine:token.line column:token.column];
    
    switch((NSInteger)token.type) {
        case LX_TK_NUMBER: {
            [self consumeToken];
            [expression addChunk:[self tokenValue:token] line:token.line column:token.column];
            break;
        }
        
        case LX_TK_STRING: {
            [self consumeToken];
            [expression addChunk:[self tokenValue:token] line:token.line column:token.column];
            break;
        }
        
        case LX_TK_NIL: {
            [self consumeToken];
            [expression addChunk:@"nil" line:token.line column:token.column];
            break;
        }
        
        case LX_TK_TRUE: {
            [self consumeToken];
            [expression addChunk:@"true" line:token.line column:token.column];
            break;
        }
        
        case LX_TK_FALSE: {
            [self consumeToken];
            [expression addChunk:@"false" line:token.line column:token.column];
            break;
        }
        
        case LX_TK_DOTS: {
            [self consumeToken];
            [expression addChunk:@"..." line:token.line column:token.column];
            break;
        }
        
        case LX_TK_FUNCTION: {
            [expression addChild:[self parseFunction:scope anonymous:YES isLocal:YES function:NULL class:nil]];
            break;
        }
        
        case '{': {
            [self consumeToken:LXTokenCompletionFlagsVariables];
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
            
            break;
        }
        
        default: {
            LXNode *subExpression = [self parseSuffixedExpression:scope onlyDotColon:NO];
            [expression addChild:subExpression];
            expression.variable = subExpression.variable;
            break;
        }
    }
    
    return expression;
}

- (LXNode *)parseSuffixedExpression:(LXScope *)scope onlyDotColon:(BOOL)onlyDotColon {
    LXNode *expression = [self parsePrimaryExpression:scope];
    LXNode *lastExpression = expression;
    
    do {
        LXToken *token = [self currentToken];
        LXNode *expression = [[LXNode alloc] initWithLine:token.line column:token.column];

        if(token.type == '.' ||
           token.type == ':') {
            token.variable = lastExpression.variable;
            [self consumeToken:token.type == ':' ? LXTokenCompletionFlagsFunctions :LXTokenCompletionFlagsMembers];
            
            [expression addChunk:token.type == ':' ? @":" : @"." line:token.line column:token.column];
            
            LXToken *nameToken = [self currentToken];
            NSString *name = [self tokenValue:nameToken];
            
            if(nameToken.type != LX_TK_NAME) {
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:nameToken]] range:nameToken.range line:nameToken.line column:nameToken.column];
                [self skipLine];
                break;
            }

            [self consumeToken];
            [expression addNamedChunk:name line:nameToken.line column:nameToken.column];
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
        else if(!onlyDotColon && token.type == '(') {
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

- (LXNode *)parsePrimaryExpression:(LXScope *)scope {
    LXToken *token = [self currentToken];
    
    LXNode *expression = [[LXNode alloc] initWithLine:token.line column:token.column];
    
    if(token.type == '(') {
        [self consumeToken:LXTokenCompletionFlagsVariables];
        
        [expression addChunk:@"(" line:token.line column:token.column];
        
        LXNode *subExpression = [self parseExpression:scope];
        [expression addChild:subExpression];
        
        LXToken *endParenToken = [self currentToken];
        
        if(endParenToken.type != ')') {
            [self addError:[NSString stringWithFormat:@"Expected ')' near: %@", [self tokenValue:endParenToken]] range:endParenToken.range line:endParenToken.line column:endParenToken.column];
            [self skipLine];
            return expression;
        }
        
        [self consumeToken:LXTokenCompletionFlagsControlStructures];
        
        [expression addChunk:@")" line:endParenToken.line column:endParenToken.column];
        expression.variable = subExpression.variable;
        expression.assignable = NO;
        endParenToken.variable = subExpression.variable;
    }
    else if(token.type == LX_TK_NAME) {
        [self consumeToken];
        
        NSString *name = [self tokenValue:token];
        LXVariable *variable = [scope variable:name];
        
        if(!variable) {
            variable = [self.compiler.globalScope createVariable:name type:nil];
            [definedVariables addObject:variable];
            
            [self addError:[NSString stringWithFormat:@"Global variable %@ not defined", variable.name] range:token.range line:token.line column:token.column];
        }
        
        if(variable.isMember) {
            [expression addAnonymousChunk:@"self."];
        }
        
        [expression addNamedChunk:name line:token.line column:token.column];

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
    LXNode *expression = [[LXNode alloc] initWithLine:currentToken.line column:currentToken.column];

    if(unaryOps[@(currentToken.type)]) {
        [self consumeToken:LXTokenCompletionFlagsVariables];
        
        [expression addChunk:[self tokenValue:currentToken] line:currentToken.line column:currentToken.column];
        [expression addChild:[self parseSubExpression:scope level:8]];
    }
    else {
        LXNode *subExpression = [self parseSimpleExpression:scope];
        
        [expression addChild:subExpression];
        expression.variable = subExpression.variable;
        
        do {
            LXToken *operatorToken = [self currentToken];
            
            NSValue *priority = priorityDict[@(operatorToken.type)];
                
            if(priority && priority.rangeValue.location > level) {
                [self consumeToken:LXTokenCompletionFlagsVariables];
                
                [expression addChunk:[self tokenValue:operatorToken] line:operatorToken.line column:operatorToken.column];
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

- (LXNode *)parseFunction:(LXScope *)scope anonymous:(BOOL)anonymous isLocal:(BOOL)isLocal function:(LXVariable **)functionPtr class:(NSString *)class {
    BOOL isStatic = ([self consumeTokenType:LX_TK_STATIC] != nil);

    LXToken *functionToken = [self consumeToken];
    LXNode *node = [[LXNode alloc] initWithLine:functionToken.line column:functionToken.column];

    [node addChunk:@"function" line:functionToken.line column:functionToken.column];
    
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
        
        [self consumeToken:LXTokenCompletionFlagsTypes];
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
                       
                       LXVariable *variable = [LXVariable variableWithType:variableType];
                       
                       [returnTypes addObject:variable];
                       
                       current = [self currentToken];
                       
                       if(current.type == ',') {
                           [self consumeToken:LXTokenCompletionFlagsTypes];
                       }
                       else {
                           break;
                       }
                       
                   }
                   else if(current.type == LX_TK_DOTS) {
                       [self consumeToken];
                   }
                   else {
                       [self addError:[NSString stringWithFormat:@"Expected 'type' near: %@", [self tokenValue:current]] range:current.range line:current.line column:current.column];
                       break;
                   }
                   
                   current = [self currentToken];
               }
               
               if(current.type != ')') {
                   [self addError:[NSString stringWithFormat:@"Expected ')' near: %@", [self tokenValue:current]] range:current.range line:current.line column:current.column];
               }
               
               rightParenToken = current;
               [self consumeToken];
           }
    }
    
    LXVariable *function = nil;
    
    if(!anonymous) {
        LXToken *nameToken = [self currentToken];
        
        if(nameToken.type == LX_TK_NAME) {
            [self consumeToken];
            
            NSString *functionName = [self tokenValue:nameToken];
            [node addAnonymousChunk:@" "];
            
            if(class) {
                [node addAnonymousChunk:[NSString stringWithFormat:@"%@%c", class, isStatic ? '.' : ':']];
            }
            
            [node addNamedChunk:functionName line:nameToken.line column:nameToken.column];
            
            if(isLocal) {
                function = [scope localVariable:functionName];
                
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
            [self addError:[NSString stringWithFormat:@"Expected '(' near: %@", [self tokenValue:current]] range:current.range line:current.line column:current.column];
        }
        
        [self consumeToken:LXTokenCompletionFlagsTypes];
        [node addChunk:@"(" line:current.line column:current.column];
    }
    else {
        if(checkingReturnType && hasReturnType) {
            current = [self currentToken];

            if(current.type != '(') {
                if([returnTypes count] == 0) {
                    hasEmptyReturnType = YES;
                    [node addChunk:@"(" line:leftParenToken.line column:leftParenToken.column];
                    [node addChunk:@")" line:rightParenToken.line column:rightParenToken.column];
                }
                else {
                    [self addError:[NSString stringWithFormat:@"Expected '(' near: %@", [self tokenValue:current]] range:current.range line:current.line column:current.column];
                }
            }
            else {
                [self consumeToken:LXTokenCompletionFlagsTypes];
                [node addChunk:@"(" line:current.line column:current.column];
            }
        }
        else {
            [node addChunk:@"(" line:current.line column:current.column];
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
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:nameToken]] range:nameToken.range line:nameToken.line column:nameToken.column];
            }
            
            NSString *name = [self tokenValue:nameToken];
            LXVariable *variable = [functionScope createVariable:name type:variableType];
            nameToken.variable = variable;
            
            [arguments addObject:variable];
            
            [self consumeToken];
            [node addNamedChunk:name line:nameToken.line column:nameToken.column];

            current = [self currentToken];
            
            if(current.type == ',') {
                [self consumeToken:LXTokenCompletionFlagsTypes];
                [node addChunk:@"," line:current.line column:current.column];
            }
            else {
                break;
            }
        }
        else if(current.type == LX_TK_DOTS) {
            isVarArg = YES;

            [self consumeToken];
            [node addChunk:@"..." line:current.line column:current.column];
            break;
        }
        else {
            [self addError:[NSString stringWithFormat:@"Expected 'type' near: %@", [self tokenValue:current]] range:current.range line:current.line column:current.column];
            break;
        }
        
        current = [self currentToken];
    }
    
    if(!hasEmptyReturnType) {
        if(current.type != ')') {
            [self addError:[NSString stringWithFormat:@"Expected ')' near: %@", [self tokenValue:current]] range:current.range line:current.line column:current.column];
        }
        
        [node addChunk:@")" line:current.line column:current.column];
        [self consumeToken:LXTokenCompletionFlagsBlock];
    }
    
    [node addChild:[self parseBlock:functionScope]];
    [self popScope];
    
    LXToken *endToken = [self currentToken];
    
    if(endToken.type != LX_TK_END) {
        [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:endToken]] range:endToken.range line:endToken.line column:endToken.column];
    }
    
    [node addChunk:@"end" line:endToken.line column:endToken.column];
    [self consumeToken:LXTokenCompletionFlagsBlock];

    function.returnTypes = returnTypes;
    function.arguments = arguments;
    function.isStatic = isStatic;
    
    if(functionPtr)
        *functionPtr = function;
    
    return node;
}

#pragma mark - Class

- (LXNode *)parseClassStatement:(LXScope *)scope {    
    LXToken *classToken = [self consumeToken];
    LXNode *class = [[LXNode alloc] initWithLine:classToken.line column:classToken.column];
    
    NSMutableArray *functions = [NSMutableArray array];
    NSMutableArray *variables = [NSMutableArray array];
    
    NSMutableArray *functionIndices = [NSMutableArray array];
    
    LXToken *nameToken = [self currentToken];
    
    if(nameToken.type != LX_TK_NAME) {
        [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:nameToken]] range:nameToken.range line:nameToken.line column:nameToken.column];
    }

    NSString *name = [self tokenValue:nameToken];
    NSString *superclass = nil;
    
    [self consumeToken:LXTokenCompletionFlagsClass];
    
    LXToken *extendsToken = [self currentToken];
    
    if(extendsToken.type == LX_TK_EXTENDS) {
        [self consumeToken:LXTokenCompletionFlagsTypes];
        
        LXToken *typeToken = [self currentToken];
        
        if(![typeToken isType]) {
            [self addError:[NSString stringWithFormat:@"Expected 'name' or 'type' near: %@", [self tokenValue:typeToken]] range:typeToken.range line:typeToken.line column:typeToken.column];
        }
        
        superclass = [self tokenValue:typeToken];
        [self consumeToken:LXTokenCompletionFlagsClass];
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
        if(current.type == LX_TK_STATIC || current.type == LX_TK_FUNCTION) {
            [functionIndices addObject:@(self.currentTokenIndex)];
            
            [self consumeTokenType:LX_TK_STATIC];
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
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:nameToken]] range:nameToken.range line:nameToken.line column:nameToken.column];
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
                    [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:nameToken]] range:nameToken.range line:nameToken.line column:nameToken.column];
                }
                
                name = [self tokenValue:nameToken];
                LXVariable *variable = [classScope createVariable:name type:variableType];
                variable.isMember = YES;
                
                nameToken.variable = variable;
                [variables addObject:variable];
                
                current = [self currentToken];
            }
            
            if(current.type == '=') {
                [self consumeToken:LXTokenCompletionFlagsVariables];
                
                do {
                    [initList addObject:[self parseExpression:scope]];
                    
                    current = [self currentToken];
                    if(current.type == ',') {
                        [self consumeToken:LXTokenCompletionFlagsVariables];
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
                    //[class addChild:[variable.type defaultExpression]];
                }
                
                [class addAnonymousChunk:@"\n"];
            }
        }
        else {
            [self addError:[NSString stringWithFormat:@"Expected function or variable declaration near: %@", [self tokenValue:current]] range:current.range line:current.line column:current.column];
            break;
        }
        
        LXToken *endToken = [self currentToken];
        
        if(endToken.type == LX_TK_END) {
            [class addAnonymousChunk:@"end"];
            
            NSInteger endIndex = self.currentTokenIndex;
            
            for(NSNumber *index in functionIndices) {
                self.currentTokenIndex = index.integerValue;
                
                LXVariable *function;
                [class addAnonymousChunk:@"\n"];
                [class addChild:[self parseFunction:classScope anonymous:NO isLocal:YES function:&function class:name]];
                
                if(function) {
                    [variables addObject:function];
                }
            }
            
            self.currentTokenIndex = endIndex;
        }
        
        current = [self currentToken];
    }
    
    [self popScope];
    
    LXToken *endToken = [self currentToken];

    if(endToken.type != LX_TK_END) {
        [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:endToken]] range:endToken.range line:endToken.line column:endToken.column];
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
    
    return class;
}

#pragma mark - Statements

- (LXNode *)parseStatement:(LXScope *)scope {
    BOOL isLocal = ![scope isGlobalScope];
    
    if([self consumeTokenType:LX_TK_LOCAL] != nil) {
        isLocal = YES;
    }
    else if([self consumeTokenType:LX_TK_GLOBAL] != nil) {
        isLocal = NO;
    }
    
    LXToken *current = [self currentToken];
    LXNode *statement = [[LXNode alloc] initWithLine:current.line column:current.column];
    
    switch((NSInteger)current.type) {
        case LX_TK_IF: {
            [self consumeToken:LXTokenCompletionFlagsVariables];
            
            [statement addChunk:@"if" line:current.line column:current.column];
            [statement addAnonymousChunk:@" "];
            [statement addChild:[self parseExpression:scope]];
        
            LXToken *thenToken = [self currentToken];
    
            if(thenToken.type != LX_TK_THEN) {
                [self addError:[NSString stringWithFormat:@"Expected 'then' near: %@", [self tokenValue:thenToken]] range:thenToken.range line:thenToken.line column:thenToken.column];
                [self skipLine];
            }
        
            [self consumeToken:LXTokenCompletionFlagsBlock];
        
            [statement addAnonymousChunk:@" "];
            [statement addChunk:@"then" line:thenToken.line column:thenToken.column];
            [statement addChild:[self parseBlock:scope]];

            LXToken *elseIfToken = [self currentToken];
        
            while(elseIfToken.type == LX_TK_ELSEIF) {
                [self consumeToken:LXTokenCompletionFlagsVariables];

                [statement addChunk:@"elseif" line:elseIfToken.line column:elseIfToken.column];
                [statement addAnonymousChunk:@" "];
                [statement addChild:[self parseExpression:scope]];
                
                thenToken = [self currentToken];
                
                if(thenToken.type != LX_TK_THEN) {
                    [self addError:[NSString stringWithFormat:@"Expected 'then' near: %@", [self tokenValue:thenToken]] range:thenToken.range line:thenToken.line column:thenToken.column];
                    [self skipLine];
                    break;
                }
                
                [self consumeToken:LXTokenCompletionFlagsBlock];
                
                [statement addAnonymousChunk:@" "];
                [statement addChunk:@"then" line:thenToken.line column:thenToken.column];
                [statement addChild:[self parseBlock:scope]];

                elseIfToken = [self currentToken];
            }
        
            LXToken *elseToken = [self currentToken];

            if(elseToken.type == LX_TK_ELSE) {
                [self consumeToken:LXTokenCompletionFlagsBlock];
                
                [statement addChunk:@"else" line:elseToken.line column:elseToken.column];
                [statement addChild:[self parseBlock:scope]];
            }
        
            LXToken *endToken = [self currentToken];

            if(endToken.type != LX_TK_END) {
                [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:endToken]] range:endToken.range line:endToken.line column:endToken.column];
                break;
            }
        
            [self consumeToken:LXTokenCompletionFlagsBlock];

            [statement addChunk:@"end" line:endToken.line column:endToken.column];
        
            break;
        }
        
        case LX_TK_WHILE: {
            [self consumeToken:LXTokenCompletionFlagsVariables];
            
            [statement addChunk:@"while" line:current.line column:current.column];
            [statement addAnonymousChunk:@" "];
            [statement addChild:[self parseExpression:scope]];

            LXToken *doToken = [self currentToken];
            
            if(doToken.type != LX_TK_DO) {
                [self addError:[NSString stringWithFormat:@"Expected 'do' near: %@", [self tokenValue:doToken]] range:doToken.range line:doToken.line column:doToken.column];
                [self skipLine];
                break;
            }
            
            [self consumeToken:LXTokenCompletionFlagsBlock];
            
            [statement addAnonymousChunk:@" "];
            [statement addChunk:@"do" line:doToken.line column:doToken.column];
            [statement addChild:[self parseBlock:scope]];

            LXToken *endToken = [self currentToken];
            
            if(endToken.type != LX_TK_END) {
                [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:endToken]] range:endToken.range line:endToken.line column:endToken.column];
                break;
            }
            
            [self consumeToken:LXTokenCompletionFlagsBlock];

            [statement addChunk:@"end" line:endToken.line column:endToken.column];
            
            break;
        }
        
        case LX_TK_DO: {
            [self consumeToken:LXTokenCompletionFlagsBlock];

            [statement addChunk:@"do" line:current.line column:current.column];
            [statement addChild:[self parseBlock:scope]];

            LXToken *endToken = [self currentToken];
            
            if(endToken.type != LX_TK_END) {
                [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:endToken]] range:endToken.range line:endToken.line column:endToken.column];
                break;
            }
            
            [self consumeToken:LXTokenCompletionFlagsBlock];
            
            [statement addChunk:@"end" line:endToken.line column:endToken.column];
            
            break;
        }
        
        case LX_TK_FOR: {
            [self consumeToken:LXTokenCompletionFlagsTypes | LXTokenCompletionFlagsVariables];
            
            [statement addChunk:@"for" line:current.line column:current.column];
            [statement addAnonymousChunk:@" "];
            
            LXScope *forScope = [self pushScope:scope openScope:NO];

            LXToken *nameToken = [self currentToken];
            
            if(![nameToken isType]) {
                [self addError:[NSString stringWithFormat:@"Expected 'name' or 'type' near: %@", [self tokenValue:nameToken]] range:nameToken.range line:nameToken.line column:nameToken.column];
                [self skipLine];
                break;
            }
            
            [self consumeToken];
            
            if([self currentToken].type == '=') {
                NSString *name = [self tokenValue:nameToken];
                
                [statement addNamedChunk:name line:nameToken.line column:nameToken.column];

                LXClass *variableType =  [LXClassNumber classNumber];
                LXVariable *variable = [forScope createVariable:name type:variableType];
                
                nameToken.variable = variable;

                [statement addChunk:@"=" line:current.line column:current.column];
                [self consumeToken];
                
                [statement addChild:[self parseExpression:scope]];
                
                LXToken *commaToken = [self currentToken];

                if(commaToken.type != ',') {
                    [self addError:[NSString stringWithFormat:@"Expected ',' near: %@", [self tokenValue:commaToken]] range:commaToken.range line:commaToken.line column:commaToken.column];
                    [self skipLine];
                    break;
                }
                
                [statement addChunk:@"," line:commaToken.line column:commaToken.column];
                [self consumeToken];
                
                [statement addChild:[self parseExpression:scope]];
                
                commaToken = [self currentToken];
                
                if(commaToken.type == ',') {
                    [statement addChunk:@"," line:commaToken.line column:commaToken.column];
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
                    [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:nameToken]] range:nameToken.range line:nameToken.line column:nameToken.column];
                    [self skipLine];
                    break;
                }
                
                NSString *name = [self tokenValue:nameToken];
                
                [statement addNamedChunk:name line:nameToken.line column:nameToken.column];

                LXVariable *variable = [forScope createVariable:name type:variableType];
                
                typeToken.variableType = variableType;
                nameToken.variable = variable;
                
                LXToken *commaToken = [self currentToken];
                
                while(commaToken.type == ',') {
                    [self consumeToken];
                    [statement addChunk:@"," line:commaToken.line column:commaToken.column];

                    nameToken = [self currentToken];
                    
                    if(![nameToken isType]) {
                        [self addError:[NSString stringWithFormat:@"Expected 'name' or 'type' near: %@", [self tokenValue:nameToken]] range:nameToken.range line:nameToken.line column:nameToken.column];
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
                        
                        [statement addNamedChunk:name line:nameToken.line column:nameToken.column];
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
                    [self addError:[NSString stringWithFormat:@"Expected 'in' near: %@", [self tokenValue:inToken]] range:inToken.range line:inToken.line column:inToken.column];
                    [self skipLine];
                    break;
                }
                
                [self consumeToken];
                [statement addAnonymousChunk:@" "];
                [statement addChunk:@"in" line:inToken.line column:inToken.column];
                [statement addAnonymousChunk:@" "];

                do {
                    [statement addChild:[self parseExpression:scope]];
                    
                    commaToken = [self currentToken];
                    
                    if(commaToken.type == ',') {
                        [self consumeToken];
                        
                        [statement addChunk:@"," line:commaToken.line column:commaToken.column];
                    }
                    else {
                        break;
                    }
                } while(YES);
            }
            
            LXToken *doToken = [self currentToken];
            
            if(doToken.type != LX_TK_DO) {
                [self addError:[NSString stringWithFormat:@"Expected 'do' near: %@", [self tokenValue:doToken]] range:doToken.range line:doToken.line column:doToken.column];
                [self skipLine];
                break;
            }
            
            [self consumeToken:LXTokenCompletionFlagsBlock];
            
            [statement addAnonymousChunk:@" "];
            [statement addChunk:@"do" line:doToken.line column:doToken.column];
            
            [statement addChild:[self parseBlock:scope]];
            
            [self popScope];
            
            LXToken *endToken = [self currentToken];
            
            if(endToken.type != LX_TK_END) {
                [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:endToken]] range:endToken.range line:endToken.line column:endToken.column];
                break;
            }
            
            [self consumeToken:LXTokenCompletionFlagsBlock];
            
            [statement addChunk:@"end" line:endToken.line column:endToken.column];
            
            break;
        }
        
        case LX_TK_REPEAT: {
            [self consumeToken:LXTokenCompletionFlagsBlock];

            [statement addChunk:@"repeat" line:current.line column:current.column];
            [statement addChild:[self parseBlock:scope]];

            LXToken *untilToken = [self currentToken];

            if(untilToken.type != LX_TK_UNTIL) {
                [self addError:[NSString stringWithFormat:@"Expected 'until' near: %@", [self tokenValue:untilToken]] range:untilToken.range line:untilToken.line column:untilToken.column];
                [self skipLine];
                break;
            }
            
            [statement addChunk:@"until" line:untilToken.line column:untilToken.column];
            [statement addAnonymousChunk:@" "];
            [self consumeToken:LXTokenCompletionFlagsVariables];
            
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
            [statement addChunk:@"::" line:current.line column:current.column];

            LXToken *nameToken = [self currentToken];
            
            if(nameToken.type != LX_TK_NAME) {
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:nameToken]] range:nameToken.range line:nameToken.line column:nameToken.column];
                [self skipLine];
                break;
            }
            
            [statement addChunk:[self tokenValue:nameToken] line:nameToken.line column:nameToken.column];
            [self consumeToken];
            
            LXToken *endLabelToken = [self currentToken];

            if(endLabelToken.type != LX_TK_DBCOLON) {
                [self addError:[NSString stringWithFormat:@"Expected '::' near: %@", [self tokenValue:endLabelToken]] range:endLabelToken.range line:endLabelToken.line column:endLabelToken.column];
                [self skipLine];
                break;
            }
            
            [self consumeToken];
            [statement addChunk:@"::" line:current.line column:current.column];
            
            break;
        }
        
        case LX_TK_RETURN: {
            [self consumeToken:LXTokenCompletionFlagsVariables];
            [statement addChunk:@"return" line:current.line column:current.column];
            [statement addAnonymousChunk:@" "];

            if([self currentToken].type != LX_TK_END) {
                do {
                    [statement addChild:[self parseExpression:scope]];
                    
                    LXToken *commaToken = [self currentToken];
                    
                    if(commaToken.type == ',') {
                        [self consumeToken:LXTokenCompletionFlagsVariables];
                        [statement addChunk:@"," line:commaToken.line column:commaToken.column];

                        continue;
                    }
                    
                    break;
                } while(YES);
            }
            
            break;
        }
        
        case LX_TK_BREAK: {
            [self consumeToken:LXTokenCompletionFlagsBlock];
            [statement addChunk:@"break" line:current.line column:current.column];
            break;
        }
        
        case LX_TK_GOTO: {
            [self consumeToken];
            [statement addChunk:@"goto" line:current.line column:current.column];
            [statement addAnonymousChunk:@" "];

            LXToken *nameToken = [self currentToken];
            
            if(nameToken.type != LX_TK_NAME) {
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:nameToken]] range:nameToken.range line:nameToken.line column:nameToken.column];
                [self skipLine];
                break;
            }
            
            [statement addChunk:[self tokenValue:nameToken] line:nameToken.line column:nameToken.column];
            [self consumeToken];
            
            break;
        }
        
        case ';': {
            [self consumeToken:LXTokenCompletionFlagsBlock];
            [statement addChunk:@";" line:current.line column:current.column];
            break;
        }
        
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
                [statement addNamedChunk:name line:nameToken.line column:nameToken.column];

                LXVariable *variable = nil;
                LXClass *variableType = [self findType:type];
                
                [typeList addObject:variableType];
                
                if(isLocal) {
                    variable = [scope localVariable:name];
                    
                    if(variable) {
                        [self addError:[NSString stringWithFormat:@"Variable %@ is already defined.", name] range:nameToken.range line:nameToken.line column:nameToken.column];
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
                            [self addError:[NSString stringWithFormat:@"Variable %@ is already defined.", name] range:nameToken.range line:nameToken.line column:nameToken.column];
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
                    
                    [statement addChunk:@"," line:commaToken.line column:commaToken.column];
                    
                    nameToken = [self currentToken];

                    if(nameToken.type != LX_TK_NAME) {
                        [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:nameToken]] range:nameToken.range line:nameToken.line column:nameToken.column];
                        break;
                    }
                    
                    [self consumeToken];
                    name = [self tokenValue:nameToken];
                    [statement addNamedChunk:name line:nameToken.line column:nameToken.column];
                    [typeList addObject:variableType];

                    variable = nil;
                    
                    if(isLocal) {
                        variable = [scope localVariable:name];
                        
                        if(variable) {
                            [self addError:[NSString stringWithFormat:@"Variable %@ is already defined.", name] range:nameToken.range line:nameToken.line column:nameToken.column];
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
                                [self addError:[NSString stringWithFormat:@"Variable %@ is already defined.", name] range:nameToken.range line:nameToken.line column:nameToken.column];
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
                    
                    [statement addChunk:@"=" line:commaToken.line column:commaToken.column];

                    do {
                        [statement addChild:[self parseExpression:scope]];

                        ++index;
                        commaToken = [self currentToken];
                        
                        if(commaToken.type == ',') {
                            [self consumeToken:LXTokenCompletionFlagsVariables];
                            
                            [statement addChunk:@"," line:commaToken.line column:commaToken.column];
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
                        [self addError:[NSString stringWithFormat:@"Unexpected assignment token near: %@", [self tokenValue:assignmentToken]] range:assignmentToken.range line:assignmentToken.line column:assignmentToken.column];
                    }
                    
                    NSMutableArray *declarations = [NSMutableArray array];
                    [declarations addObject:declaration];
                    
                    while(assignmentToken.type == ',') {
                        [self consumeToken:LXTokenCompletionFlagsVariables];
                        
                        [statement addChunk:@"," line:assignmentToken.line column:assignmentToken.column];
                        declaration = [self parseSuffixedExpression:scope onlyDotColon:NO];
                        [statement addChild:declaration];
                        [declarations addObject:declaration];

                        assignmentToken = [self currentToken];
                    }
                    
                    if(![assignmentToken isAssignmentOperator]) {
                        [self addError:[NSString stringWithFormat:@"Expected '=' near: %@", [self tokenValue:assignmentToken]] range:assignmentToken.range line:assignmentToken.line column:assignmentToken.column];
                        [self skipLine];
                        break;
                    }
                    
                    [self consumeToken:LXTokenCompletionFlagsVariables];
                    [statement addChunk:@"=" line:assignmentToken.line column:assignmentToken.column];

                    NSInteger i = 0;
                    
                    do {
                        LXNode *matchingDeclaration = i < [declarations count] ? declarations[i] : nil;
                        
                        switch((NSInteger)assignmentToken.type) {
                            case LX_TK_PLUS_EQ: {
                                [statement addChild:matchingDeclaration];
                                [statement addChunk:@"+" line:assignmentToken.line column:assignmentToken.column];
                                break;
                            }
                            
                            case LX_TK_MINUS_EQ: {
                                [statement addChild:matchingDeclaration];
                                [statement addChunk:@"-" line:assignmentToken.line column:assignmentToken.column];
                                break;
                            }
                            
                            case LX_TK_MULT_EQ: {
                                [statement addChild:matchingDeclaration];
                                [statement addChunk:@"*" line:assignmentToken.line column:assignmentToken.column];
                                break;
                            }
                            
                            case LX_TK_DIV_EQ: {
                                [statement addChild:matchingDeclaration];
                                [statement addChunk:@"/" line:assignmentToken.line column:assignmentToken.column];
                                break;
                            }
                            
                            case LX_TK_POW_EQ: {
                                [statement addChild:matchingDeclaration];
                                [statement addChunk:@"^" line:assignmentToken.line column:assignmentToken.column];
                                break;
                            }
                            
                            case LX_TK_MOD_EQ: {
                                [statement addChild:matchingDeclaration];
                                [statement addChunk:@"%" line:assignmentToken.line column:assignmentToken.column];
                                break;
                            }
                            
                            case LX_TK_CONCAT_EQ: {
                                [statement addChild:matchingDeclaration];
                                [statement addChunk:@".." line:assignmentToken.line column:assignmentToken.column];
                                break;
                            }
                            
                            default:
                                break;
                        }
                        
                        [statement addChild:[self parseExpression:scope]];
                        
                        assignmentToken = [self currentToken];
                        
                        if(assignmentToken.type == ',') {
                            [self consumeToken:LXTokenCompletionFlagsVariables];
                            
                            [statement addChunk:@"," line:assignmentToken.line column:assignmentToken.column];
                        }
                        else {
                            break;
                        }
                        
                        ++i;
                    } while(YES);
                }
                else if(declaration.assignable) {
                    [self addError:[NSString stringWithFormat:@"Expected ',' or '=' near: %@", [self tokenValue:assignmentToken]] range:assignmentToken.range line:assignmentToken.line column:assignmentToken.column];
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
    
    LXNode *block = [[LXNode alloc] initWithLine:token.line column:token.endLine];
    
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