//
//  LXCompiler.m
//  LuaX
//
//  Created by Noah Hilt on 8/8/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXCompiler.h"
#import "LXToken.h"

@interface LXCompiler() {
    NSInteger currentPosition;
    NSInteger currentLine;
    NSInteger currentColumn;
    NSInteger currentTokenIndex;
    NSMutableArray *scopeStack;
    NSMutableArray *errors;
}

@end

@implementation LXCompiler

- (id)init {
    if(self = [super init]) {
        _tokens = [[NSMutableArray alloc] init];
        _baseTypeMap = [[NSMutableDictionary alloc] init];
        _typeMap = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}

- (void)compile:(NSString *)string {
    self.string = string;

    currentPosition = 0;
    currentLine = 0;
    currentColumn = 0;
    currentTokenIndex = 0;
    
    [_tokens removeAllObjects];
    [_typeMap removeAllObjects];
    
    LXToken *token = [self scanNextToken];
    
    while(token.type != LX_TK_EOS) {
        [self.tokens addObject:token];
        
        token = [self scanNextToken];
    }
    
    self.globalScope = [self pushScope:nil openScope:NO];
    LXNode *block = [self parseBlock:self.globalScope];
    [self popScope];
    
    NSLog(@"%@", [block toString]);
}

//

- (char)current {
    if(currentPosition >= [self.string length])
        return '\0';
    
    return [self.string characterAtIndex:currentPosition];
}

- (BOOL)isDigit:(char)ch {
    return ch >= '0' && ch <= '9';
}

- (BOOL)isAlphaNumeric:(char)ch {
    return ch == '_' || (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || [self isDigit:ch];
}

- (void)next {
    if(currentPosition < [self.string length]) {
        currentPosition++;
        currentColumn++;
    }
}

- (BOOL)checkNext:(NSString *)set {
    if([self current] == '\0' ||
       [set rangeOfString:[NSString stringWithFormat:@"%c", [self current]]].location == NSNotFound)
        return NO;
    
    [self next];
    return YES;
}

- (BOOL)currentIsNewLine {
    char ch = [self current];
    
    return ch == '\n' || ch == '\r';
}

- (void)increaseLineNumber {
    char old = [self current];
    
    [self next];
    
    if([self currentIsNewLine] && old != [self current])
        [self next];
    
    currentLine++;
    currentColumn = 0;
}

- (NSInteger)skipSeparator {
    NSInteger count = 0;
    char s = [self current];
    
    [self next];
    
    while([self current] == '=') {
        [self next];
        ++count;
    }
    
    return [self current] == s ? count : (-count) - 1;
}

- (void)readLongString:(NSInteger)separator {
    [self next];
    
    if([self currentIsNewLine])
        [self increaseLineNumber];
    
    BOOL loop = YES;
    while(loop) {
        switch([self current]) {
            case '\0':
                loop = NO;
                break;
            case ']': {
                if([self skipSeparator] == separator) {
                    [self next];
                    loop = NO;
                }
                break;
            }
            case '\n':
            case '\r': {
                [self increaseLineNumber];
                break;
            }
            default: {
                [self next];
            }
        }
    }
}

- (void)readHex {
    for(int i = 0; i < 2; ++i) {
        [self next];
        //Check if actually hex?
    }
}

- (void)readDecimalEscape {
    for(int i = 0; i < 3 && [self isDigit:[self current]]; ++i) {
        [self next];
    }
}

- (void)readString:(char)delimiter {
    [self next];
    
    BOOL loop = YES;
    while(loop && [self current] != delimiter) {
        switch([self current]) {
            case '\0':
            case '\n':
            case '\r':
                loop = NO;
                break;
            case '\\': {
                [self next];
                switch([self current]) {
                    case 'a': goto read_save;
                    case 'b': goto read_save;
                    case 'f': goto read_save;
                    case 'n': goto read_save;
                    case 'r': goto read_save;
                    case 't': goto read_save;
                    case 'v': goto read_save;
                    case 'x': [self readHex]; goto read_save;
                    case '\n': case '\r':
                        [self increaseLineNumber]; goto no_save;
                    case '\\': case '\"': case '\'':
                        goto read_save;
                    case '\0': goto no_save;  /* will raise an error next loop */
                    case 'z': {  /* zap following span of spaces */
                        [self next];  /* skip the 'z' */
                        while([self current] == ' ') {
                            if([self currentIsNewLine]) [self increaseLineNumber];
                            else [self next];
                        }
                        goto no_save;
                    }
                    default: {
                        if(![self isDigit:[self current]]) {
                            goto no_save;
                        }
                        
                        [self readDecimalEscape];
                        goto no_save;
                    }
                }
            read_save: [self next];
            no_save: break;
            }
            default:
                [self next];
        }
    }
    
    [self next];
}

- (void)readNumeral {
    do {
        [self next];
        if([self checkNext:@"EePp"])
            [self checkNext:@"+-"];
    } while([self isDigit:[self current]] || [self current] == '.');
}

- (LXToken *)tokenWithType:(LXTokenType)type position:(NSInteger)startPosition line:(NSInteger)startLine column:(NSInteger)column {
    LXToken *token = [[LXToken alloc] init];
    
    token.type = type;
    token.range = NSMakeRange(startPosition, currentPosition-startPosition);
    token.startLine = startLine;
    token.endLine = currentLine;
    token.column = column;
    
    return [token autorelease];
}

- (LXToken *)scanNextToken {
    for(;;) {
        NSInteger startPosition = currentPosition;
        NSInteger startLine = currentLine;
        NSInteger startColumn = currentColumn;
        
        switch([self current]) {
            case '\n': case '\r': {  /* line breaks */
                [self increaseLineNumber];
                break;
            }
            case ' ': case '\f': case '\t': case '\v': {  /* spaces */
                [self next];
                break;
            }
            case '-': {  /* '-' or '--' (comment) */
                [self next];
                if([self current] != '-')
                    return [self tokenWithType:'-' position:startPosition line:startLine column:startColumn];
                /* else is a comment */
                [self next];
                if([self current] == '[') {  /* long comment? */
                    NSInteger sep = [self skipSeparator];
                    
                    if(sep >= 0) {
                        [self readLongString:sep];
                        return [self tokenWithType:LX_TK_LONGCOMMENT position:startPosition line:startLine column:startColumn];
                        break;
                    }
                }
                /* else short comment */
                while(![self currentIsNewLine] && [self current] != '\0')
                    [self next];  /* skip until end of line (or end of file) */
                
                return [self tokenWithType:LX_TK_COMMENT position:startPosition line:startLine column:startColumn];
                break;
            }
            case '[': {  /* long string or simply '[' */
                NSInteger sep = [self skipSeparator];
                if(sep >= 0) {
                    [self readLongString:sep];
                    return [self tokenWithType:LX_TK_STRING position:startPosition line:startLine column:startColumn];
                }
                else if (sep == -1) return [self tokenWithType:'[' position:startPosition line:startLine column:startColumn];
                else return [self tokenWithType:LX_TK_ERROR position:startPosition line:startLine column:startColumn];
            }
            case '=': {
                [self next];
                if([self current] != '=') return [self tokenWithType:'=' position:startPosition line:startLine column:startColumn];
                else { [self next]; return [self tokenWithType:LX_TK_EQ position:startPosition line:startLine column:startColumn]; }
            }
            case '<': {
                [self next];
                if([self current] != '=') return [self tokenWithType:'<' position:startPosition line:startLine column:startColumn];
                else { [self next]; return [self tokenWithType:LX_TK_LE position:startPosition line:startLine column:startColumn]; }
            }
            case '>': {
                [self next];
                if([self current] != '=') return [self tokenWithType:'>' position:startPosition line:startLine column:startColumn];
                else { [self next]; return [self tokenWithType:LX_TK_GE position:startPosition line:startLine column:startColumn]; }
            }
            case '~': {
                [self next];
                if([self current] != '=') return [self tokenWithType:'~' position:startPosition line:startLine column:startColumn];
                else { [self next]; return [self tokenWithType:LX_TK_NE position:startPosition line:startLine column:startColumn]; }
            }
            case ':': {
                [self next];
                if([self current] != ':') return [self tokenWithType:':' position:startPosition line:startLine column:startColumn];
                else { [self next]; return [self tokenWithType:LX_TK_DBCOLON position:startPosition line:startLine column:startColumn]; }
            }
            case '"': case '\'': {  /* short literal strings */
                [self readString:[self current]];
                return [self tokenWithType:LX_TK_STRING position:startPosition line:startLine column:startColumn];
            }
            case '.': {  /* '.', '..', '...', or number */
                [self next];
                if([self checkNext:@"."]) {
                    if([self checkNext:@"."])
                        return [self tokenWithType:LX_TK_DOTS position:startPosition line:startLine column:startColumn];   /* '...' */
                    else return [self tokenWithType:LX_TK_CONCAT position:startPosition line:startLine column:startColumn];   /* '..' */
                }
                else if(![self isDigit:[self current]]) return [self tokenWithType:'.' position:startPosition line:startLine column:startColumn];
                /* else go through */
            }
            case '0': case '1': case '2': case '3': case '4':
            case '5': case '6': case '7': case '8': case '9': {
                [self readNumeral];
                return [self tokenWithType:LX_TK_NUMBER position:startPosition line:startLine column:startColumn];
            }
            case '\0': {
                return [self tokenWithType:LX_TK_EOS position:startPosition line:startLine column:startColumn];
            }
            default: {
                if([self isAlphaNumeric:[self current]]) {  /* identifier or reserved word? */
                    do {
                        [self next];
                    } while([self isAlphaNumeric:[self current]]);
                    
                    static NSArray *reservedWords = nil;
                    
                    if(!reservedWords) {
                        reservedWords = [@[
                                         @"and", @"break", @"do", @"else", @"elseif",
                                         @"end", @"false", @"for", @"function", @"goto", @"if",
                                         @"in", @"local", @"global", @"nil", @"not", @"or", @"repeat",
                                         @"return", @"then", @"true", @"until", @"while",
                                         @"var", @"Bool", @"Number", @"String", @"Table", @"Function",
                                         @"class", @"extends", @"super"
                                         ] retain];
                    }
                    
                    NSUInteger index = [reservedWords indexOfObject:[self.string substringWithRange:NSMakeRange(startPosition, currentPosition-startPosition)]];
                    
                    if(index != NSNotFound) {
                        return [self tokenWithType:FIRST_RESERVED+(int)index position:startPosition line:startLine column:startColumn];
                    }
                    else {
                        return [self tokenWithType:LX_TK_NAME position:startPosition line:startLine column:startColumn];
                    }
                }
                else {  /* single-char tokens (+ - / ...) */
                    char c = [self current];
                    [self next];
                    return [self tokenWithType:c position:startPosition line:startLine column:startColumn];
                }
            }
        }
    }
    
    return nil;
}

//

- (LXToken *)token:(NSInteger *)index {
    while(YES) {
        if(*index >= [self.tokens count]) {
            LXToken *eofToken = [[LXToken alloc] init];
            eofToken.type = LX_TK_EOS;
            
            return [eofToken autorelease];
        }
        
        LXToken *token = self.tokens[*index];
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
    NSArray *openTokens = [@[
                       @(LX_TK_DO), @(LX_TK_FOR), @(LX_TK_FUNCTION), @(LX_TK_IF),
                       @(LX_TK_REPEAT), @(LX_TK_WHILE), @(LX_TK_CLASS)
                       ] retain];
    
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
    return [[self string] substringWithRange:token.range];
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
        type = [[LXClass alloc] init];
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
        type = [[LXClass alloc] init];
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
        [formatter release];
        
        return [numberExpression autorelease];
    }
    else if([self consumeToken:LX_TK_STRING]) {
        LXNodeStringExpression *stringExpression = [[LXNodeStringExpression alloc] init];
        stringExpression.value = [self tokenValue:token];
        
        return [stringExpression autorelease];
    }
    else if([self consumeToken:LX_TK_NIL]) {
        return [[[LXNodeNilExpression alloc] init] autorelease];
    }
    else if([self consumeToken:LX_TK_TRUE]) {
        LXNodeBoolExpression *boolExpression = [[LXNodeBoolExpression alloc] init];
        boolExpression.value = YES;
        
        return [boolExpression autorelease];
    }
    else if([self consumeToken:LX_TK_FALSE]) {
        LXNodeBoolExpression *boolExpression = [[LXNodeBoolExpression alloc] init];
        boolExpression.value = NO;
        
        return [boolExpression autorelease];
    }
    else if([self consumeToken:LX_TK_DOTS]) {
        return [[[LXNodeVarArgExpression alloc] init] autorelease];
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
                [kvp release];
            }
            else if(token.type == LX_TK_NAME) {
                LXToken *next = [self nextToken];
                
                LXNode *key = nil;
                
                if(next.type == '=') {
                    LXNodeVariableExpression *expression = [[LXNodeVariableExpression alloc] init];
                    expression.variable = [self tokenValue:[self currentToken]];
                    key = [expression autorelease];
                    
                    [self consumeToken:'='];
                }
                
                LXNode *value = [self parseExpression:scope];
                
                if(!value) {
                    
                }
                
                KeyValuePair *kvp = [[KeyValuePair alloc] init];
                kvp.key = key;
                kvp.value = value;
                [keyValuePairs addObject:kvp];
                [kvp release];
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
                [kvp release];
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
                
                expression = [memberExpression autorelease];
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
                
                expression = [indexExpression autorelease];
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
            
            expression = [callExpression autorelease];
        }
        else if(!onlyDotColon && [self currentToken].type == LX_TK_STRING) {
            LXNodeStringCallExpression *stringCallExpression = [[LXNodeStringCallExpression alloc] init];
            
            stringCallExpression.base = expression;
            stringCallExpression.value = [self tokenValue:[self consumeToken]];
            expression = [stringCallExpression autorelease];
        }
        else if(!onlyDotColon && [self currentToken].type == '{') {
            LXNodeTableCallExpression *tableCallExpression = [[LXNodeTableCallExpression alloc] init];
            tableCallExpression.base = expression;
            tableCallExpression.table = [self parseExpression:scope];
            
            expression = [tableCallExpression autorelease];
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
            variableExpression.local = YES;
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
    NSDictionary *unaryOps = @{@('-') : @YES, @('#') : @YES, @(LX_TK_NOT) : @YES};
    NSDictionary *priorityDict = @{
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
            
            expression = [unaryOpExpression autorelease];
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
        }

        //functionStatement.name = [self parseSuffixedExpression:scope onlyDotColon:YES];
        
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
                NSString *identifier = [[self string] substringWithRange:[self consumeToken].range];
                
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

            [variable release];
            
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
            
            declarationStatement.varList = varList;
            declarationStatement.initList = initList;
            
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
                
                LXNodeFunctionExpression *functionExpression = [self parseFunction:classScope anonymous:NO isLocal:YES];
                LXNodeFunctionStatement *functionStatement = [[LXNodeFunctionStatement alloc] init];
                functionStatement.expression = functionExpression;
                functionStatement.isLocal = YES;
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
    
    LXClass *scriptClass = [[LXClass alloc] init];
    scriptClass.name = classStatement.name;
    if(classStatement.superclass)
        scriptClass.parent = [self findType:classStatement.superclass];
    scriptClass.variables = variables;
    scriptClass.functions = functions;
    
    [self declareType:classStatement.name objectType:scriptClass];
    
    return classStatement;
}

- (LXNodeStatement *)parseStatement:(LXScope *)scope {
    BOOL isLocal = ![scope isFileScope] && ![scope isGlobalScope];
    
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
            [elseIfStatement release];
        }
        
        ifStatement.elseIfStatements = elseIfStatements;
        
        if([self consumeToken:LX_TK_ELSE]) {
            ifStatement.elseStatement = [self parseBlock:scope];
        }
        
        if(![self consumeToken:LX_TK_END]) {
            [errors addObject:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:[self currentToken]]]];
        }
        
        return [ifStatement autorelease];
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
        
        return [whileStatement autorelease];
    }
    else if([self consumeToken:LX_TK_DO]) {
        LXNodeDoStatement *doStatement = [[LXNodeDoStatement alloc] init];
        
        doStatement.body = [self parseBlock:scope];
        
        if(![self consumeToken:LX_TK_END]) {
            [errors addObject:[NSString stringWithFormat:@"Expected 'end' near: %@", [self tokenValue:[self currentToken]]]];
        }
        
        return [doStatement autorelease];
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
            
            return [forStatement autorelease];
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
            
            return [forStatement autorelease];
        }
    }
    else if([self consumeToken:LX_TK_REPEAT]) {
        LXNodeRepeatStatement *repeatStatement = [[LXNodeRepeatStatement alloc] init];
        
        repeatStatement.body = [self parseBlock:scope];
        
        if(![self consumeToken:LX_TK_UNTIL]) {
            [errors addObject:[NSString stringWithFormat:@"Expected 'until' near: %@", [self tokenValue:[self currentToken]]]];
        }
        
        repeatStatement.condition = [self parseExpression:scope];
        
        return [repeatStatement autorelease];
    }
    else if([self consumeToken:LX_TK_FUNCTION]) {
        LXNodeFunctionExpression *functionExpression = [self parseFunction:scope anonymous:NO isLocal:isLocal];
        LXNodeFunctionStatement *functionStatement = [[LXNodeFunctionStatement alloc] init];
        functionStatement.expression = functionExpression;
        functionStatement.isLocal = isLocal;
        
        return [functionStatement autorelease];
    }
    else if([self consumeToken:LX_TK_CLASS]) {
        LXNodeClassStatement *classStatement = [self parseClassStatement:scope];
        classStatement.isLocal = isLocal;
        
        return [classStatement autorelease];
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
        
        return [labelStatement autorelease];
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
        
        return [returnStatement autorelease];
    }
    else if([self consumeToken:LX_TK_BREAK]) {
        LXNodeBreakStatement *breakStatement = [[LXNodeBreakStatement alloc] init];
        
        return [breakStatement autorelease];
    }
    else if([self consumeToken:LX_TK_GOTO]) {
        LXNodeGotoStatement *gotoStatement = [[LXNodeGotoStatement alloc] init];
        
        if([self currentToken].type != LX_TK_NAME) {
            [errors addObject:[NSString stringWithFormat:@"Expected 'name' near: %@", [self tokenValue:[self currentToken]]]];
        }
        else {
            gotoStatement.label = [self tokenValue:[self currentToken]];
        }
        
        return [gotoStatement autorelease];
    }
    else if([self consumeToken:';']) {
        LXNodeEmptyStatement *emptyStatement = [[LXNodeEmptyStatement alloc] init];
        
        return [emptyStatement autorelease];
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
            
            declarationStatement.varList = varList;
            declarationStatement.initList = initList;
            
            return [declarationStatement autorelease];
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
                
                assignmentStatement.varList = varList;
                assignmentStatement.initList = initList;
                
                return [assignmentStatement autorelease];
            }
            else {
                if(![expression isKindOfClass:[LXNodeCallExpression class]] &&
                   ![expression isKindOfClass:[LXNodeTableCallExpression class]] &&
                   ![expression isKindOfClass:[LXNodeStringCallExpression class]]) {
                    [errors addObject:@"Expected call expression"];
                }
                
                LXNodeExpressionStatement *expressionStatement = [[LXNodeExpressionStatement alloc] init];
                
                expressionStatement.expression = expression;
                return [expressionStatement autorelease];
            }
        }
    }
}

- (LXNodeBlock *)parseBlock:(LXScope *)scope {
    NSDictionary *closeKeywords = @{@(LX_TK_END) : @YES, @(LX_TK_ELSE) : @YES, @(LX_TK_ELSEIF) : @YES, @(LX_TK_UNTIL) : @YES};
    
    LXNodeBlock *block = [[LXNodeBlock alloc] init];
    
    LXScope *blockScope = [self pushScope:scope openScope:YES];
    block.scope = blockScope;
    [blockScope release];
    
    NSMutableArray *statements = [NSMutableArray array];
    while(!closeKeywords[@([self currentToken].type)] &&
          [self currentToken].type != LX_TK_EOS) {
        LXNodeStatement *statement = [self parseStatement:block.scope];
        
        [statements addObject:statement];
    }
    
    block.statements = statements;
    
    [self popScope];
    
    return [block autorelease];
}

@end
