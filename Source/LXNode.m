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
@property (nonatomic, assign) NSInteger indentationLevel;
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

- (NSString *)indentedString:(NSString *)string {
    NSArray *lines = [string componentsSeparatedByString:@"\n"];
    NSMutableArray *mutableLines = [[NSMutableArray alloc] init];
    
    for(NSString *line in lines) {
        [mutableLines addObject:[line stringByPaddingToLength:[line length]+self.indentationLevel withString:@" " startingAtIndex:0]];
    }
    
    return [mutableLines componentsJoinedByString:@"\n"];
}

- (void)writeSpace {
    [self write:@" "];
}

- (void)writeNewline {
    [self.mutableString appendString:@"\n"];

    self.currentLine++;
    self.currentColumn = 0;
    
    [self write:[@"" stringByPaddingToLength:self.indentationLevel*2 withString:@" " startingAtIndex:0]];
}

- (void)write:(NSString *)generated {
    [self.mutableString appendString:generated];
    self.currentColumn += [generated length];
    
    /*NSArray *lines = [generated componentsSeparatedByString:@"\n"];
    
    if([lines count] == 1) {
        [self.mutableString appendString:generated];
        self.currentColumn += [generated length];
    }
    else {
        NSString *line = nil;
        for(NSInteger i = 0; i < [lines count]; ++i) {
            line = lines[i];
            line = (i == 0) ? line : [line stringByPaddingToLength:[line length]+self.indentationLevel*2 withString:@" " startingAtIndex:0];
            line = (i == [lines count]-1) ? line : [line stringByAppendingString:@"\n"];
            
            [self.mutableString appendString:line];
        }
        
        self.currentLine += [lines count] - 1;
        self.currentColumn = [line length];
    }*/
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
            
            for(LXNodeNew *node in value) {
                [[self mutableChildren] insertObject:node atIndex:index++];
                node.parent = self;
            }            
        }
        else {
            NSInteger index = [[self children] indexOfObject:currentValue];
            
            [[self mutableChildren] removeObject:currentValue];
            [[self mutableChildren] insertObject:value atIndex:index];
            
            LXNodeNew *node = value;
            node.parent = self;
        }
    }
    else {
        if([value isKindOfClass:[NSArray class]]) {
            for(LXNodeNew *node in value) {
                [[self mutableChildren] addObject:node];
                node.parent = self;
            }
        }
        else {
            [[self mutableChildren] addObject:value];
            
            LXNodeNew *node = value;
            node.parent = self;
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

- (NSRange)range {
    return NSMakeRange(self.location, self.length);
}

- (void)resolveVariables:(LXContext *)context {}
- (void)resolveTypes:(LXContext *)context {}

BOOL rangeInside(NSRange range1, NSRange range2) {
    if(range2.location < range1.location)
        return NO;
    
    if(NSMaxRange(range2) > NSMaxRange(range1))
        return NO;
    
    return YES;
}

- (void)verify {
    NSRange range = self.range;
    
    for(LXNodeNew *child in self.children) {
        if(!rangeInside(range, child.range)) {
            NSLog(@"%@ - %@ : %@ - %@", [self class], NSStringFromRange(range), [child class], NSStringFromRange(child.range));
        }
    }
    
    for(LXNodeNew *child in self.children) {
        [child verify];
    }
}

- (LXNodeNew *)closestNode:(NSInteger)location {
    if([self.children count] == 0)
        return self;
    
    NSInteger closestDistance = NSIntegerMax;
    LXNodeNew *closestChild = nil;
    
    for(LXNodeNew *child in self.children) {
        if(location < child.location) {
            NSInteger distance = child.location - location;
            
            if(distance < closestDistance) {
                closestDistance = distance;
                closestChild = child;
            }
        }
        else if(location > NSMaxRange(child.range)) {
            NSInteger distance = location - NSMaxRange(child.range);
            
            if(distance < closestDistance) {
                closestDistance = distance;
                closestChild = child;
            }
        }
        else {
            closestDistance = 0;
            closestChild = child;
            break;
        }
    }
    
    if(closestDistance > 0)
        return closestChild;
    else
        return [closestChild closestNode:location];
}

- (void)print:(NSInteger)indent {
    NSLog(@"%@%@ : %ld - %ld", [@"" stringByPaddingToLength:indent withString:@" " startingAtIndex:0], [self class], self.line, self.column);
    
    for(LXNodeNew *child in self.children) {
        [child print:indent+1];
    }
}

- (void)compile:(LXLuaWriter *)writer {}

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

- (void)print:(NSInteger)indent {
    NSLog(@"%@%@", [@"" stringByPaddingToLength:indent withString:@" " startingAtIndex:0], self.value);
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:self.value line:self.line column:self.column];
}

@end

@implementation LXExpr
@end

@implementation LXBoxedExpr
@dynamic leftParenToken, expr, rightParenToken;

- (void)resolveTypes:(LXContext *)context {
    [self.expr resolveTypes:context];
    self.resultType = self.expr.resultType;
}

- (void)compile:(LXLuaWriter *)writer {
    [self.leftParenToken compile:writer];
    [self.expr compile:writer];
    [self.rightParenToken compile:writer];
}

@end

@implementation LXNumberExpr
@dynamic token;

- (void)resolveTypes:(LXContext *)context {
    self.resultType = [LXVariable variableWithType:[LXClassNumber classNumber]];
}

- (void)compile:(LXLuaWriter *)writer {
    [self.token compile:writer];
}

@end

@implementation LXStringExpr
@dynamic token;

- (void)resolveTypes:(LXContext *)context {
    self.resultType = [LXVariable variableWithType:[LXClassString classString]];
}

- (void)compile:(LXLuaWriter *)writer {
    [self.token compile:writer];
}

@end

@implementation LXNilExpr
@dynamic nilToken;

- (void)resolveTypes:(LXContext *)context {
    self.resultType = nil;
}

- (void)compile:(LXLuaWriter *)writer {
    [self.nilToken compile:writer];
}

@end

@implementation LXBoolExpr
@dynamic token;

- (void)resolveTypes:(LXContext *)context {
    self.resultType = [LXVariable variableWithType:[LXClassBool classBool]];
}

- (void)compile:(LXLuaWriter *)writer {
    [self.token compile:writer];
}

@end

@implementation LXDotsExpr
@dynamic dotsToken;

- (void)compile:(LXLuaWriter *)writer {
    [self.dotsToken compile:writer];
}

@end

@implementation LXVariableExpr
@dynamic token;

- (void)resolveTypes:(LXContext *)context {
    LXVariable *variable = [context.currentScope variable:self.token.value];
    
    if(!variable) {
        [context addError:[NSString stringWithFormat:@"Variable %@ is undefined.", self.token.value] range:self.token.range line:self.token.line column:self.token.column];
    }
    
    self.resultType = variable;
}

- (void)compile:(LXLuaWriter *)writer {
    LXVariable *variable = self.resultType;
    
    if(variable.isMember) {
        [writer write:@"self."];
    }
    
    [writer write:self.token.value name:self.token.value line:self.line column:self.column];
}

@end

@implementation LXDeclarationNode
@dynamic type, var;

- (void)compile:(LXLuaWriter *)writer {
    [self.var compile:writer];
}

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

- (void)resolveTypes:(LXContext *)context {
    self.resultType = [LXVariable variableWithType:[LXClassTable classTable]];
}

@end

@implementation LXMemberExpr
@dynamic prefix, memberToken, value;

+ (LXMemberExpr *)memberExpressionWithPrefix:(LXExpr *)prefix {
    LXMemberExpr *memberExpr = [[LXMemberExpr alloc] init];
    memberExpr.line = prefix.line;
    memberExpr.column = prefix.column;
    memberExpr.location = prefix.location;
    memberExpr.prefix = prefix;
    
    return memberExpr;
}

- (void)resolveVariables:(LXContext *)context {
    [self.prefix resolveVariables:context];
}

- (void)resolveTypes:(LXContext *)context {
    [self.prefix resolveTypes:context];
    
    for(LXVariable *variable in self.prefix.resultType.type.variables) {
        if([variable.name isEqualToString:self.value.value]) {
            self.resultType = variable;
            break;
        }
    }
}

- (void)compile:(LXLuaWriter *)writer {
    [self.prefix compile:writer];
    [self.memberToken compile:writer];
    [self.value compile:writer];
}

@end

@implementation LXIndexExpr
@dynamic prefix, leftBracketToken, expr, rightBracketToken;

+ (LXIndexExpr *)indexExpressionWithPrefix:(LXExpr *)prefix {
    LXIndexExpr *indexExpr = [[LXIndexExpr alloc] init];
    indexExpr.line = prefix.line;
    indexExpr.column = prefix.column;
    indexExpr.location = prefix.location;
    indexExpr.prefix = prefix;
    
    return indexExpr;
}

- (void)resolveVariables:(LXContext *)context {
    [self.prefix resolveVariables:context];
    [self.expr resolveVariables:context];
}

- (void)resolveTypes:(LXContext *)context {
    [self.prefix resolveTypes:context];
    [self.expr resolveTypes:context];
}


- (void)compile:(LXLuaWriter *)writer {
    [self.prefix compile:writer];
    [self.leftBracketToken compile:writer];
    [self.expr compile:writer];
    [self.rightBracketToken compile:writer];
}

@end

@implementation LXFunctionCallExpr
@dynamic prefix, memberToken, value, leftParenToken, args, rightParenToken;

+ (LXFunctionCallExpr *)functionCallWithPrefix:(LXExpr *)prefix {
    LXFunctionCallExpr *functionCall = [[LXFunctionCallExpr alloc] init];
    functionCall.line = prefix.line;
    functionCall.column = prefix.column;
    functionCall.location = prefix.location;
    functionCall.prefix = prefix;
    
    return functionCall;
}

- (void)resolveVariables:(LXContext *)context {    
    [self.prefix resolveVariables:context];
    
    for(LXExpr *expr in self.args) {
        [expr resolveVariables:context];
    }
}

- (void)resolveTypes:(LXContext *)context {
    [self.prefix resolveTypes:context];
    
    for(LXExpr *expr in self.args) {
        [expr resolveTypes:context];
    }
    
    if([self.prefix isKindOfClass:[LXVariableExpr class]]) {
        self.resultType = self.prefix.resultType.returnTypes.firstObject;
    }
    else {
        for(LXVariable *function in self.prefix.resultType.type.functions) {
            if([function.name isEqualToString:self.value.value]) {
                self.resultType = function.returnTypes.firstObject;
                break;
            }
        }
    }
}

- (void)compile:(LXLuaWriter *)writer {
    [self.prefix compile:writer];
    [self.memberToken compile:writer];
    [self.value compile:writer];
    [self.leftParenToken compile:writer];
    
    for(LXNodeNew *arg in self.args) {
        [arg compile:writer];
    }
    
    [self.rightParenToken compile:writer];
}

@end

@implementation LXUnaryExpr
@dynamic opToken, expr;

- (void)resolveVariables:(LXContext *)context {
    [self.expr resolveVariables:context];
}

- (void)resolveTypes:(LXContext *)context {
    [self.expr resolveTypes:context];
    
    self.resultType = self.expr.resultType;
}

- (void)compile:(LXLuaWriter *)writer {
    [self.opToken compile:writer];
    [self.expr compile:writer];
}

@end

@implementation LXBinaryExpr
@dynamic lhs, opToken, rhs;

+ (LXBinaryExpr *)binaryExprWithExpr:(LXExpr *)expr {
    LXBinaryExpr *binaryExpr = [[LXBinaryExpr alloc] init];
    binaryExpr.line = expr.line;
    binaryExpr.column = expr.column;
    binaryExpr.location = expr.location;
    binaryExpr.lhs = expr;
    
    return binaryExpr;
}

- (void)resolveVariables:(LXContext *)context {
    [self.lhs resolveVariables:context];
    [self.rhs resolveVariables:context];
}

- (void)resolveTypes:(LXContext *)context {
    [self.lhs resolveTypes:context];
    [self.rhs resolveTypes:context];
    
    //TODO: Find the type resulting from the operation
    self.resultType = self.lhs.resultType;
}

- (void)compile:(LXLuaWriter *)writer {
    [self.lhs compile:writer];
    [self.opToken compile:writer];
    [self.rhs compile:writer];
}

@end

@implementation LXFunctionReturnTypes
@dynamic leftParenToken, returnTypes, rightParenToken;

+ (LXFunctionReturnTypes *)returnTypes:(NSArray *)types leftToken:(LXTokenNode *)leftToken rightToken:(LXTokenNode *)rightToken {
    LXFunctionReturnTypes *returnTypes = [[LXFunctionReturnTypes alloc] init];
    returnTypes.leftParenToken = leftToken;
    returnTypes.returnTypes = types;
    returnTypes.rightParenToken = rightToken;
    returnTypes.line = leftToken.line;
    returnTypes.column = leftToken.column;
    returnTypes.location = leftToken.location;
    returnTypes.length = NSMaxRange(rightToken.range) - leftToken.location;

    return returnTypes;
}

@end

@implementation LXFunctionArguments
@dynamic leftParenToken, args, rightParenToken;

+ (LXFunctionArguments *)arguments:(NSArray *)args leftToken:(LXTokenNode *)leftToken rightToken:(LXTokenNode *)rightToken {
    LXFunctionArguments *arguments = [[LXFunctionArguments alloc] init];
    arguments.leftParenToken = leftToken;
    arguments.args = args;
    arguments.rightParenToken = rightToken;
    arguments.line = leftToken.line;
    arguments.column = leftToken.column;
    arguments.location = leftToken.location;
    arguments.length = NSMaxRange(rightToken.range) - leftToken.location;
    
    return arguments;
}

- (void)compile:(LXLuaWriter *)writer {
    [self.leftParenToken compile:writer];
    
    for(LXNodeNew *node in self.args) {
        [node compile:writer];
    }
    
    [self.rightParenToken compile:writer];
}

@end

@implementation LXFunctionExpr
@dynamic scopeToken, staticToken, functionToken, returnTypes, nameExpr, args, body, endToken;

- (void)resolveVariables:(LXContext *)context {
    self.scope = [context createScope:NO];

    if(self.nameExpr) {
        LXScope *scope = self.isGlobal ? context.compiler.globalScope : self.scope.parent;
        LXVariable *variable = [scope localVariable:self.nameExpr.value];
        
        if(variable) {
            [context addError:[NSString stringWithFormat:@"Variable %@ is already defined.", self.nameExpr.value] range:self.nameExpr.range line:self.nameExpr.line column:self.nameExpr.column];
        }
        else {
            variable = [scope createFunction:self.nameExpr.value];
            variable.definedLocation = self.nameExpr.location;
            
            NSMutableArray *mutableReturnTypes = [[NSMutableArray alloc] init];
            for(LXTokenNode *node in self.returnTypes.returnTypes) {
                if([node.value isEqualToString:@","])
                    continue;
                
                LXClass *type = [context findType:node.value];
                [mutableReturnTypes addObject:[LXVariable variableWithType:type]];
            }
            
            NSMutableArray *mutableArguments = [[NSMutableArray alloc] init];
            for(LXDeclarationNode *node in self.args.args) {
                if(![node isKindOfClass:[LXDeclarationNode class]])
                    continue;
                
                LXClass *type = [context findType:node.type.value];
                LXVariable *variable = [self.scope localVariable:node.var.value];
                
                if(variable) {
                    [context addError:[NSString stringWithFormat:@"Variable %@ is already defined.", node.var.value] range:node.var.range line:node.var.line column:node.var.column];
                }
                else {
                    variable = [self.scope createVariable:node.var.value type:type];
                    variable.definedLocation = node.var.location;
                    
                    [mutableArguments addObject:variable];
                }
            }
            
            variable.returnTypes = mutableReturnTypes;
            variable.arguments = mutableArguments;
            
            if(self.isGlobal) {
                //TODO: Keep track of globals
            }
        }
    }
    
    [self.body resolveVariables:context];
    
    [context popScope];
}

- (void)resolveTypes:(LXContext *)context {
    [context pushScope:self.scope];
    /*if(self.nameExpr) {
        [self.nameExpr resolveTypes:context];
    }*/
    
    [self.body resolveTypes:context];
    
    self.resultType = [LXVariable variableWithType:[LXClassFunction classFunction]];
    [context popScope];
}

- (void)compile:(LXLuaWriter *)writer {
    [self compile:writer class:nil];
}

- (void)compile:(LXLuaWriter *)writer class:(LXClass *)class {
    if(!class && !self.isGlobal && self.nameExpr) {
        if(self.scopeToken) {
            [self.scopeToken compile:writer];
        }
        else {
            [writer write:@"local"];
        }
        
        [writer writeSpace];
    }
    
    [self.functionToken compile:writer];
    
    if(self.nameExpr) {
        [writer writeSpace];
        
        if(class) {
            [writer write:class.name];
            [writer write:@":"];
        }
        
        [self.nameExpr compile:writer];
    }
    
    [self.args compile:writer];
    
    if([self.body.stmts count]) {
        writer.indentationLevel++;
        [writer writeNewline];
        [self.body compile:writer];
        writer.indentationLevel--;
    }
    
    [writer writeNewline];
    [self.endToken compile:writer];
}

@end

@implementation LXStmt
@end

@implementation LXEmptyStmt
@dynamic token;

- (void)compile:(LXLuaWriter *)writer {
    [self.token compile:writer];
}

@end

@implementation LXBlock
@dynamic stmts;

- (void)resolveVariables:(LXContext *)context {
    self.scope = [context createScope:YES];
    
    for(LXStmt *statement in self.stmts) {
        [statement resolveVariables:context];
    }
    
    [context popScope];
}

- (void)resolveTypes:(LXContext *)context {
    [context pushScope:self.scope];
    
    for(LXStmt *statement in self.stmts) {
        [statement resolveTypes:context];
    }
    
    [context popScope];
}

- (void)compile:(LXLuaWriter *)writer {
    for(LXStmt *statement in self.stmts) {
        [statement compile:writer];
        
        if(statement != self.stmts.lastObject)
            [writer writeNewline];
    }
}

@end

@implementation LXClassStmt
@dynamic classToken, nameToken, extendsToken, superToken, vars, functions, endToken;

- (void)resolveVariables:(LXContext *)context {
    if(self.superToken) {
        [context findType:self.superToken.value];
    }
    
    self.type = [context findType:self.nameToken.value];
    
    if(self.type.isDefined) {
        [context addError:[NSString stringWithFormat:@"Class %@ is already defined.", self.nameToken.value] range:self.nameToken.range line:self.nameToken.line column:self.nameToken.column];
    }
    else {
        [context declareType:self.type];
        self.type.isDefined = YES;
    }
    
    self.scope = [context createScope:YES];

    for(LXDeclarationStmt *stmt in self.vars) {
        [stmt resolveVariables:context];
    }
    
    for(LXExprStmt *stmt in self.functions) {
        [stmt resolveVariables:context];
    }
    
    [context popScope];
    
    NSMutableArray *mutableVariables = [[NSMutableArray alloc] init];
    NSMutableArray *mutableFunctions = [[NSMutableArray alloc] init];

    for(LXVariable *variable in self.scope.localVariables) {
        variable.isMember = YES;
        
        if(variable.isFunction) {
            [mutableFunctions addObject:variable];
        }
        else {
            [mutableVariables addObject:variable];
        }
    }
    
    self.type.variables = mutableVariables;
    self.type.functions = mutableFunctions;
}

- (void)resolveTypes:(LXContext *)context {
    if(self.superToken) {
        LXClass *type = [context findType:self.superToken.value];
        
        if(!type.isDefined) {
            [context addError:[NSString stringWithFormat:@"Type %@ is undefined.", self.superToken.value] range:self.superToken.range line:self.superToken.line column:self.superToken.column];
        }
    }
    
    [context pushScope:self.scope];
    
    for(LXDeclarationStmt *stmt in self.vars) {
        [stmt resolveTypes:context];
    }
    
    for(LXExprStmt *stmt in self.functions) {
        [stmt resolveTypes:context];
    }
    
    [context popScope];
}

- (void)compile:(LXLuaWriter *)writer {
    if(self.type.parent) {
        [writer write:[NSString stringWithFormat:@"%@ = %@ or setmetatable({}, {__call = function(class, ...)", self.type.name, self.type.name]];
        [writer writeNewline];
        [writer write:[NSString stringWithFormat:@"  local obj = setmetatable({class = \"%@\", super = %@}, {__index = class})", self.type.name, self.type.parent.name]];
        [writer writeNewline];
        [writer write:[NSString stringWithFormat:@"  obj:init(...)"]];
        [writer writeNewline];
        [writer write:[NSString stringWithFormat:@"  return obj"]];
        [writer writeNewline];
        [writer write:[NSString stringWithFormat:@"end})"]];
        [writer writeNewline];

        [writer write:[NSString stringWithFormat:@"for k, v in pairs(%@) do", self.type.parent.name]];
        [writer writeNewline];
        [writer write:[NSString stringWithFormat:@"  %@[k] = v", self.type.name]];
        [writer writeNewline];
        [writer write:[NSString stringWithFormat:@"end"]];
        [writer writeNewline];

        /*[writer write:[NSString stringWithFormat:@"function %@:init(...)", name]];
        [writer writeNewline];
        [writer write:[NSString stringWithFormat:@"%@.init(self, ...)", superclass]];
        [writer writeNewline];*/
    }
    else {
        [writer write:[NSString stringWithFormat:@"%@ = %@ or setmetatable({}, {__call = function(class, ...)", self.type.name, self.type.name]];
        [writer writeNewline];
        [writer write:[NSString stringWithFormat:@"  local obj = setmetatable({class = \"%@\"}, {__index = class})", self.type.name]];
        [writer writeNewline];
        [writer write:[NSString stringWithFormat:@"  return obj"]];
        [writer writeNewline];
        [writer write:[NSString stringWithFormat:@"end})"]];
        [writer writeNewline];
        
        /*[writer write:[NSString stringWithFormat:@"function %@:init(...)", name]];
        [writer writeNewline];*/
    }
    
    for(LXFunctionExpr *function in self.functions) {
        [function compile:writer class:self.type];
        [writer writeNewline];
    }
}

@end

@implementation LXIfStmt
@dynamic ifToken, expr, thenToken, body, elseIfStmts, elseToken, elseStmt, endToken;

- (void)resolveVariables:(LXContext *)context {
    [self.expr resolveVariables:context];
    [self.body resolveVariables:context];

    for(LXElseIfStmt *stmt in self.elseIfStmts) {
        [stmt resolveVariables:context];
    }
    
    [self.elseStmt resolveVariables:context];
}

- (void)resolveTypes:(LXContext *)context {
    [self.expr resolveTypes:context];
    [self.body resolveTypes:context];
    
    for(LXElseIfStmt *stmt in self.elseIfStmts) {
        [stmt resolveTypes:context];
    }
    
    [self.elseStmt resolveTypes:context];
}

- (void)compile:(LXLuaWriter *)writer {
    [self.ifToken compile:writer];
    [writer writeSpace];
    [self.expr compile:writer];
    [writer writeSpace];
    [self.thenToken compile:writer];
    
    if([self.body.stmts count]) {
        writer.indentationLevel++;
        [writer writeNewline];
        [self.body compile:writer];
        writer.indentationLevel--;
    }
    
    [writer writeNewline];

    for(LXElseIfStmt *stmt in self.elseIfStmts) {
        [stmt compile:writer];
        [writer writeNewline];
    }
    
    if(self.elseToken) {
        [self.elseToken compile:writer];
        writer.indentationLevel++;
        [writer writeNewline];
        [self.elseStmt compile:writer];
        writer.indentationLevel--;
        [writer writeNewline];
    }

    [self.endToken compile:writer];
}

@end

@implementation LXElseIfStmt
@dynamic elseIfToken, expr, thenToken, body;

- (void)resolveVariables:(LXContext *)context {
    [self.expr resolveVariables:context];
    [self.body resolveVariables:context];
}

- (void)resolveTypes:(LXContext *)context {
    [self.expr resolveTypes:context];
    [self.body resolveTypes:context];
}

- (void)compile:(LXLuaWriter *)writer {
    [self.elseIfToken compile:writer];
    [writer writeSpace];
    [self.expr compile:writer];
    [writer writeSpace];
    [self.thenToken compile:writer];
    
    if([self.body.stmts count]) {
        writer.indentationLevel++;
        [writer writeNewline];
        [self.body compile:writer];
        writer.indentationLevel--;
    }
}

@end

@implementation LXWhileStmt
@dynamic whileToken, expr, doToken, body, endToken;

- (void)resolveVariables:(LXContext *)context {
    [self.expr resolveVariables:context];
    [self.body resolveVariables:context];
}

- (void)resolveTypes:(LXContext *)context {
    [self.expr resolveTypes:context];
    [self.body resolveTypes:context];
}

- (void)compile:(LXLuaWriter *)writer {
    [self.whileToken compile:writer];
    [writer writeSpace];
    [self.expr compile:writer];
    [writer writeSpace];
    [self.doToken compile:writer];
    
    if([self.body.stmts count]) {
        writer.indentationLevel++;
        [writer writeNewline];
        [self.body compile:writer];
        writer.indentationLevel--;
    }
  
    [writer writeNewline];
    [self.endToken compile:writer];
}

@end

@implementation LXDoStmt
@dynamic doToken, body, endToken;

- (void)resolveVariables:(LXContext *)context {
    [self.body resolveVariables:context];
}

- (void)resolveTypes:(LXContext *)context {
    [self.body resolveTypes:context];
}

- (void)compile:(LXLuaWriter *)writer {
    [self.doToken compile:writer];
    
    if([self.body.stmts count]) {
        writer.indentationLevel++;
        [writer writeNewline];
        [self.body compile:writer];
        writer.indentationLevel--;
    }

    [writer writeNewline];
    [self.endToken compile:writer];
}

@end

@implementation LXForStmt
@dynamic forToken, doToken, body, endToken;

+ (instancetype)forStatementWithToken:(LXTokenNode *)forToken {
    LXForStmt *statement = [[self alloc] init];
    statement.line = forToken.line;
    statement.column = forToken.column;
    statement.location = forToken.location;
    statement.forToken = forToken;
    
    return statement;
}

@end

@implementation LXNumericForStmt
@dynamic equalsToken, exprInit, exprCondCommaToken, exprCond, exprIncCommaToken, exprInc;
@end

@implementation LXIteratorForStmt
@end

@implementation LXRepeatStmt
@dynamic repeatToken, body, untilToken, expr;

- (void)resolveVariables:(LXContext *)context {
    [self.body resolveVariables:context];
    [self.expr resolveVariables:context];
}

- (void)resolveTypes:(LXContext *)context {
    [self.body resolveTypes:context];
    [self.expr resolveTypes:context];
}

- (void)compile:(LXLuaWriter *)writer {
    [self.repeatToken compile:writer];
    
    if([self.body.stmts count]) {
        writer.indentationLevel++;
        [writer writeNewline];
        [self.body compile:writer];
        writer.indentationLevel--;
    }

    [writer writeNewline];
    [self.untilToken compile:writer];
    [self.expr compile:writer];
}

@end

@implementation LXLabelStmt
@dynamic beginLabelToken, endLabelToken;

- (void)compile:(LXLuaWriter *)writer {
    [self.beginLabelToken compile:writer];
    [writer writeSpace];
    //[self.value compile:writer];
    [writer writeSpace];
    [self.endLabelToken compile:writer];
}

@end

@implementation LXGotoStmt
@dynamic gotoToken;

- (void)compile:(LXLuaWriter *)writer {
    [self.gotoToken compile:writer];
    [writer writeSpace];
}

@end

@implementation LXBreakStmt
@dynamic breakToken;

- (void)compile:(LXLuaWriter *)writer {
    [self.breakToken compile:writer];
}

@end

@implementation LXReturnStmt
@dynamic returnToken, exprs;

- (void)resolveVariables:(LXContext *)context {
    for(LXExpr *expr in self.exprs) {
        [expr resolveVariables:context];
    }
}

- (void)resolveTypes:(LXContext *)context {
    for(LXExpr *expr in self.exprs) {
        [expr resolveTypes:context];
    }
}

- (void)compile:(LXLuaWriter *)writer {
    [self.returnToken compile:writer];
    [writer writeSpace];

    for(LXExpr *expr in self.exprs) {
        [expr compile:writer];
    }
}

@end

@implementation LXDeclarationStmt
@dynamic scopeToken, typeToken, vars, equalsToken, exprs;

- (void)resolveVariables:(LXContext *)context {
    LXClass *type = [context findType:self.typeToken.value];
    
    for(LXTokenNode *node in self.vars) {
        if([node.value isEqualToString:@","])
            continue;
        
        LXScope *scope = self.isGlobal ? context.compiler.globalScope : context.currentScope;
        LXVariable *variable = [scope localVariable:node.value];
        
        if(variable) {
            [context addError:[NSString stringWithFormat:@"Variable %@ is already defined.", node.value] range:node.range line:node.line column:node.column];
        }
        else {
            variable = [scope createVariable:node.value type:type];
            variable.definedLocation = node.location;
            
            if(self.isGlobal) {
                //TODO: Keep track of globals
            }
        }
    }
    
    for(LXExpr *expr in self.exprs) {
        [expr resolveVariables:context];
    }
}

- (void)resolveTypes:(LXContext *)context {
    LXClass *type = [context findType:self.typeToken.value];

    if(!type.isDefined) {
        [context addError:[NSString stringWithFormat:@"Type %@ is undefined.", self.typeToken.value] range:self.typeToken.range line:self.typeToken.line column:self.typeToken.column];
    }
    
    for(LXExpr *expr in self.exprs) {
        [expr resolveTypes:context];
    }
}

- (void)compile:(LXLuaWriter *)writer {
    if(!self.isGlobal) {
        if(self.scopeToken) {
            [self.scopeToken compile:writer];
        }
        else {
            [writer write:@"local"];
        }
        
        [writer writeSpace];
    }
    
    for(LXNodeNew *node in self.vars) {
        [node compile:writer];
    }
    
    [self.equalsToken compile:writer];
    
    for(LXNodeNew *node in self.exprs) {
        [node compile:writer];
    }
}

@end

@implementation LXAssignmentStmt
@dynamic vars, equalsToken, exprs;

- (void)resolveVariables:(LXContext *)context {
    for(LXExpr *expr in self.vars) {
        [expr resolveVariables:context];
    }
     
    for(LXExpr *expr in self.exprs) {
        [expr resolveVariables:context];
    }
}

- (void)resolveTypes:(LXContext *)context {
    for(LXExpr *expr in self.vars) {
        [expr resolveTypes:context];
    }
    
    for(LXExpr *expr in self.exprs) {
        [expr resolveTypes:context];
    }
}

- (void)compile:(LXLuaWriter *)writer {
    for(LXNodeNew *node in self.vars) {
        [node compile:writer];
    }
    
    [self.equalsToken compile:writer];
    
    for(LXNodeNew *node in self.exprs) {
        [node compile:writer];
    }
}

@end

@implementation LXExprStmt
@dynamic expr;

- (void)resolveVariables:(LXContext *)context {
    [self.expr resolveVariables:context];
}

- (void)resolveTypes:(LXContext *)context {
    [self.expr resolveTypes:context];
}

- (void)compile:(LXLuaWriter *)writer {
    [self.expr compile:writer];
}

@end