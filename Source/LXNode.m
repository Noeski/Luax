//
//  LXNode.m
//  LuaX
//
//  Created by Noah Hilt on 8/11/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXNode.h"
#import "LXCompiler.h"
#import "NSNumber+Base64VLQ.h"
#import <objc/objc-runtime.h>

@interface LXLuaWriter()
@property (nonatomic, strong) NSMutableString *mutableString;
@property (nonatomic, strong) NSMutableArray *mutableMappings;
@property (nonatomic, strong) NSString *lastName;
@property (nonatomic, assign) NSInteger lastLine;
@property (nonatomic, assign) NSInteger lastColumn;
@end

@implementation LXLuaWriter

- (id)init {
    if(self = [super init]) {
        _mutableString = [[NSMutableString alloc] init];
        _mutableMappings = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (NSString *)string {
    return _mutableString;
}

- (NSArray *)mappings {
    return _mutableMappings;
}

- (void)write:(NSString *)generated {
    [self.mutableString appendString:generated];
    
    NSArray *lines = [generated componentsSeparatedByString:@"\n"];
    
    if([lines count] == 1) {
        self.currentColumn += [generated length];
    }
    else {
        self.currentLine += [lines count] - 1;
        self.currentColumn = [lines.lastObject length];
    }
}

- (void)write:(NSString *)generated line:(NSInteger)line column:(NSInteger)column {
    [self write:generated name:nil line:line column:column];
}

- (void)write:(NSString *)generated name:(NSString *)name line:(NSInteger)line column:(NSInteger)column {
    if(line != self.lastLine ||
       column != self.lastColumn ||
       ![name isEqual:self.lastName]) {
        NSDictionary *dictionary = @{@"source" : self.currentSource, @"name" : name ? name : @"", @"original" : @{@"line" : @(line), @"column" : @(column)}, @"generated" : @{@"line" : @(self.currentLine), @"column" : @(self.currentColumn)}};
        
        [self.mutableMappings addObject:dictionary];
        
        self.lastName = name;
        self.lastLine = line;
        self.lastColumn = column;
    }
    
    [self write:generated];
}

/*- (NSDictionary *)originalPosition:(NSInteger)line column:(NSInteger)column {
    NSDictionary *mapping = recursiveSearch(-1, [self.mappings count], @{@"generated" : @{@"line" : @(line), @"column" : @(column)}}, self.mappings, ^(NSDictionary *obj1, NSDictionary *obj2) {
        NSInteger cmp = [obj1[@"generated"][@"line"] integerValue] - [obj2[@"generated"][@"line"] integerValue];
        
        if(cmp > 0)
            return cmp;
        else if(cmp < 0)
            return cmp;
        
        cmp = [obj1[@"generated"][@"column"] integerValue] - [obj2[@"generated"][@"column"] integerValue];
        
        if(cmp > 0)
            return cmp;
        else if(cmp < 0)
            return cmp;
        
        return cmp;
    });
    
    return mapping;
}

- (NSDictionary *)generatedPosition:(NSInteger)line column:(NSInteger)column {
    NSInteger index = [self.mappings indexOfObject:@{@"original" : @{@"line" : @(line), @"column" : @(column)}} inSortedRange:NSMakeRange(0, [self.mappings count]) options:NSBinarySearchingFirstEqual usingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
        NSInteger cmp = [obj1[@"original"][@"line"] integerValue] - [obj2[@"original"][@"line"] integerValue];
        
        if(cmp > 0)
            return NSOrderedAscending;
        else if(cmp < 0)
            return NSOrderedDescending;
        
        cmp = [obj1[@"original"][@"column"] integerValue] - [obj2[@"original"][@"column"] integerValue];
        
        if(cmp > 0)
            return NSOrderedAscending;
        else if(cmp < 0)
            return NSOrderedDescending;
        
        return NSOrderedSame;
    }];
    
    return self.mappings[index];
}*/

- (NSDictionary *)generateSourceMap {
    NSMutableArray *sourcesArray = [NSMutableArray array];
    NSMutableDictionary *sourcesMap = [NSMutableDictionary dictionary];
    NSInteger currentSourceIndex = 0;

    NSMutableArray *namesArray = [NSMutableArray array];
    NSMutableDictionary *namesMap = [NSMutableDictionary dictionary];
    NSInteger currentNameIndex = 0;
    
    NSInteger previousGeneratedColumn = 0;
    NSInteger previousGeneratedLine = 0;
    NSInteger previousOriginalColumn = 0;
    NSInteger previousOriginalLine = 0;
    NSInteger previousSource = 0;
    NSInteger previousName = 0;

    NSString *mappings = @"";
    
    for(NSInteger i = 0; i < [self.mappings count]; ++i) {
        NSDictionary *mapping = self.mappings[i];
        NSInteger generatedLine = [mapping[@"generated"][@"line"] integerValue];
        NSInteger generatedColumn = [mapping[@"generated"][@"column"] integerValue];
        NSInteger originalLine = [mapping[@"original"][@"line"] integerValue];
        NSInteger originalColumn = [mapping[@"original"][@"column"] integerValue];
        NSString *source = mapping[@"source"];
        NSString *name = mapping[@"name"];
        
        if(generatedLine != previousGeneratedLine) {
            previousGeneratedColumn = 0;
            while(generatedLine != previousGeneratedLine) {
                mappings = [mappings stringByAppendingString:@";"];
                previousGeneratedLine++;
            }
        }
        else {
            if(i > 0) {
                NSDictionary *lastMapping = self.mappings[i-1];
                
                if([lastMapping isEqualToDictionary:mapping])
                    continue;
                    
                mappings = [mappings stringByAppendingString:@","];
            }
        }
        
        
        mappings = [mappings stringByAppendingString:[@(generatedColumn - previousGeneratedColumn) encode]];

        previousGeneratedColumn = generatedColumn;
        
        NSNumber *sourceIndex = sourcesMap[source];
        
        if(!sourceIndex) {
            sourceIndex = [NSNumber numberWithInteger:currentSourceIndex++];
            sourcesMap[source] = sourceIndex;
            
            [sourcesArray addObject:source];
        }
        
        mappings = [mappings stringByAppendingString:[@([sourceIndex integerValue] - previousSource) encode]];
        previousSource = [sourceIndex integerValue];
        
        mappings = [mappings stringByAppendingString:[@(originalLine - previousOriginalLine) encode]];
        
        previousOriginalLine = originalLine;
        
        mappings = [mappings stringByAppendingString:[@(originalColumn - previousOriginalColumn) encode]];
        
        previousOriginalColumn = originalColumn;
        
        if([name length] > 0) {
            NSNumber *nameIndex = namesMap[name];
            
            if(!nameIndex) {
                nameIndex = [NSNumber numberWithInteger:currentNameIndex++];
                namesMap[name] = nameIndex;
                
                [namesArray addObject:name];

            }
            
            mappings = [mappings stringByAppendingString:[@([nameIndex integerValue] - previousName) encode]];
            previousName = [nameIndex integerValue];
        }
    }
    
    
    return @{@"version" : @(3), @"sources" : sourcesArray, @"names" : namesArray, @"mappings" : mappings};
}

- (NSArray *)parseMapping:(NSString *)string {
    NSMutableString *mutableString = [NSMutableString stringWithString:string];
    NSMutableArray *newMappings = [NSMutableArray array];
    
    NSInteger generatedLine = 0;
    NSInteger previousGeneratedColumn = 0;
    NSInteger previousOriginalLine = 0;
    NSInteger previousOriginalColumn = 0;
    NSInteger previousSource = 0;
    NSInteger previousName = 0;
    NSCharacterSet *mappingSeparator = [NSCharacterSet characterSetWithCharactersInString:@",;"];
    
    while([mutableString length] > 0) {
        if([mutableString characterAtIndex:0] == ';') {
            generatedLine++;
            [mutableString deleteCharactersInRange:NSMakeRange(0, 1)];
            previousGeneratedColumn = 0;
        }
        else if([string characterAtIndex:0] == ',') {
            string = [string substringFromIndex:1];
        }
        else {
            NSMutableDictionary *mapping = [NSMutableDictionary dictionary];
            NSInteger temp;

            temp = [[mutableString decode] integerValue];
            previousGeneratedColumn = previousGeneratedColumn + temp;

            mapping[@"generated"] = @{@"line" : @(generatedLine), @"column" : @(previousGeneratedColumn)};
            
            if([mutableString length] > 0 && ![mappingSeparator characterIsMember:[mutableString characterAtIndex:0]]) {
                // Original source.
                temp = [[mutableString decode] integerValue];
                
                NSInteger source = previousSource + temp;
                previousSource += temp;
                
                if([mutableString length] == 0 || [mappingSeparator characterIsMember:[mutableString characterAtIndex:0]]) {
                    //error
                }
                
                temp = [[mutableString decode] integerValue];
                
                // Original line.
                NSInteger originalLine = previousOriginalLine + temp;
                previousOriginalLine = originalLine;
                
                if([mutableString length] == 0 || [mappingSeparator characterIsMember:[mutableString characterAtIndex:0]]) {
                    //error
                }
                
                temp = [[mutableString decode] integerValue];
                
                NSInteger originalColumn = previousOriginalColumn + temp;
                previousOriginalColumn = originalColumn;
                
                mapping[@"original"] = @{@"line" : @(originalLine), @"column" : @(originalColumn)};
                
                if([mutableString length] > 0 && ![mappingSeparator characterIsMember:[mutableString characterAtIndex:0]]) {
                    // Original name.
                    temp = [[mutableString decode] integerValue];
                    
                    mapping[@"name"] = @(previousName+temp);
                    
                    previousName += temp;
                }
            }
            
            [newMappings addObject:mapping];
        }
    }
    
    return newMappings;
}

@end

@implementation LXScope

- (id)initWithParent:(LXScope *)parent openScope:(BOOL)openScope {
    if(self = [super init]) {
        _type = LXScopeTypeBlock;
        _parent = parent;
        _children = [[NSMutableArray alloc] init];
        _localVariables = [[NSMutableArray alloc] init];
        
        [_parent.children addObject:self];
        
        if([self isGlobalScope] || [self isFileScope]) {
            _scopeLevel = 0;
        }
        else if(openScope) {
            _scopeLevel = parent.scopeLevel+1;
        }
        else {
            _scopeLevel = parent.scopeLevel;
        }
    }
    
    return self;
}

- (BOOL)isGlobalScope {
    return self.parent == nil;
}

- (BOOL)isFileScope {
    return [self.parent isGlobalScope];
}

- (LXVariable *)localVariable:(NSString *)name {
    for(LXVariable *variable in self.localVariables) {
        if([variable.name isEqualToString:name]) {
            return variable;
        }
    }
    
    return nil;
}

- (LXVariable *)variable:(NSString *)name {
    for(LXVariable *variable in self.localVariables) {
        if([variable.name isEqualToString:name]) {
            return variable;
        }
    }
    
    return [self.parent variable:name];
}

- (LXVariable *)createVariable:(NSString *)name type:(LXClass *)type {
    if([name isEqualToString:@"A"]) {
        NSLog(@"Break");
    }
    
    LXVariable *variable = [LXVariable variableWithName:name type:type];
    variable.isGlobal = [self isGlobalScope];
    
    [self.localVariables addObject:variable];
    
    return variable;
}

- (LXVariable *)createFunction:(NSString *)name {
    LXVariable *function = [LXVariable functionWithName:name];
    function.name = name;
    function.isGlobal = [self isGlobalScope];
    
    [self.localVariables addObject:function];
    
    return function;
}

- (void)removeVariable:(LXVariable *)variable {
    [self.localVariables removeObject:variable];
}

- (LXScope *)scopeAtLocation:(NSInteger)location {
    if(![self isGlobalScope] &&
       ![self isFileScope] &&
       !NSLocationInRange(location, self.range)) {
        return nil;
    }
        
    for(LXScope *child in self.children) {
        LXScope *scope = [child scopeAtLocation:location];
        
        if(scope)
            return scope;
    }
    
    return self;
}

- (void)removeScope:(LXScope *)scope {
    [self.children removeObject:scope];
}

@end

@interface LXNode()
@property (nonatomic, strong) NSMutableArray *mutableChildren;
@end

@implementation LXNode

- (id)initWithName:(NSString *)name line:(NSInteger)line column:(NSInteger)column {
    if(self = [super init]) {
        _line = line;
        _column = column;
        
        _chunk = name;
        _name = name;
        _mutableChildren = [NSMutableArray array];
    }
    
    return self;
}

- (id)initWithChunk:(NSString *)chunk line:(NSInteger)line column:(NSInteger)column {
    if(self = [super init]) {
        _line = line;
        _column = column;
        
        _chunk = chunk;
        _mutableChildren = [NSMutableArray array];
    }
    
    return self;
}

- (id)initWithLine:(NSInteger)line column:(NSInteger)column {
    if(self = [super init]) {
        _line = line;
        _column = column;
        
        _mutableChildren = [NSMutableArray array];
    }
    
    return self;
}

- (NSArray *)children {
    return _mutableChildren;
}

- (void)addChild:(LXNode *)child {
    [self.mutableChildren addObject:child];
}

- (void)addChunk:(NSString *)child line:(NSInteger)line column:(NSInteger)column {
    LXNode *node = [[LXNode alloc] initWithChunk:child line:line column:column];
    
    [self addChild:node];
}

- (void)addNamedChunk:(NSString *)child line:(NSInteger)line column:(NSInteger)column {
    LXNode *node = [[LXNode alloc] initWithName:child line:line column:column];
    
    [self addChild:node];
}

- (void)addAnonymousChunk:(NSString *)child {
    LXNode *node = [[LXNode alloc] initWithChunk:child line:-1 column:-1];
    
    [self addChild:node];
}

- (void)compile:(LXLuaWriter *)writer {
    if(self.name) {
        [writer write:self.chunk name:self.name line:self.line column:self.column];
    }
    else if(self.chunk) {
        if(self.line == -1)
            [writer write:self.chunk];
        else
            [writer write:self.chunk line:self.line column:self.column];
    }
    
    for(LXNode *child in self.children) {
        [child compile:writer];
    }
}

@end

@interface LXNodeNew()
@property (nonatomic, strong) NSMutableArray *mutableChildren;
@property (nonatomic, strong) NSMutableDictionary *mutableProperties;
@end

@implementation LXNodeNew
- (id)init {
    if(self = [super init]) {
        _mutableChildren = [[NSMutableArray alloc] init];
        _mutableProperties = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}

- (id)initWithLine:(NSInteger)line column:(NSInteger)column location:(NSInteger)location {
    if(self = [super init]) {
        _line = line;
        _column = column;
        _location = location;
        
        _mutableChildren = [[NSMutableArray alloc] init];
        _mutableProperties = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}

//Kind of hacky, but this allows us to automatically add any child node by setting the property

static id propertyIMP(id self, SEL _cmd) {
    return [[self mutableProperties] valueForKey:
            NSStringFromSelector(_cmd)];
}

static void setPropertyIMP(id self, SEL _cmd, id value) {
    NSMutableString *key =
    [NSStringFromSelector(_cmd) mutableCopy];
    
    // Delete "set" and ":" and lowercase first letter
    [key deleteCharactersInRange:NSMakeRange(0, 3)];
    [key deleteCharactersInRange:
     NSMakeRange([key length] - 1, 1)];
    NSString *firstChar = [key substringToIndex:1];
    [key replaceCharactersInRange:NSMakeRange(0, 1)
                       withString:[firstChar lowercaseString]];
    
    id currentValue = [[self mutableProperties] objectForKey:key];
    
    if(currentValue) {
        if([value isKindOfClass:[NSArray class]]) {
            NSInteger index = [[self children] indexOfObject:[currentValue firstObject]];

            [[self mutableChildren] removeObjectsInRange:NSMakeRange(index, [currentValue count])];
            [[self mutableChildren] insertObjects:value atIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(index, [value count])]];
        }
        else {
            NSInteger index = [[self children] indexOfObject:currentValue];
            
            [[self mutableChildren] removeObject:currentValue];
            [[self mutableChildren] insertObject:value atIndex:index];
        }
    }
    else {
        if([value isKindOfClass:[NSArray class]]) {
            [[self mutableChildren] addObjectsFromArray:value];
        }
        else {
            [[self mutableChildren] addObject:value];
        }
    }
    
    [[self mutableProperties] setValue:value forKey:key];
}

+ (BOOL)resolveInstanceMethod:(SEL)aSEL {
    if([NSStringFromSelector(aSEL) hasPrefix:@"set"]) {
        class_addMethod([self class], aSEL, (IMP)setPropertyIMP, "v@:@");
    }
    else {
        class_addMethod([self class], aSEL, (IMP)propertyIMP, "@@:");
    }
    return YES;
}

- (NSArray *)children {
    return _mutableChildren;
}

- (void)resolve:(LXContext *)context {

}
@end

@implementation LXTokenNode

+ (LXTokenNode *)tokenNodeWithToken:(LXToken *)token {
    LXTokenNode *tokenNode = [[LXTokenNode alloc] init];
    
    tokenNode.line = token.line;
    tokenNode.column = token.column;
    tokenNode.location = token.range.location;
    tokenNode.length = token.range.length;
    
    return tokenNode;
}

@end

@implementation LXExpr
@end

@implementation LXNumberExpr
@end

@implementation LXStringExpr
@end

@implementation LXNilExpr
@end

@implementation LXBoolExpr
@end

@implementation LXDotsExpr : LXExpr
@end

@implementation LXVariableExpr
- (void)resolve:(LXContext *)context {
    LXVariable *variable = [context.currentScope variable:self.value];
    
    if(!variable) {
        [context addError:@"" range:NSMakeRange(0, 0) line:0 column:0];
    }
}
@end

@implementation LXTypeNode
@end

@implementation LXVariableNode
@end

@implementation LXDeclarationNode
@end

@implementation LXKVP
- (id)initWithKey:(LXExpr *)key value:(LXExpr *)value {
    if(self = [super init]) {
        _key = key;
        _value = value;
    }
    
    return self;
}

- (id)initWithValue:(LXExpr *)value {
    if(self = [super init]) {
        _value = value;
    }
    
    return self;
}

@end

@implementation LXTableCtorExpr
@end

@implementation LXMemberExpr
- (void)resolve:(LXContext *)context {
    [self.prefix resolve:context];
}
@end

@implementation LXIndexExpr
- (void)resolve:(LXContext *)context {
    [self.prefix resolve:context];
    [self.expr resolve:context];
}
@end

@implementation LXFunctionCallExpr
- (void)resolve:(LXContext *)context {
    [self.prefix resolve:context];
    
    LXVariable *variable = [context.currentScope variable:self.value];
    
    if(!variable) {
        [context addError:@"" range:NSMakeRange(0, 0) line:0 column:0];
    }
    
    for(LXExpr *expr in self.args) {
        [expr resolve:context];
    }
}
@end

@implementation LXUnaryExpr
- (void)resolve:(LXContext *)context {
    [self.expr resolve:context];
}
@end

@implementation LXBinaryExpr
- (void)resolve:(LXContext *)context {
    [self.lhs resolve:context];
    [self.rhs resolve:context];
}
@end

@implementation LXFunctionExpr
- (void)resolve:(LXContext *)context {
    if(self.nameExpr) {
        [self.nameExpr resolve:context];
    }
    
    for(LXTypeNode *node in self.returnTypes) {
        
    }
    
    for(LXDeclarationNode *node in self.args) {
        
    }
    
    [self.body resolve:context];
}
@end

@implementation LXStmt
@end

@implementation LXEmptyStmt
@end

@implementation LXBlock
- (void)resolve:(LXContext *)context {
    [context pushScope:[context currentScope] openScope:YES];
    
    for(LXStmt *statement in self.stmts) {
        [statement resolve:context];
    }
    
    [context popScope];
}
@end

@implementation LXClassStmt
- (void)resolve:(LXContext *)context {
    for(LXDeclarationStmt *stmt in self.vars) {
        [stmt resolve:context];
    }
    
    for(LXExprStmt *stmt in self.functions) {
        [stmt resolve:context];
    }
}
@end

@implementation LXIfStmt
@dynamic ifToken, expr, thenToken, body, elseIfStmts, elseToken, elseStmt, endToken;
@end

@implementation LXElseIfStmt
@dynamic elseIfToken, expr, thenToken, body;
@end

@implementation LXWhileStmt
@dynamic whileToken, expr, doToken, body, endToken;
@end

@implementation LXDoStmt
@dynamic doToken, body, endToken;
@end

@implementation LXForStmt
@dynamic forToken, doToken, body, endToken;
@end

@implementation LXNumericForStmt
@dynamic exprInit, exprCond, exprInc;
@end

@implementation LXIteratorForStmt
@end

@implementation LXRepeatStmt
@end

@implementation LXLabelStmt
@end

@implementation LXGotoStmt
@end

@implementation LXBreakStmt
@end

@implementation LXReturnStmt
@end

@implementation LXDeclarationStmt
- (void)resolve:(LXContext *)context {
    for(LXDeclarationNode *node in self.vars) {
        LXClass *type = [context findType:node.type.value];
        
        if(!type) {
            [context addError:@"" range:NSMakeRange(0, 0) line:0 column:0];
        }
        
        LXVariable *variable = [context.currentScope variable:node.var.value];
        
        if(variable) {
            [context addError:@"" range:NSMakeRange(0, 0) line:0 column:0];
        }
        else {
            [context.currentScope createVariable:node.var.value type:type];
        }
    }
    
    for(LXExpr *expr in self.exprs) {
        [expr resolve:context];
    }
}
@end

@implementation LXAssignmentStmt
@end

@implementation LXExprStmt
@end