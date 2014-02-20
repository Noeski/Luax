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
#import "LXTextView.h"

@implementation LXCompilerError
@end

@implementation LXCompiler

- (id)init {
    if(self = [super init]) {
        _fileMap = [[NSMutableDictionary alloc] init];
        _baseTypeMap = [[NSMutableDictionary alloc] init];
        _typeMap = [[NSMutableDictionary alloc] init];
        
        NSString *path = [[NSBundle mainBundle] pathForResource:@"AutoCompleteDefinitions" ofType:@"json"];
        NSError *error;
        NSDictionary *dictionary = [[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error] JSONValue];
        NSArray *definitions = dictionary[@"definitions"];
        _baseAutoCompleteDefinitions = [[NSMutableArray alloc] initWithCapacity:[definitions count]];

        for(NSDictionary *definition in definitions) {
            LXAutoCompleteDefinition *autoCompleteDefinition = [[LXAutoCompleteDefinition alloc] init];
            
            autoCompleteDefinition.key = definition[@"key"];
            
            NSString *string = definition[@"string"];
            NSMutableArray *autoCompleteDefinitionMarkers = [NSMutableArray array];
            NSRange firstMarkerRange = [string rangeOfString:@"\\m" options:NSLiteralSearch range:NSMakeRange(0, [string length])];
            NSInteger offset = 0;
            
            while(firstMarkerRange.location != NSNotFound) {
                NSRange secondMarkerRange = [string rangeOfString:@"\\m" options:NSLiteralSearch range:NSMakeRange(NSMaxRange(firstMarkerRange), [string length] - NSMaxRange(firstMarkerRange))];
                
                if(secondMarkerRange.location == NSNotFound)
                    break;
                
                NSInteger location = NSMaxRange(firstMarkerRange) - offset - 2;
                NSInteger length = secondMarkerRange.location - location - offset - 2;
                
                [autoCompleteDefinitionMarkers addObject:[NSValue valueWithRange:NSMakeRange(location, length)]];
                
                firstMarkerRange = [string rangeOfString:@"\\m" options:NSLiteralSearch range:NSMakeRange(NSMaxRange(secondMarkerRange), [string length] - NSMaxRange(secondMarkerRange))];
                
                offset += 4;
            }
            
            autoCompleteDefinition.string = [string stringByReplacingOccurrencesOfString:@"\\m" withString:@""];
            autoCompleteDefinition.title = definition[@"title"];
            autoCompleteDefinition.description = definition[@"description"];
            autoCompleteDefinition.markers = autoCompleteDefinitionMarkers;
            [_baseAutoCompleteDefinitions addObject:autoCompleteDefinition];
        }

        _baseTypeMap[@"Number"] = [LXClassNumber classNumber];
        _baseTypeMap[@"Bool"] = [LXClassBool classBool];
        _baseTypeMap[@"String"] = [LXClassString classString];
        _baseTypeMap[@"Table"] = [LXClassTable classTable];
        _baseTypeMap[@"Function"] = [LXClassFunction classFunction];
        _baseTypeMap[@"var"] = [LXClassVar classVar];

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
    NSMutableDictionary *tokensByLine;
    LXTokenNode *firstToken;
    LXTokenNode *previousTokenNode;
}

@end

@implementation LXContext

- (id)initWithName:(NSString *)name compiler:(LXCompiler *)compiler {
    if(self = [super init]) {
        _name = [name copy];
        _compiler = compiler;
        _parser = [[LXParser alloc] init];
        _errors = [[NSMutableArray alloc] init];
        _warnings = [[NSMutableArray alloc] init];
        scopeStack = [[NSMutableArray alloc] init];
        tokensByLine = [[NSMutableDictionary alloc] init];
        definedTypes = [[NSMutableArray alloc] init];
        definedVariables = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void)compile:(NSString *)string {
    [self.errors removeAllObjects];
    [self.warnings removeAllObjects];

    for(LXClass *type in definedTypes) {
        [self.compiler undeclareType:type.name];
    }
    
    for(LXVariable *variable in definedVariables) {
        [self.compiler.globalScope removeVariable:variable];
    }
    
    [definedTypes removeAllObjects];
    [definedVariables removeAllObjects];
    [scopeStack removeAllObjects];
    [tokensByLine removeAllObjects];
    
    firstToken = nil;
    previousTokenNode = nil;

    [self.compiler.globalScope removeScope:self.scope];
    
    [self.parser parse:string];
    
    self.currentTokenIndex = 0;
    
    _currentScope = self.compiler.globalScope;
    
    LXBlock *block = [self parseBlock:nil];
    [block verify];
    [block resolveVariables:self];
    [block resolveTypes:self];
    
    self.block = block;
    self.scope = block.scope;
}

BOOL locationInsideRange(NSInteger location, NSRange range) {
    return location >= range.location && location <= NSMaxRange(range);
}

- (NSArray *)completionsForLocation:(NSInteger)location range:(NSRangePointer)range {
    LXTokenNode *node = [self.block closestCompletionNode:location];
    NSInteger firstLine = node.line;
    NSInteger nextLine = firstLine;
    
    *range = NSMakeRange(location, 0);
    
    if(locationInsideRange(location, node.range)) {
        if(node.isReserved) {
            *range = NSMakeRange(node.location, location-node.location);
            node = node.prev;
            firstLine = node.line;
        }
        else if(node.tokenType == '.' || node.tokenType == ':') {
            
        }
        else {
            node = nil;
        }
    }
    
    NSMutableArray *autoCompleteDefinitions = [[NSMutableArray alloc] init];
    
    if((node.completionFlags & LXTokenCompletionFlagsMembers) == LXTokenCompletionFlagsMembers ||
       (node.completionFlags & LXTokenCompletionFlagsFunctions) == LXTokenCompletionFlagsFunctions) {
        LXClass *type = node.type;
        
        if(type.isDefined) {
            while(type) {
                NSArray *variables = [type.variables arrayByAddingObjectsFromArray:type.functions];
                
                for(LXVariable *variable in variables) {
                    if(![variable isFunction] && !variable.type.isDefined) {
                        continue;
                    }
                    
                    if((node.completionFlags & LXTokenCompletionFlagsMembers) == LXTokenCompletionFlagsMembers) {
                        if([variable isFunction]) {
                            if(!variable.isStatic)
                                continue;
                        }
                    }
                    else {
                        if([variable isFunction]) {
                            if(variable.isStatic)
                                continue;
                        }
                        else {
                            continue;
                        }
                    }
                    
                    BOOL found = NO;
                    
                    for(LXAutoCompleteDefinition *definition in autoCompleteDefinitions) {
                        if([definition.key isEqualToString:variable.name]) {
                            found = YES;
                            break;
                        }
                    }
                    
                    if(found)
                        continue;
                    
                    LXAutoCompleteDefinition *autoCompleteDefinition = [[LXAutoCompleteDefinition alloc] init];
                    
                    autoCompleteDefinition.key = variable.name;
                    
                    if([variable isFunction]) {
                        if([variable.returnTypes count]) {
                            LXVariable *returnType = variable.returnTypes[0];
                            
                            autoCompleteDefinition.type = returnType.type.name;
                            
                            for(NSInteger i = 1; i < [variable.returnTypes count]; ++i) {
                                returnType = variable.returnTypes[i];
                                
                                autoCompleteDefinition.type = [autoCompleteDefinition.type stringByAppendingFormat:@", %@", returnType.type.name];
                            }
                        }
                        else {
                            autoCompleteDefinition.type = @"void";
                        }
                        
                        autoCompleteDefinition.string = [NSString stringWithFormat:@"%@(", variable.name];
                        autoCompleteDefinition.title = [NSString stringWithFormat:@"%@(", variable.name];
                        
                        NSMutableArray *markers = nil;
                        
                        if([variable.arguments count]) {
                            markers = [NSMutableArray array];
                            
                            LXVariable *argument = variable.arguments[0];
                            
                            NSRange marker = NSMakeRange(autoCompleteDefinition.string.length, argument.name.length);
                            [markers addObject:[NSValue valueWithRange:marker]];
                            
                            autoCompleteDefinition.string = [autoCompleteDefinition.string stringByAppendingFormat:@"%@", argument.name];
                            autoCompleteDefinition.title = [autoCompleteDefinition.title stringByAppendingFormat:@"%@", argument.type.name];
                            
                            for(NSInteger i = 1; i < [variable.arguments count]; ++i) {
                                argument = variable.arguments[i];
                                
                                marker = NSMakeRange(autoCompleteDefinition.string.length+2, argument.name.length);
                                [markers addObject:[NSValue valueWithRange:marker]];
                                
                                autoCompleteDefinition.string = [autoCompleteDefinition.string stringByAppendingFormat:@", %@", argument.name];
                                autoCompleteDefinition.title = [autoCompleteDefinition.title stringByAppendingFormat:@", %@", argument.type.name];
                            }
                        }
                        
                        autoCompleteDefinition.string = [autoCompleteDefinition.string stringByAppendingString:@")"];
                        autoCompleteDefinition.title = [autoCompleteDefinition.title stringByAppendingString:@")"];
                        
                        autoCompleteDefinition.markers = markers;
                        autoCompleteDefinition.description = nil;
                    }
                    else {
                        autoCompleteDefinition.type = variable.type.name ? variable.type.name : @"(Undefined)";
                        autoCompleteDefinition.string = variable.name;
                        autoCompleteDefinition.title = variable.name;
                        autoCompleteDefinition.description = nil;
                        autoCompleteDefinition.markers = nil;
                    }
                    
                    [autoCompleteDefinitions addObject:autoCompleteDefinition];
                }
                
                type = type.parent;
            }
        }
    }
    else {
        if((node.completionFlags & LXTokenCompletionFlagsControlStructures) == LXTokenCompletionFlagsControlStructures &&
           firstLine != nextLine) {
            for(LXAutoCompleteDefinition *definition in self.compiler.baseAutoCompleteDefinitions) {
                BOOL found = NO;

                for(LXAutoCompleteDefinition *otherDefinition in autoCompleteDefinitions) {
                    if([otherDefinition.key isEqualToString:definition.key]) {
                        found = YES;
                        break;
                    }
                }

                if(found)
                    continue;

                [autoCompleteDefinitions addObject:definition];
            }
        }
        
        if((node.completionFlags & LXTokenCompletionFlagsVariables) == LXTokenCompletionFlagsVariables) {
            LXScope *scope = [node scope];
            
            while(scope) {
                for(LXVariable *variable in scope.localVariables) {
                    if(!variable.isFunction && !variable.type.isDefined) {
                        continue;
                    }
                    
                    if(!scope.isGlobalScope && variable.definedLocation >= location) {
                        continue;
                    }
                    
                    BOOL found = NO;
                    
                    for(LXAutoCompleteDefinition *definition in autoCompleteDefinitions) {
                        if([definition.key isEqualToString:variable.name]) {
                            found = YES;
                            break;
                        }
                    }
                    
                    if(found)
                        continue;
                    
                    if([variable isFunction]) {
                        LXAutoCompleteDefinition *autoCompleteDefinition = [[LXAutoCompleteDefinition alloc] init];
                        
                        autoCompleteDefinition.key = variable.name;
                        
                        if([variable.returnTypes count]) {
                            LXVariable *returnType = variable.returnTypes[0];
                            
                            autoCompleteDefinition.type = returnType.type.name;
                            
                            for(NSInteger i = 1; i < [variable.returnTypes count]; ++i) {
                                returnType = variable.returnTypes[i];
                                
                                autoCompleteDefinition.type = [autoCompleteDefinition.type stringByAppendingFormat:@", %@", returnType.type.name];
                            }
                        }
                        else {
                            autoCompleteDefinition.type = @"void";
                        }
                        
                        autoCompleteDefinition.string = [NSString stringWithFormat:@"%@(", variable.name];
                        autoCompleteDefinition.title = [NSString stringWithFormat:@"%@(", variable.name];
                        
                        NSMutableArray *markers = nil;
                        
                        if([variable.arguments count]) {
                            markers = [NSMutableArray array];
                            
                            LXVariable *argument = variable.arguments[0];
                            
                            NSRange marker = NSMakeRange(autoCompleteDefinition.string.length, argument.name.length);
                            [markers addObject:[NSValue valueWithRange:marker]];
                            
                            autoCompleteDefinition.string = [autoCompleteDefinition.string stringByAppendingFormat:@"%@", argument.name];
                            autoCompleteDefinition.title = [autoCompleteDefinition.title stringByAppendingFormat:@"%@", argument.type.name];
                            
                            for(NSInteger i = 1; i < [variable.arguments count]; ++i) {
                                argument = variable.arguments[i];
                                
                                marker = NSMakeRange(autoCompleteDefinition.string.length+2, argument.name.length);
                                [markers addObject:[NSValue valueWithRange:marker]];
                                
                                autoCompleteDefinition.string = [autoCompleteDefinition.string stringByAppendingFormat:@", %@", argument.name];
                                autoCompleteDefinition.title = [autoCompleteDefinition.title stringByAppendingFormat:@", %@", argument.type.name];
                            }
                        }
                        
                        autoCompleteDefinition.string = [autoCompleteDefinition.string stringByAppendingString:@")"];
                        autoCompleteDefinition.title = [autoCompleteDefinition.title stringByAppendingString:@")"];
                        
                        autoCompleteDefinition.markers = markers;
                        autoCompleteDefinition.description = nil;
                        
                        [autoCompleteDefinitions addObject:autoCompleteDefinition];
                    }
                    
                    if(variable.type.isDefined) {
                        LXAutoCompleteDefinition *autoCompleteDefinition = [[LXAutoCompleteDefinition alloc] init];
                        
                        autoCompleteDefinition.key = variable.name;
                        
                        autoCompleteDefinition.type = variable.type.name ? variable.type.name : @"(Undefined)";
                        autoCompleteDefinition.string = variable.name;
                        autoCompleteDefinition.title = variable.name;
                        autoCompleteDefinition.description = nil;
                        autoCompleteDefinition.markers = nil;
                        
                        [autoCompleteDefinitions addObject:autoCompleteDefinition];
                    }
                }
                
                scope = scope.parent;
            }
        }
        
        if((node.completionFlags & LXTokenCompletionFlagsTypes) == LXTokenCompletionFlagsTypes) {
            NSMutableDictionary *typeMap = [self.compiler.baseTypeMap mutableCopy];
            [typeMap addEntriesFromDictionary:self.compiler.typeMap];
            
            for(NSString *key in [typeMap allKeys]) {
                if(![typeMap[key] isDefined])
                    continue;
                
                LXAutoCompleteDefinition *autoCompleteDefinition = [[LXAutoCompleteDefinition alloc] init];
                
                autoCompleteDefinition.key = key;
                autoCompleteDefinition.type = @"Class";
                autoCompleteDefinition.string = key;
                autoCompleteDefinition.title = key;
                autoCompleteDefinition.description = nil;
                autoCompleteDefinition.markers = nil;
                [autoCompleteDefinitions addObject:autoCompleteDefinition];
            }
        }
    }
    
    return autoCompleteDefinitions;
}

- (LXTokenNode *)firstToken {
    return firstToken;
}

- (LXTokenNode *)tokenForLine:(NSInteger)line {
    return tokensByLine[@(line)];
}

- (void)addError:(NSString *)error range:(NSRange)range line:(NSInteger)line column:(NSInteger)column {
    LXCompilerError *compilerError = [[LXCompilerError alloc] init];
    compilerError.error = error;
    compilerError.range = range;
    compilerError.line = line;
    compilerError.column = column;
    [self.errors addObject:compilerError];
}

- (void)addWarning:(NSString *)warning range:(NSRange)range line:(NSInteger)line column:(NSInteger)column {
    LXCompilerError *compilerError = [[LXCompilerError alloc] init];
    compilerError.error = warning;
    compilerError.range = range;
    compilerError.line = line;
    compilerError.column = column;
    compilerError.isWarning = YES;
    [self.warnings addObject:compilerError];
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

- (LXVariable *)createGlobalVariable:(NSString *)name type:(LXClass *)type {
    LXVariable *variable = [self.compiler.globalScope createVariable:name type:type];
    [definedVariables addObject:variable];
    
    return variable;
}

- (LXVariable *)createGlobalFunction:(NSString *)name {
    LXVariable *function = [self.compiler.globalScope createFunction:name];
    [definedVariables addObject:function];
    
    return function;
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

- (LXScope *)createScope:(BOOL)openScope {
    LXScope *scope = [[LXScope alloc] initWithParent:_currentScope openScope:openScope];
    scope.range = NSMakeRange(NSMaxRange([self previousToken].range), 0);
    
    [self pushScope:scope];
    
    return scope;
}

- (void)finishScope {
    _currentScope.range = NSMakeRange(_currentScope.range.location, _current.range.location - _currentScope.range.location);
    
    [self popScope];
}

- (void)pushScope:(LXScope *)scope {
    _currentScope = scope;
    [scopeStack addObject:_currentScope];
}

- (void)popScope {
    if([scopeStack count] == 0) {
        //error
    }
    
    [scopeStack removeLastObject];
    _currentScope = [scopeStack lastObject];
}

- (LXScope *)currentScope {
    return _currentScope;
}

- (void)setCurrentTokenIndex:(NSInteger)index {
    _nextTokenIndex = index;
    _current = [self previousToken:_nextTokenIndex-1];
    _next = [self token:&_nextTokenIndex];
    
    [self advance];
}

- (LXToken *)previousToken:(NSInteger)index {
    NSInteger count = [self.parser.tokens count];
    
    if(index >= count) {
        index = count-1;
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
    LXToken *token = _current;
    [self advance];
    return token;
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
    NSInteger line = _current.endLine;
    
    while(_current.type != LX_TK_EOS && _current.endLine == line) {
        [self consumeTokenNode];
    }
}

- (id)nodeWithType:(Class)class {
    LXNode *node = [[class alloc] init];
    node.line = _current.line;
    node.column = _current.column;
    node.location = _current.range.location;
    
    return node;
}

- (id)finish:(LXNode *)node {
    node.length = NSMaxRange(_previous.range)-node.location;
    
    return node;
}

- (LXTokenNode *)consumeTokenNode {
    LXTokenNode *tokenNode = [LXTokenNode tokenNodeWithToken:_current];
    tokenNode.value = [self tokenValue:_current];
    tokenNode.tokenType = _current.type;
    tokenNode.prev = previousTokenNode;
    [self advance];
    
    LXTokenNode *tokenByLine = tokensByLine[@(tokenNode.line)];
    
    if(!tokenByLine) {
        tokensByLine[@(tokenNode.line)] = tokenNode;
    }
   
    if(!firstToken) {
        firstToken = tokenNode;
    }
    
    previousTokenNode = tokenNode;
    
    return tokenNode;
}

@end