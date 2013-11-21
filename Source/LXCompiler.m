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
            NSString *path = [context.name stringByDeletingLastPathComponent];
            NSString *fileName = [[context.name lastPathComponent] stringByDeletingPathExtension];
            
            [[context.block toString] writeToFile:[NSString stringWithFormat:@"%@/%@.lua", path, fileName] atomically:YES encoding:NSUTF8StringEncoding error:nil];
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

- (LXScope *)scope {
    return self.block.scope;
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
    
    self.block = [self parseBlock:self.compiler.globalScope];
    
    LXLuaWriter *writer = [[LXLuaWriter alloc] init];
    [self.block compile:writer];
    
    NSString *generated = writer.string;
    NSArray *mappings = writer.mappings;
    
    NSString *output = @"";
    
    NSMutableArray *inputLines = [NSMutableArray arrayWithArray:[self.parser.string componentsSeparatedByString:@"\n"]];
    NSMutableArray *lines = [NSMutableArray arrayWithArray:[generated componentsSeparatedByString:@"\n"]];
    NSInteger lastGeneratedLine = 0;
    NSInteger lastGeneratedColumn = 0;
    NSInteger lastOriginalLine = 0;
    NSInteger lastOriginalColumn = 0;
    
    id lastMapping = nil;
    
    for(NSDictionary *dictionary in mappings) {
        NSInteger originalLine = [dictionary[@"original"][@"line"] integerValue];
        NSInteger originalColumn = [dictionary[@"original"][@"column"] integerValue];

        NSInteger generatedLine = [dictionary[@"generated"][@"line"] integerValue];
        NSInteger generatedColumn = [dictionary[@"generated"][@"column"] integerValue];
        
        if(lastMapping == nil) {
            while(lastGeneratedLine < generatedLine) {
                output = [output stringByAppendingFormat:@"{%@}", lines[0]];
                [lines removeObjectAtIndex:0];
                
                lastGeneratedLine++;
            }
            
            if(lastGeneratedColumn < generatedColumn) {
                NSString *nextLine = lines[0];
                output = [output stringByAppendingFormat:@"{%@}", [nextLine substringToIndex:generatedColumn]];
                lines[0] = [nextLine substringFromIndex:generatedColumn];
                lastGeneratedColumn = generatedColumn;
            }
        }
        else {
            if(lastGeneratedLine < generatedLine) {
                do {
                    output = [output stringByAppendingFormat:@"{%@}", lines[0]];
                    [lines removeObjectAtIndex:0];
                    
                    lastGeneratedLine++;
                    lastGeneratedColumn = 0;
                } while(lastGeneratedLine < generatedLine);
                
                if(lastGeneratedColumn < generatedColumn) {
                    NSString *nextLine = lines[0];
                    output = [output stringByAppendingFormat:@"{%@}", [nextLine substringToIndex:generatedColumn]];
                    lines[0] = [nextLine substringFromIndex:generatedColumn];
                    lastGeneratedColumn = generatedColumn;
                }
                
                //addMappingWithCode(lastMapping, code)
            }
            else {
                NSString *nextLine = lines[0];
                output = [output stringByAppendingFormat:@"{%@}", [nextLine substringToIndex:generatedColumn-lastGeneratedColumn]];
                lines[0] = [nextLine substringFromIndex:generatedColumn-lastGeneratedColumn];
                lastGeneratedColumn = generatedColumn;
                //addMappingWithCode(lastMapping, code)
            }
        }
        
        if(originalLine > lastOriginalLine) {
            while(lastOriginalLine < originalLine) {
                output = [output stringByAppendingFormat:@"(%@)", inputLines[lastOriginalLine++]];
            }
            
            lastOriginalColumn = 0;
        }
        
        if(originalLine == lastOriginalLine && originalColumn > lastOriginalColumn) {
            NSString *nextLine = inputLines[lastOriginalLine];
            output = [output stringByAppendingFormat:@"(%@)", [nextLine substringWithRange:NSMakeRange(lastOriginalColumn, originalColumn-lastOriginalColumn)]];
            lastOriginalColumn = originalColumn;
        }
        
        //NSLog(@"%d %d - %d %d", originalLine, lastOriginalLine, originalColumn, lastOriginalColumn);
        
        lastMapping = [NSNull null];
        lastOriginalLine = originalLine;
        lastOriginalColumn = originalColumn;
    }
    
    NSLog(@"%@", output);
    
    //NSLog(@"%@", [writer string]);
    //NSLog(@"%@", [writer mappings]);
    //NSLog(@"Generate: %@", [writer generate]);
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
        if(*index >= [self.parser.tokens count]) {
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
    return [self.parser.string substringWithRange:token.range];
}

- (LXNode *)parseSimpleExpression:(LXScope *)scope {
    LXToken *token = [self currentToken];
    
    if([self consumeToken:LX_TK_NUMBER]) {
        LXNodeNumberExpression *numberExpression = [[LXNodeNumberExpression alloc] initWithLine:token.startLine column:token.column];
        
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        [formatter setNumberStyle:NSNumberFormatterNoStyle];
        numberExpression.value = [formatter numberFromString:[self tokenValue:token]];
        
        return numberExpression;
    }
    else if([self consumeToken:LX_TK_STRING]) {
        LXNodeStringExpression *stringExpression = [[LXNodeStringExpression alloc] initWithLine:token.startLine column:token.column];
        stringExpression.value = [self tokenValue:token];
        
        return stringExpression;
    }
    else if([self consumeToken:LX_TK_NIL]) {
        return [[LXNodeNilExpression alloc] initWithLine:token.startLine column:token.column];
    }
    else if([self consumeToken:LX_TK_TRUE]) {
        LXNodeBoolExpression *boolExpression = [[LXNodeBoolExpression alloc] initWithLine:token.startLine column:token.column];
        boolExpression.value = YES;
        
        return boolExpression;
    }
    else if([self consumeToken:LX_TK_FALSE]) {
        LXNodeBoolExpression *boolExpression = [[LXNodeBoolExpression alloc] initWithLine:token.startLine column:token.column];
        boolExpression.value = NO;
        
        return boolExpression;
    }
    else if([self consumeToken:LX_TK_DOTS]) {
        return [[LXNodeVarArgExpression alloc] initWithLine:token.startLine column:token.column];
    }
    else if([self consumeToken:'{']) {
        LXNodeTableConstructorExpression *tableConstructor = [[LXNodeTableConstructorExpression alloc] initWithLine:token.startLine column:token.column];
        
        NSMutableArray *keyValuePairs = [NSMutableArray array];
        
        while(YES) {
            token = [self currentToken];
            
            if([self consumeToken:'[']) {
                LXNode *key = [self parseExpression:scope];
                
                if(!key) {
                    [self matchToken:'['];
                }
                else if(![self consumeToken:']']) {
                    LXToken *token = [self currentToken];
                    
                    [self addError:[NSString stringWithFormat:@"Expected ']' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
                }
                
                if(![self consumeToken:'=']) {
                    LXToken *token = [self currentToken];
                    
                    [self addError:[NSString stringWithFormat:@"Expected '=' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
                }
                
                LXNode *value = [self parseExpression:scope];
                
                if(!value) {
                    
                }
                
                LXKeyValuePair *kvp = [[LXKeyValuePair alloc] init];
                kvp.key = key;
                kvp.value = value;
                kvp.isBoxed = YES;
                [keyValuePairs addObject:kvp];
            }
            else if(token.type == LX_TK_NAME) {
                LXToken *next = [self nextToken];
                
                LXNode *key = nil;
                
                if(next.type == '=') {
                    LXNodeVariableExpression *expression = [[LXNodeVariableExpression alloc] initWithLine:token.startLine column:token.column];
                    expression.variable = [self tokenValue:[self consumeToken]];
                    key = expression;
                    
                    [self consumeToken:'='];
                }
                
                LXNode *value = [self parseExpression:scope];
                
                if(!value) {
                    
                }
                
                LXKeyValuePair *kvp = [[LXKeyValuePair alloc] init];
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
                
                LXKeyValuePair *kvp = [[LXKeyValuePair alloc] init];
                kvp.value = value;
                [keyValuePairs addObject:kvp];
            }
            
            if([self consumeToken:';'] || [self consumeToken:',']) {
            }
            else if([self consumeToken:'}']) {
                break;
            }
            else {
                LXToken *token = [self currentToken];
                
                [self addError:[NSString stringWithFormat:@"Expected ';', ',' or '}' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
                
                [self matchToken:'{'];
            }
        }
        
        tableConstructor.keyValuePairs = keyValuePairs;
        
        return tableConstructor;
    }
    else if([self currentToken].type == LX_TK_FUNCTION) {
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
                LXToken *token = [self currentToken];
                
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
                
                expression = nil;
            }
            else {
                LXNodeMemberExpression *memberExpression = [[LXNodeMemberExpression alloc] initWithLine:token.startLine column:token.column];
                
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
                LXNodeIndexExpression *indexExpression = [[LXNodeIndexExpression alloc] initWithLine:token.startLine column:token.column];
                indexExpression.base = expression;
                indexExpression.index = index;
                
                if(![self consumeToken:']']) {
                    LXToken *token = [self currentToken];
                    
                    [self addError:[NSString stringWithFormat:@"Expected ']' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
                }
                
                expression = indexExpression;
            }
        }
        else if(!onlyDotColon && [self consumeToken:'(']) {
            LXNodeCallExpression *callExpression = [[LXNodeCallExpression alloc] initWithLine:token.startLine column:token.column];
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
                        LXToken *token = [self currentToken];
                        
                        [self addError:[NSString stringWithFormat:@"Expected ')' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
                    }
                    
                    break;
                }
            }
            
            callExpression.arguments = arguments;
            
            expression = callExpression;
        }
        else if(!onlyDotColon && [self currentToken].type == LX_TK_STRING) {
            LXNodeStringCallExpression *stringCallExpression = [[LXNodeStringCallExpression alloc] initWithLine:token.startLine column:token.column];
            
            stringCallExpression.base = expression;
            stringCallExpression.value = [self tokenValue:[self consumeToken]];
            expression = stringCallExpression;
        }
        else if(!onlyDotColon && [self currentToken].type == '{') {
            LXNodeTableCallExpression *tableCallExpression = [[LXNodeTableCallExpression alloc] initWithLine:token.startLine column:token.column];
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
            LXToken *token = [self currentToken];
            
            [self addError:[NSString stringWithFormat:@"Expected ')' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
        }
        
        //[expression setParenCount:+1];
        
        return expression;
    }
    else if([self consumeToken:LX_TK_NAME]) {
        NSString *identifier = [self tokenValue:token];
        LXNodeVariableExpression *variableExpression = [[LXNodeVariableExpression alloc] initWithLine:token.startLine column:token.column];
        variableExpression.variable = identifier;
        
        LXVariable *local = [scope variable:identifier];
        
        if(local) {
            //variableExpression.local = YES;
        }
        else {
            local = [self.compiler.globalScope createVariable:identifier type:nil];
            [definedVariables addObject:local];
        }
        
        token.variable = local;
        variableExpression.scriptVariable = local;
        
        return variableExpression;
    }
    else {
        LXToken *token = [self currentToken];
        
        [self addError:[NSString stringWithFormat:@"Expected 'name' or '(expression)' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
        
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
            LXNodeUnaryOpExpression *unaryOpExpression = [[LXNodeUnaryOpExpression alloc] initWithLine:unaryOp.startLine column:unaryOp.column];
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
                    LXNodeBinaryOpExpression *binaryOpExpression = [[LXNodeBinaryOpExpression alloc] initWithLine:binaryOp.startLine column:binaryOp.column];
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
    LXToken *token = [self consumeToken];
    
    LXNodeFunctionExpression *functionStatement = [[LXNodeFunctionExpression alloc] initWithLine:token.startLine column:token.column];
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
                               LXToken *token = [self currentToken];
                               
                               [self addError:[NSString stringWithFormat:@"Expected ')' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
                           }
                           
                           break;
                       }
                   }
                   else if([self consumeToken:LX_TK_DOTS]) {
                       //isVarArg = YES;
                       
                       if(![self consumeToken:')']) {
                           LXToken *token = [self currentToken];
                           
                           [self addError:[NSString stringWithFormat:@"Expected ')' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
                       }
                       
                       break;
                   }
                   else {
                       LXToken *token = [self currentToken];
                       
                       [self addError:[NSString stringWithFormat:@"Expected 'type' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
                       
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
            LXNodeVariableExpression *variableExpression = [[LXNodeVariableExpression alloc] initWithLine:token.startLine column:token.column];
            variableExpression.variable = identifier;
            
            LXVariable *local = nil;
            
            if(isLocal) {
                local = [scope localVariable:identifier];
                
                if(local) {
                    //ERROR
                }
                else {
                    local = [scope createVariable:identifier type:[self findType:@"Function"]];
                }
            }
            else {
                local = [self.compiler.globalScope createVariable:identifier type:[self findType:@"Function"]];
            }
            
            [definedVariables addObject:local];

            token.variable = local;
            variableExpression.scriptVariable = local;
            
            LXNodeExpression *expression = variableExpression;
            
            LXToken *token = [self currentToken];
            
            while([self consumeToken:'.'] ||
                  [self consumeToken:':']) {
                if([self currentToken].type != LX_TK_NAME) {
                    LXToken *token = [self currentToken];
                    
                    [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
                    
                    expression = nil;
                }
                else {
                    LXNodeMemberExpression *memberExpression = [[LXNodeMemberExpression alloc] initWithLine:token.startLine column:token.column];
                    
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
            LXToken *token = [self currentToken];
            
            [self addError:[NSString stringWithFormat:@"Expected '(' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
        }
    }
    else {
        if(checkingReturnType && hasReturnType) {
            if(![self consumeToken:'(']) {
                if([returnTypes count] == 0) {
                    hasEmptyReturnType = YES;
                }
                else {
                    LXToken *token = [self currentToken];
                    
                    [self addError:[NSString stringWithFormat:@"Expected '(' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
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
                LXToken *token = [self currentToken];
                
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
            }
            else {
                NSString *identifier = [self tokenValue:[self consumeToken]];
                
                LXVariable *variable = [functionScope createVariable:identifier type:[self findType:type]];
                token.variable = variable;
                
                [arguments addObject:variable];
            }
            
            if(![self consumeToken:',']) {
                if(![self consumeToken:')']) {
                    LXToken *token = [self currentToken];
                    
                    [self addError:[NSString stringWithFormat:@"Expected ')' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
                }
                
                break;
            }
        }
        else if([self consumeToken:LX_TK_DOTS]) {
            isVarArg = YES;
            
            if(![self consumeToken:')']) {
                LXToken *token = [self currentToken];
                
                [self addError:[NSString stringWithFormat:@"Expected ')' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
            }
            
            break;
        }
        else {
            LXToken *token = [self currentToken];
            
            [self addError:[NSString stringWithFormat:@"Expected 'type' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
            
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
        LXToken *token = [self currentToken];
        
        [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
    }
    
    return functionStatement;
}

- (LXNodeClassStatement *)parseClassStatement:(LXScope *)scope {
    LXToken *token = [self consumeToken];
    
    NSMutableArray *functions = [NSMutableArray array];
    NSMutableArray *variables = [NSMutableArray array];
    NSMutableArray *variableDeclarations = [NSMutableArray array];
    
    NSMutableArray *functionIndices = [NSMutableArray array];
    
    LXNodeClassStatement *classStatement = [[LXNodeClassStatement alloc] initWithLine:token.startLine column:token.column];
    
    if([self currentToken].type != LX_TK_NAME) {
        LXToken *token = [self currentToken];
        
        [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
    }
    else {
        classStatement.name = [self tokenValue:[self consumeToken]];
    }
    
    if([self consumeToken:LX_TK_EXTENDS]) {
        if(![[self currentToken] isType]) {
            LXToken *token = [self currentToken];
            
            [self addError:[NSString stringWithFormat:@"Expected 'name' or 'type' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
        }
        else {
            classStatement.superclass = [self tokenValue:[self consumeToken]];
        }
    }
    
    LXScope *classScope = [self pushScope:scope openScope:YES];
    classScope.type = LXScopeTypeClass;
    
    LXVariable *variable = [classScope createVariable:@"self" type:[self findType:classStatement.name]];
    [variables addObject:variable];
    
    if(classStatement.superclass) {
        LXVariable *variable = [classScope createVariable:@"super" type:[self findType:classStatement.superclass]];
        variable.isMember = YES;
        [variables addObject:variable];
    }
    
    while([self currentToken].type != LX_TK_END) {
        if([self currentToken].type == LX_TK_FUNCTION) {
            [functionIndices addObject:@(currentTokenIndex)];
            
            [self consumeToken];
            [self closeBlock:LX_TK_FUNCTION];
        }
        else if([[self currentToken] isType]) {
            LXToken *typeToken = [self currentToken];
            NSString *type = [self tokenValue:[self consumeToken]];
            LXClass *variableType = [self findType:type];
            typeToken.variableType = variableType;
            
            LXNodeDeclarationStatement *declarationStatement = [[LXNodeDeclarationStatement alloc] initWithLine:typeToken.startLine column:typeToken.endLine];

            if([self currentToken].type != LX_TK_NAME) {
                LXToken *token = [self currentToken];
                
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
            }
            else {
                
            }
            
            LXToken *currentToken = [self currentToken];
            
            NSString *var = [self tokenValue:[self consumeToken]];
            
            LXVariable *variable = [classScope createVariable:var type:[self findType:type]];
            variable.isMember = YES;
            
            currentToken.variable = variable;
            [variables addObject:variable];
            
            NSMutableArray *varList = [NSMutableArray arrayWithObject:variable];
            NSMutableArray *initList = [NSMutableArray array];
            
            while([self consumeToken:',']) {
                if([self currentToken].type != LX_TK_NAME) {
                    LXToken *token = [self currentToken];
                    
                    [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
                }
                
                LXToken *currentToken = [self currentToken];
                
                var = [self tokenValue:[self consumeToken]];
                
                LXVariable *variable = [classScope createVariable:var type:[self findType:type]];
                variable.isMember = YES;
                
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
            LXToken *token = [self currentToken];
            
            [self addError:[NSString stringWithFormat:@"Expected function or variable declaration near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
            
            [self matchToken:LX_TK_CLASS];
            break;
        }
        
        if([self currentToken].type == LX_TK_END) {
            NSInteger endIndex = currentTokenIndex;
            
            for(NSNumber *index in functionIndices) {
                currentTokenIndex = index.integerValue;
                
                LXToken *token = [self currentToken];
                
                LXNodeFunctionExpression *functionExpression = [self parseFunction:classScope anonymous:NO isLocal:YES];
                
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
                
                LXNodeFunctionStatement *functionStatement = [[LXNodeFunctionStatement alloc] initWithLine:token.startLine column:token.endLine];
                functionStatement.expression = functionExpression;
                
                //functionStatement.isLocal = YES;
                [functions addObject:functionStatement];
            }
            
            currentTokenIndex = endIndex;
        }
    }
    
    [self popScope];
    
    if(![self consumeToken:LX_TK_END]) {
        LXToken *token = [self currentToken];
        
        [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
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
    
    if([self currentToken].type == LX_TK_IF) {
        LXToken *token = [self consumeToken];
        
        LXNodeIfStatement *ifStatement = [[LXNodeIfStatement alloc] initWithLine:token.startLine column:token.endLine];
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
            LXToken *token = [self currentToken];
            
            [self addError:[NSString stringWithFormat:@"Expected 'then' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
        }
        
        ifStatement.body = [self parseBlock:scope];
        
        NSMutableArray *elseIfStatements = [NSMutableArray array];
        
        while([self currentToken].type == LX_TK_ELSEIF) {
            LXToken *token = [self consumeToken];
            
            LXNodeElseIfStatement *elseIfStatement = [[LXNodeElseIfStatement alloc] initWithLine:token.startLine column:token.endLine];
            elseIfStatement.condition = [self parseExpression:scope];
            
            if(elseIfStatement.condition == nil) {
            }
            
            if(![self consumeToken:LX_TK_THEN]) {
                LXToken *token = [self currentToken];
                
                [self addError:[NSString stringWithFormat:@"Expected 'then' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
            }
            
            elseIfStatement.body = [self parseBlock:scope];
            [elseIfStatements addObject:elseIfStatement];
        }
        
        ifStatement.elseIfStatements = elseIfStatements;
        
        if([self consumeToken:LX_TK_ELSE]) {
            ifStatement.elseStatement = [self parseBlock:scope];
        }
        
        if(![self consumeToken:LX_TK_END]) {
            LXToken *token = [self currentToken];
            
            [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
        }
        
        return ifStatement;
    }
    else if([self currentToken].type == LX_TK_WHILE) {
        LXToken *token = [self consumeToken];
        
        LXNodeWhileStatement *whileStatement = [[LXNodeWhileStatement alloc] initWithLine:token.startLine column:token.endLine];
        whileStatement.condition = [self parseExpression:scope];
        
        if(whileStatement.condition == nil) {
            
        }
        
        if(![self consumeToken:LX_TK_DO]) {
            LXToken *token = [self currentToken];
            
            [self addError:[NSString stringWithFormat:@"Expected 'do' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
        }
        
        whileStatement.body = [self parseBlock:scope];
        
        if(![self consumeToken:LX_TK_END]) {
            LXToken *token = [self currentToken];
            
            [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
        }
        
        return whileStatement;
    }
    else if([self currentToken].type == LX_TK_DO) {
        LXToken *token = [self consumeToken];
        
        LXNodeDoStatement *doStatement = [[LXNodeDoStatement alloc] initWithLine:token.startLine column:token.endLine];
        
        doStatement.body = [self parseBlock:scope];
        
        if(![self consumeToken:LX_TK_END]) {
            LXToken *token = [self currentToken];
            
            [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
        }
        
        return doStatement;
    }
    else if([self currentToken].type == LX_TK_FOR) {
        LXToken *token = [self consumeToken];

        if(![[self currentToken] isType]) {
            LXToken *token = [self currentToken];
            
            [self addError:[NSString stringWithFormat:@"Expected 'name' or 'type' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
        }
        
        if([self nextToken].type == '=') {
            LXNodeNumericForStatement *forStatement = [[LXNodeNumericForStatement alloc] initWithLine:token.startLine column:token.endLine];
            
            LXScope *forScope = [self pushScope:scope openScope:NO];
            
            LXToken *variableToken = [self currentToken];
            NSString *var = [self tokenValue:[self consumeToken]];
            
            LXClass *variableType = [self findType:@"Number"];
            LXVariable *variable = [forScope createVariable:var type:variableType];
            
            variableToken.variable = variable;

            forStatement.variable = variable;
            
            [self consumeToken];

            forStatement.startExpression = [self parseExpression:scope];
            
            if(![self consumeToken:',']) {
                LXToken *token = [self currentToken];
                
                [self addError:[NSString stringWithFormat:@"Expected ',' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
            }
            
            forStatement.endExpression = [self parseExpression:scope];
            
            if([self consumeToken:',']) {
                forStatement.stepExpression = [self parseExpression:scope];
            }
            
            if(![self consumeToken:LX_TK_DO]) {
                LXToken *token = [self currentToken];
                
                [self addError:[NSString stringWithFormat:@"Expected 'do' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
            }
            
            forStatement.body = [self parseBlock:forScope];
            
            [self popScope];
            
            if(![self consumeToken:LX_TK_END]) {
                LXToken *token = [self currentToken];
                
                [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
            }
            
            return forStatement;
        }
        else {
            LXToken *typeToken = [self currentToken];
            NSString *type = [self tokenValue:[self consumeToken]];
            
            if([self currentToken].type != LX_TK_NAME) {
                LXToken *token = [self currentToken];
                
                [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
            }
            
            LXToken *variableToken = [self currentToken];
            NSString *var = [self tokenValue:[self consumeToken]];
            
            LXNodeGenericForStatement *forStatement = [[LXNodeGenericForStatement alloc] initWithLine:token.startLine column:token.endLine];
            
            LXScope *forScope = [self pushScope:scope openScope:NO];
            
            LXClass *variableType = [self findType:type];
            LXVariable *variable = [forScope createVariable:var type:variableType];

            typeToken.variableType = variableType;
            variableToken.variable = variable;
            
            NSMutableArray *varList = [NSMutableArray arrayWithObject:variable];
            
            while([self consumeToken:',']) {
                if(![[self currentToken] isType]) {
                    LXToken *token = [self currentToken];
                    
                    [self addError:[NSString stringWithFormat:@"Expected 'name' or 'type' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
                }
                else {
                    if([self nextToken].type == LX_TK_NAME) {
                        LXToken *typeToken = [self currentToken];
                        NSString *type = [self tokenValue:[self consumeToken]];
                        
                        LXToken *variableToken = [self currentToken];
                        NSString *var = [self tokenValue:[self consumeToken]];
                        
                        LXClass *variableType = [self findType:type];
                        LXVariable *variable = [forScope createVariable:var type:variableType];
                        
                        typeToken.variableType = variableType;
                        variableToken.variable = variable;
                        
                        [varList addObject:variable];
                    }
                    else {
                        LXToken *currentToken = [self currentToken];
                        NSString *var = [self tokenValue:[self consumeToken]];
                        
                        LXVariable *variable = [forScope createVariable:var type:variableType];
                        currentToken.variable = variable;
                        [varList addObject:variable];
                    }
                }
            }
            
            forStatement.variableList = varList;
            
            if(![self consumeToken:LX_TK_IN]) {
                LXToken *token = [self currentToken];
                
                [self addError:[NSString stringWithFormat:@"Expected 'in' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
            }
            
            NSMutableArray *generators = [NSMutableArray array];
            
            do {
                LXNode *generator = [self parseExpression:scope];
                [generators addObject:generator];
            } while([self consumeToken:',']);
            
            forStatement.generators = generators;
            
            if(![self consumeToken:LX_TK_DO]) {
                LXToken *token = [self currentToken];
                
                [self addError:[NSString stringWithFormat:@"Expected 'do' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
            }
            
            forStatement.body = [self parseBlock:forScope];
            
            [self popScope];
            
            if(![self consumeToken:LX_TK_END]) {
                LXToken *token = [self currentToken];
                
                [self addError:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
            }
            
            return forStatement;
        }
    }
    else if([self currentToken].type == LX_TK_REPEAT) {
        LXToken *token = [self consumeToken];
        
        LXNodeRepeatStatement *repeatStatement = [[LXNodeRepeatStatement alloc] initWithLine:token.startLine column:token.endLine];
        
        repeatStatement.body = [self parseBlock:scope];
        
        if(![self consumeToken:LX_TK_UNTIL]) {
            LXToken *token = [self currentToken];
            
            [self addError:[NSString stringWithFormat:@"Expected 'until' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
        }
        
        repeatStatement.condition = [self parseExpression:scope];
        
        return repeatStatement;
    }
    else if([self currentToken].type == LX_TK_FUNCTION) {
        LXToken *token = [self currentToken];
        
        LXNodeFunctionExpression *functionExpression = [self parseFunction:scope anonymous:NO isLocal:isLocal];
        LXNodeFunctionStatement *functionStatement = [[LXNodeFunctionStatement alloc] initWithLine:token.startLine column:token.endLine];
        functionStatement.expression = functionExpression;
        functionStatement.isLocal = isLocal && [functionExpression.name class] == [LXNodeVariableExpression class]; //Hacky
        
        return functionStatement;
    }
    else if([self currentToken].type == LX_TK_CLASS) {
        LXNodeClassStatement *classStatement = [self parseClassStatement:scope];
        classStatement.isLocal = isLocal;
        
        return classStatement;
    }
    else if([self currentToken].type == LX_TK_DBCOLON) {
        LXToken *token = [self consumeToken];
        
        LXNodeLabelStatement *labelStatement = [[LXNodeLabelStatement alloc] initWithLine:token.startLine column:token.endLine];
        
        if([self currentToken].type != LX_TK_NAME) {
            LXToken *token = [self currentToken];
            
            [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
        }
        else {
            labelStatement.label = [self tokenValue:[self currentToken]];
        }
        
        if(![self consumeToken:LX_TK_DBCOLON]) {
            LXToken *token = [self currentToken];
            
            [self addError:[NSString stringWithFormat:@"Expected '::' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
        }
        
        return labelStatement;
    }
    else if([self currentToken].type == LX_TK_RETURN) {
        LXToken *token = [self consumeToken];
        
        LXNodeReturnStatement *returnStatement = [[LXNodeReturnStatement alloc] initWithLine:token.startLine column:token.endLine];
        
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
    else if([self currentToken].type == LX_TK_BREAK) {
        LXToken *token = [self consumeToken];

        LXNodeBreakStatement *breakStatement = [[LXNodeBreakStatement alloc] initWithLine:token.startLine column:token.endLine];
        
        return breakStatement;
    }
    else if([self currentToken].type == LX_TK_GOTO) {
        LXToken *token = [self consumeToken];

        LXNodeGotoStatement *gotoStatement = [[LXNodeGotoStatement alloc] initWithLine:token.startLine column:token.endLine];
        
        if([self currentToken].type != LX_TK_NAME) {
            LXToken *token = [self currentToken];
            
            [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
        }
        else {
            gotoStatement.label = [self tokenValue:[self currentToken]];
        }
        
        return gotoStatement;
    }
    else if([self currentToken].type == ';') {
        LXToken *token = [self consumeToken];

        LXNodeEmptyStatement *emptyStatement = [[LXNodeEmptyStatement alloc] initWithLine:token.startLine column:token.endLine];
        
        return emptyStatement;
    }
    else {
        if([[self currentToken] isType] && [self nextToken].type == LX_TK_NAME && [self currentToken].startLine == [self nextToken].endLine) {
            LXToken *typeToken = [self currentToken];
            NSString *type = [self tokenValue:[self consumeToken]];
            
            LXToken *variableToken = [self currentToken];
            NSString *var = [self tokenValue:[self consumeToken]];
            
            LXVariable *variable = nil;
            LXClass *variableType = [self findType:type];
            
            LXNodeDeclarationStatement *declarationStatement = [[LXNodeDeclarationStatement alloc] initWithLine:typeToken.startLine column:typeToken.endLine];

            if(isLocal) {
                variable = [scope localVariable:var];
                
                if(variable) {
                    [self addError:[NSString stringWithFormat:@"Variable %@ is already defined.", var] range:variableToken.range line:variableToken.startLine column:variableToken.column];
                }
                else {
                    variable = [scope createVariable:var type:variableType];
                }
            }
            else {
                variable = [self.compiler.globalScope localVariable:var];
                
                if(variable) {
                    if(variable.isDefined) {
                        [self addError:[NSString stringWithFormat:@"Variable %@ is already defined.", var] range:variableToken.range line:variableToken.startLine column:variableToken.column];
                    }
                    else {
                        variable.type = variableType;
                    }
                }
                else {
                    variable = [self.compiler.globalScope createVariable:var type:variableType];
                    [definedVariables addObject:variable];
                }
            }
            
            typeToken.variableType = variableType;
            variableToken.variable = variable;
            
            LXNodeVariableExpression *variableExpression = [[LXNodeVariableExpression alloc] initWithLine:variableToken.startLine column:variableToken.column];
            variableExpression.variable = variable.name;
            
            NSMutableArray *varList = [NSMutableArray arrayWithObject:variableExpression];
            NSMutableArray *initList = [NSMutableArray array];
            
            while([self consumeToken:',']) {
                if([self currentToken].type != LX_TK_NAME) {
                    LXToken *token = [self currentToken];
                    
                    [self addError:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
                }
                else {
                    variableToken = [self currentToken];
                    var = [self tokenValue:[self consumeToken]];
                    
                    variable = nil;
                    
                    if(isLocal) {
                        variable = [scope localVariable:var];
                        
                        if(variable) {
                            [self addError:[NSString stringWithFormat:@"Variable %@ is already defined.", var] range:variableToken.range line:variableToken.startLine column:variableToken.column];
                        }
                        else {
                            variable = [scope createVariable:var type:[self findType:type]];
                        }
                    }
                    else {
                        variable = [self.compiler.globalScope localVariable:var];
                        
                        if(variable) {
                            if(variable.isDefined) {
                                [self addError:[NSString stringWithFormat:@"Variable %@ is already defined.", var] range:variableToken.range line:variableToken.startLine column:variableToken.column];
                            }
                            else {
                                variable.type = [self findType:type];
                            }
                        }
                        else {
                            variable = [self.compiler.globalScope createVariable:var type:[self findType:type]];
                            [definedVariables addObject:variable];
                        }
                    }
                    
                    variableToken.variable = variable;
                    variableExpression = [[LXNodeVariableExpression alloc] initWithLine:variableToken.startLine column:variableToken.column];
                    variableExpression.variable = variable.name;

                    [varList addObject:variableExpression];
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
            LXToken *token = [self currentToken];
            LXNode *expression = [self parseSuffixedExpression:scope onlyDotColon:NO];

            if(expression && ([self currentToken].type == ',' || [[self currentToken] isAssignmentOperator])) {
                LXToken *token = [self currentToken];
                
                LXNodeAssignmentStatement *assignmentStatement = [[LXNodeAssignmentStatement alloc] initWithLine:token.startLine column:token.endLine];
                NSMutableArray *varList = [NSMutableArray arrayWithObject:expression];
                NSMutableArray *initList = [NSMutableArray array];
                
                while([self consumeToken:',']) {
                    LXNode *expression = [self parseSuffixedExpression:scope onlyDotColon:NO];
                    
                    if(expression != nil)
                    [varList addObject:expression];
                }
                
                if(![[self currentToken] isAssignmentOperator]) {
                    LXToken *token = [self currentToken];
                    
                    [self addError:[NSString stringWithFormat:@"Expected '=' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
                }
                
                LXToken *assignmentOp = [self consumeToken];
                
                do {
                    LXNode *expression = [self parseExpression:scope];
                    
                    if(expression)
                        [initList addObject:expression];
                } while([self consumeToken:',']);
                
                assignmentStatement.variables = varList;
                assignmentStatement.initializers = initList;
                assignmentStatement.op = [self tokenValue:assignmentOp];
                
                return assignmentStatement;
            }
            else {
                if(!expression) {
                    [self skipLine];
                }
                
                if(expression && ![expression isKindOfClass:[LXNodeCallExpression class]] &&
                   ![expression isKindOfClass:[LXNodeTableCallExpression class]] &&
                   ![expression isKindOfClass:[LXNodeStringCallExpression class]]) {
                    LXToken *token = [self currentToken];
                    
                    [self addError:[NSString stringWithFormat:@"Expected 'call expression' near: %@", [self tokenValue:token]] range:token.range line:token.startLine column:token.column];
                }
                
                LXNodeExpressionStatement *expressionStatement = [[LXNodeExpressionStatement alloc] initWithLine:token.startLine column:token.endLine];
                
                expressionStatement.expression = expression;
                return expressionStatement;
            }
        }
    }
}

- (LXNodeBlock *)parseBlock:(LXScope *)scope {
    LXToken *token = [self currentToken];
    NSDictionary *closeKeywords = @{@(LX_TK_END) : @YES, @(LX_TK_ELSE) : @YES, @(LX_TK_ELSEIF) : @YES, @(LX_TK_UNTIL) : @YES};
    
    LXNodeBlock *block = [[LXNodeBlock alloc] initWithLine:token.startLine column:token.endLine];
    
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