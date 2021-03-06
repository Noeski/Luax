//
//  LXNode.m
//  LuaX
//
//  Created by Noah Hilt on 8/11/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import <objc/objc-runtime.h>

#import "LXNode.h"
#import "LXCompiler.h"
#import "LXLuaWriter.h"

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
@property (nonatomic, strong) NSMutableDictionary *mutableProperties;
@end

@implementation LXNode

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
            
            for(LXNode *node in value) {
                [[self mutableChildren] insertObject:node atIndex:index++];
                node.parent = self;
            }            
        }
        else {
            NSInteger index = [[self children] indexOfObject:currentValue];
            
            [[self mutableChildren] removeObject:currentValue];
            
            if(value) {
                [[self mutableChildren] insertObject:value atIndex:index];
                
                LXNode *node = value;
                node.parent = self;
            }
        }
    }
    else if(value) {
        if([value isKindOfClass:[NSArray class]]) {
            for(LXNode *node in value) {
                [[self mutableChildren] addObject:node];
                node.parent = self;
            }
        }
        else {
            [[self mutableChildren] addObject:value];
            
            LXNode *node = value;
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
    
    for(LXNode *child in self.children) {
        if(!rangeInside(range, child.range)) {
            NSLog(@"%@ - %@ : %@ - %@", [self class], NSStringFromRange(range), [child class], NSStringFromRange(child.range));
        }
    }
    
    for(LXNode *child in self.children) {
        [child verify];
    }
}

- (LXTokenNode *)closestCompletionNode:(NSInteger)location {
    if([self isKindOfClass:[LXTokenNode class]]) {
        LXTokenNode *node = (LXTokenNode *)self;
        
        return node;
    }
    
    NSInteger closestDistance = NSIntegerMax;
    LXNode *closestChild = nil;
    
    for(LXNode *child in self.children) {
        if(location <= child.location) {
            continue;
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
    
    return [closestChild closestCompletionNode:location];
}

- (void)print:(NSInteger)indent {
    NSLog(@"%@%@ : %ld - %ld", [@"" stringByPaddingToLength:indent withString:@" " startingAtIndex:0], [self class], self.line, self.column);
    
    for(LXNode *child in self.children) {
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

- (void)setPrev:(LXTokenNode *)prev {
    _prev = prev;
    _prev.next = self;
}

- (BOOL)isKeyword {
    return (self.tokenType >= FIRST_RESERVED && self.tokenType < LX_TK_CONCAT);
}

- (BOOL)isReserved {
    return ((self.tokenType) == LX_TK_NAME ||
            (self.tokenType >= FIRST_RESERVED && self.tokenType < LX_TK_CONCAT) ||
            (self.tokenType >= LX_TK_TYPE_VAR && self.tokenType < LX_TK_CLASS));
}

- (void)print:(NSInteger)indent {
    NSLog(@"%@%@", [@"" stringByPaddingToLength:indent withString:@" " startingAtIndex:0], self.value);
}

- (void)compile:(LXLuaWriter *)writer {
    if(self.tokenType == LX_TK_NAME) {
        [writer write:self.value name:self.value line:self.line column:self.column];
    }
    else {
        [writer write:self.value line:self.line column:self.column];    
    }
}

- (LXScope *)scope {
    LXScope *scope = nil;
    id parent = self.parent;
    
    while(parent) {
        if([parent respondsToSelector:@selector(scope)]) {
            scope = [parent scope];
            
            if(scope)
                break;
        }
        
        parent = [parent parent];
    }
    
    return scope;
}

@end

@implementation LXExpr
@end

@implementation LXBoxedExpr
@dynamic leftParenToken, expr, rightParenToken;

- (void)resolveTypes:(LXContext *)context {
    [self.expr resolveTypes:context];
    self.resultType = self.expr.resultType;
    
    self.leftParenToken.completionFlags = LXTokenCompletionFlagsVariables;
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
    self.token ? [self.token compile:writer] : [writer write:@"0"];
}

@end

@implementation LXStringExpr
@dynamic token;

- (void)resolveTypes:(LXContext *)context {
    self.resultType = [LXVariable variableWithType:[LXClassString classString]];
}

- (void)compile:(LXLuaWriter *)writer {
    self.token ? [self.token compile:writer] : [writer write:@"\"\""];
}

@end

@implementation LXNilExpr
@dynamic nilToken;

- (void)resolveTypes:(LXContext *)context {
    self.resultType = nil;
}

- (void)compile:(LXLuaWriter *)writer {
    self.nilToken ? [self.nilToken compile:writer] : [writer write:@"nil"];
}

@end

@implementation LXBoolExpr
@dynamic token;

- (void)resolveTypes:(LXContext *)context {
    self.resultType = [LXVariable variableWithType:[LXClassBool classBool]];
}

- (void)compile:(LXLuaWriter *)writer {
    self.token ? [self.token compile:writer] : [writer write:@"false"];
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
        [context addWarning:[NSString stringWithFormat:@"Variable %@ is undefined.", self.token.value] range:self.token.range line:self.token.line column:self.token.column];
    }
    
    self.resultType = variable;
}

- (void)compile:(LXLuaWriter *)writer {
    LXVariable *variable = self.resultType;
    
    if(variable.isMember) {
        [writer write:@"self"];
        
        if(variable.isFunction) {
            [writer write:@":"];
        }
        else {
            [writer write:@"."];
        }
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
@dynamic key, assignmentToken, value;

- (void)resolveVariables:(LXContext *)context {
    [self.value resolveVariables:context];
}

- (void)resolveTypes:(LXContext *)context {
    [self.value resolveTypes:context];
}

- (void)compile:(LXLuaWriter *)writer {
    [self.key compile:writer];
    [self.assignmentToken compile:writer];
    [self.value compile:writer];
}

@end

@implementation LXIndexedKVP
@dynamic leftBracketToken, key, rightBracketToken, assignmentToken, value;

- (void)resolveVariables:(LXContext *)context {
    [self.key resolveVariables:context];
    [self.value resolveVariables:context];
}

- (void)resolveTypes:(LXContext *)context {
    [self.key resolveTypes:context];
    [self.value resolveTypes:context];
}

- (void)compile:(LXLuaWriter *)writer {
    [self.leftBracketToken compile:writer];
    [self.key compile:writer];
    [self.rightBracketToken compile:writer];
    [self.assignmentToken compile:writer];
    [self.value compile:writer];
}

@end

@implementation LXTableCtorExpr
@dynamic leftBraceToken, keyValuePairs, rightBraceToken;

- (void)resolveVariables:(LXContext *)context {
    for(LXNode *node in self.keyValuePairs) {
        [node resolveVariables:context];
    }
}

- (void)resolveTypes:(LXContext *)context {
    for(LXNode *node in self.keyValuePairs) {
        [node resolveTypes:context];
    }
    
    self.resultType = [LXVariable variableWithType:[LXClassTable classTable]];
}

- (void)compile:(LXLuaWriter *)writer {
    [self.leftBraceToken compile:writer];
    for(LXNode *node in self.keyValuePairs) {
        [node compile:writer];
    }
    [self.rightBraceToken compile:writer];
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
    
    self.memberToken.completionFlags = LXTokenCompletionFlagsMembers;
    self.memberToken.type = self.prefix.resultType.type;
    self.value.isMember = YES;
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
    
    self.leftBracketToken.completionFlags = LXTokenCompletionFlagsVariables;
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
        self.resultType = self.prefix.resultType;
    }
    else {
        for(LXVariable *function in self.prefix.resultType.type.functions) {
            if([function.name isEqualToString:self.value.value]) {
                self.resultType = function.returnTypes.firstObject;
                break;
            }
        }
    }
    
    self.memberToken.completionFlags = LXTokenCompletionFlagsFunctions;
    self.memberToken.type = self.prefix.resultType.type;
    self.value.isMember = YES;
    self.leftParenToken.completionFlags = LXTokenCompletionFlagsVariables;
}

- (void)compile:(LXLuaWriter *)writer {
    BOOL isSuper = NO;
    
    if([self.prefix isKindOfClass:[LXVariableExpr class]]) {
        LXVariableExpr *expr = (LXVariableExpr *)self.prefix;
        if([expr.token.value isEqualToString:@"super"]) {
            isSuper = YES;
        }
    }
    
    [self.prefix compile:writer];

    if(isSuper) {
        [writer write:@"."];
        [self.value compile:writer];
        [self.leftParenToken compile:writer];
        [writer write:@"self"];
        
        if([self.args count]) {
            [writer write:@","];
        }
    }
    else {
        [self.memberToken compile:writer];
        [self.value compile:writer];
        [self.leftParenToken compile:writer];
    }
    
    for(LXNode *arg in self.args) {
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
    self.opToken.completionFlags = LXTokenCompletionFlagsVariables;
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
    self.opToken.completionFlags = LXTokenCompletionFlagsVariables;
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

- (void)resolveTypes:(LXContext *)context {
    self.leftParenToken.completionFlags = LXTokenCompletionFlagsTypes;
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

- (void)resolveTypes:(LXContext *)context {
    self.leftParenToken.completionFlags = LXTokenCompletionFlagsTypes;
    self.rightParenToken.completionFlags = LXTokenCompletionFlagsBlock;
}

- (void)compile:(LXLuaWriter *)writer {
    [self compile:writer isMeta:NO];
}

- (void)compile:(LXLuaWriter *)writer isMeta:(BOOL)isMeta {
    [self.leftParenToken compile:writer];
    
    if(isMeta) {
        [writer write:@"self"];
        
        if([self.args count]) {
            [writer write:@", "];
        }
    }
    
    for(LXNode *node in self.args) {
        [node compile:writer];
    }
    
    [self.rightParenToken compile:writer];
}

@end

@implementation LXFunctionExpr
@dynamic scopeToken, staticToken, functionToken, returnTypes, nameExpr, args, body, endToken;

- (void)resolveVariables:(LXContext *)context {
    [self resolveVariables:context class:nil];
}

- (void)resolveVariables:(LXContext *)context class:(LXClassStmt *)class {
    if(self.nameExpr) {
        LXScope *scope = self.isGlobal ? context.compiler.globalScope : self.scope.parent;
        LXVariable *variable = [scope localVariable:self.nameExpr.value];
        
        if(variable) {
            [context addError:[NSString stringWithFormat:@"Variable %@ is already defined.", self.nameExpr.value] range:self.nameExpr.range line:self.nameExpr.line column:self.nameExpr.column];
        }
        else {
            variable = self.isGlobal ? [context createGlobalFunction:self.nameExpr.value] : [scope createFunction:self.nameExpr.value];
            variable.definedLocation = self.nameExpr.location;
            
            if(class) {
                [self.scope createVariable:@"self" type:class.type];
            }
            
            NSMutableArray *mutableReturnTypes = [[NSMutableArray alloc] init];
            for(LXTokenNode *node in self.returnTypes.returnTypes) {
                if([node.value isEqualToString:@","])
                    continue;
                
                LXClass *type = [context findType:node.value];
                [mutableReturnTypes addObject:[LXVariable variableWithType:type]];
            }
            
            //TODO: Need to do this anyways for anonymous functions
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
        }
    }
    
    [self.body resolveVariables:context];
}

- (void)resolveTypes:(LXContext *)context {
    [self.returnTypes resolveTypes:context];
    /*if(self.nameExpr) {
     [self.nameExpr resolveTypes:context];
     }*/
    [context pushScope:self.scope];
    [self.args resolveTypes:context];
    [self.body resolveTypes:context];
    
    self.resultType = [LXVariable variableWithType:[LXClassFunction classFunction]];
    [context popScope];
    
    self.endToken.completionFlags = LXTokenCompletionFlagsBlock;
}

- (void)compile:(LXLuaWriter *)writer {
    [self compile:writer class:nil isMeta:NO];
}

- (void)compile:(LXLuaWriter *)writer class:(LXClassStmt *)class isMeta:(BOOL)isMeta {
    if(!class && !isMeta && !self.isGlobal && self.nameExpr) {
        if(self.scopeToken) {
            [self.scopeToken compile:writer];
        }
        else {
            [writer write:@"local"];
        }
        
        [writer writeSpace];
    }
    
    [self.functionToken compile:writer];
    
    BOOL compileInitFunction = NO;
    
    if(self.nameExpr && !isMeta) {
        compileInitFunction = (class && [self.nameExpr.value isEqualToString:@"init"]);
        
        [writer writeSpace];
        
        if(class) {
            [writer write:class.type.name];
            [writer write:@":"];
        }
        
        [self.nameExpr compile:writer];
    }
    
    [self.args compile:writer isMeta:isMeta];
    
    if([self.body.stmts count] || compileInitFunction) {
        writer.indentationLevel++;
        
        if(compileInitFunction) {
            [class compileInitFunction:writer];
        }
        
        if([self.body.stmts count]) {
            [writer writeNewline];
            [self.body compile:writer];
        }
        
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
    [context pushScope:self.scope];

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
    LXClass *parent = nil;
    
    if(self.superToken) {
        parent = [context findType:self.superToken.value];
    }
    
    self.type = [context findType:self.nameToken.value];
    self.type.parent = parent;
    self.type.statement = self;
    
    if(self.type.isDefined) {
        [context addError:[NSString stringWithFormat:@"Class %@ is already defined.", self.nameToken.value] range:self.nameToken.range line:self.nameToken.line column:self.nameToken.column];
    }
    else {
        [context declareType:self.type];
    }
    
    [context pushScope:self.scope];

    LXVariable *super = [self.scope createVariable:@"super" type:parent];
    super.isMember = YES;
    
    for(LXDeclarationStmt *stmt in self.vars) {
        [stmt resolveVariables:context];
    }
    
    for(LXFunctionExpr *stmt in self.functions) {
        [stmt resolveVariables:context class:self];
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
    
    LXVariable *classTable = [context.compiler.globalScope localVariable:self.nameToken.value];
    
    if(classTable) {
        [context addError:[NSString stringWithFormat:@"Global variable %@ is already defined.", self.nameToken.value] range:self.nameToken.range line:self.nameToken.line column:self.nameToken.column];
    }
    else {
        classTable = [context createGlobalVariable:self.nameToken.value type:self.type];
    }
}

- (void)resolveTypes:(LXContext *)context {
    if(self.superToken) {
        LXClass *parent = [context findType:self.superToken.value];
        
        if(!parent.isDefined) {
            [context addWarning:[NSString stringWithFormat:@"Type %@ is undefined.", self.superToken.value] range:self.superToken.range line:self.superToken.line column:self.superToken.column];
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
    
    self.extendsToken.completionFlags = LXTokenCompletionFlagsTypes;
    self.nameToken.completionFlags = LXTokenCompletionFlagsBlock;
    self.superToken.completionFlags = LXTokenCompletionFlagsBlock;
    self.endToken.completionFlags = LXTokenCompletionFlagsBlock;
}

- (void)compile:(LXLuaWriter *)writer {
    NSDictionary *metaTokens = @{@"__add" : @(YES), @"__sub" : @(YES), @"__mul" : @(YES), @"__div" : @(YES), @"__unm" : @(YES), @"__pow" : @(YES), @"__concat" : @(YES)};
    NSMutableArray *functions = [[NSMutableArray alloc] init];
    NSMutableArray *metaFunctions = [[NSMutableArray alloc] init];
    
    for(LXFunctionExpr *function in self.functions) {
        NSString *functionName = function.nameExpr.value;
        
        if(functionName) {
            BOOL isMeta = [metaTokens[functionName] boolValue];
            
            if(isMeta) {
                [metaFunctions addObject:function];
            }
            else {
                [functions addObject:function];
            }
        }
    }
    
    NSString *parent = @"table";
    
    if(self.type.parent) {
        parent = self.type.parent.name;
    }
    
    [writer write:[NSString stringWithFormat:@"%@ = %@ or {}", self.type.name, self.type.name]];
    [writer writeNewline];
    NSString *classMetatable = [NSString stringWithFormat:@"__%@", self.type.name];
    [writer write:[NSString stringWithFormat:@"local %@ = {__index = %@", classMetatable, self.type.name]];
    for(LXFunctionExpr *function in metaFunctions) {
        [writer write:@","];
        [writer writeNewline];
        [function.nameExpr compile:writer];
        [writer write:@"="];
        [function compile:writer class:self isMeta:YES];
    }
    [writer write:@"}"];
    [writer writeNewline];
    [writer write:[NSString stringWithFormat:@"setmetatable(%@, {", self.type.name]];
    [writer writeNewline];
    [writer write:@"__call = function(self, ...)"];
    [writer writeNewline];
    [writer write:[NSString stringWithFormat:@"  local obj = setmetatable({class = \"%@\", super = %@}, %@)", self.type.name, parent, classMetatable] line:self.nameToken.line column:self.nameToken.column];
    [writer writeNewline];
    [writer write:[NSString stringWithFormat:@"  obj:init(...)"] line:self.nameToken.line column:self.nameToken.column];
    [writer writeNewline];
    [writer write:[NSString stringWithFormat:@"  return obj"] line:self.nameToken.line column:self.nameToken.column];
    [writer writeNewline];
    [writer write:[NSString stringWithFormat:@"end})"] line:self.nameToken.line column:self.nameToken.column];
    [writer writeNewline];

    if(self.type.parent) {
        [writer write:[NSString stringWithFormat:@"for k, v in pairs(%@) do", parent]];
        [writer writeNewline];
        [writer write:[NSString stringWithFormat:@"  %@[k] = v", self.type.name]];
        [writer writeNewline];
        [writer write:[NSString stringWithFormat:@"end"]];
        [writer writeNewline];
    }
    
    for(LXFunctionExpr *function in functions) {
        [function compile:writer class:self isMeta:NO];
        [writer writeNewline];
    }
    
    LXVariable *initFunction = [self.scope localVariable:@"init"];
    
    if(!initFunction || !initFunction.isFunction) {
        [writer write:@"function "];
        [writer write:self.type.name];
        [writer write:@":init(...)"];
        writer.indentationLevel++;
        if(self.type.parent) {
            [writer writeNewline];
            [writer write:@"self.super.init(self, ...)"];
        }
        [self compileInitFunction:writer];
        
        writer.indentationLevel--;
        [writer writeNewline];
        [writer write:@"end"];
    }
}

- (void)compileInitFunction:(LXLuaWriter *)writer {
    if([self.vars count]) {
        [writer writeNewline];
        
        for(LXDeclarationStmt *stmt in self.vars) {
            for(NSInteger i = 0; i < [stmt.vars count]; ++i) {
                LXTokenNode *tokenNode = stmt.vars[i];
                
                if([tokenNode.value isEqualToString:@","])
                    continue;
                
                LXVariable *variable = [self.scope localVariable:tokenNode.value];
                
                if(!variable)
                    continue;
                
                [writer write:@"self."];
                [tokenNode compile:writer];
                [writer write:@" = "];
                
                LXExpr *expr = i < [stmt.exprs count] ? stmt.exprs[i] : [variable.type defaultExpression];
                [expr compile:writer];
                
                if(stmt != self.vars.lastObject || tokenNode != stmt.vars.lastObject)
                    [writer writeNewline];
            }
        }
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
    
    self.ifToken.completionFlags = LXTokenCompletionFlagsVariables;
    self.thenToken.completionFlags = LXTokenCompletionFlagsBlock;
    self.elseToken.completionFlags = LXTokenCompletionFlagsBlock;
    self.endToken.completionFlags = LXTokenCompletionFlagsBlock;
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
    
    self.elseIfToken.completionFlags = LXTokenCompletionFlagsVariables;
    self.thenToken.completionFlags = LXTokenCompletionFlagsBlock;
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
    
    self.whileToken.completionFlags = LXTokenCompletionFlagsVariables;
    self.doToken.completionFlags = LXTokenCompletionFlagsBlock;
    self.endToken.completionFlags = LXTokenCompletionFlagsBlock;
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
    
    self.doToken.completionFlags = LXTokenCompletionFlagsBlock;
    self.endToken.completionFlags = LXTokenCompletionFlagsBlock;
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
@dynamic nameToken, equalsToken, exprInit, exprCondCommaToken, exprCond, exprIncCommaToken, exprInc;

- (void)resolveVariables:(LXContext *)context {
    LXClass *type = [LXClassNumber classNumber];
    LXVariable *variable = [self.scope createVariable:self.nameToken.value type:type];
    variable.definedLocation = self.nameToken.location;

    [self.exprInit resolveVariables:context];
    [self.exprCond resolveVariables:context];
    [self.exprInc resolveVariables:context];
    [self.body resolveVariables:context];
}

- (void)resolveTypes:(LXContext *)context {
    [self.exprInit resolveTypes:context];
    [self.exprCond resolveTypes:context];
    [self.exprInc resolveTypes:context];
    
    [context pushScope:self.scope];
    [self.body resolveTypes:context];
    [context popScope];

    self.equalsToken.completionFlags = LXTokenCompletionFlagsVariables;
    self.exprCondCommaToken.completionFlags = LXTokenCompletionFlagsVariables;
    self.exprIncCommaToken.completionFlags = LXTokenCompletionFlagsVariables;
    self.doToken.completionFlags = LXTokenCompletionFlagsBlock;
    self.endToken.completionFlags = LXTokenCompletionFlagsBlock;
}

- (void)compile:(LXLuaWriter *)writer {
    [self.forToken compile:writer];
    [writer writeSpace];
    [self.nameToken compile:writer];
    [self.equalsToken compile:writer];
    [self.exprInit compile:writer];
    [self.exprCondCommaToken compile:writer];
    [self.exprCond compile:writer];
    [self.exprIncCommaToken compile:writer];
    [self.exprInc compile:writer];
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

@implementation LXIteratorForStmt
@dynamic vars, inToken, exprs;

- (void)resolveVariables:(LXContext *)context {
    for(LXDeclarationNode *node in self.vars) {
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
        }
    }
    
    for(LXNode *node in self.exprs) {
        [node resolveVariables:context];
    }
    
    [self.body resolveVariables:context];
}

- (void)resolveTypes:(LXContext *)context {
    for(LXExpr *expr in self.exprs) {
        [expr resolveTypes:context];
    }
    
    [context pushScope:self.scope];
    [self.body resolveTypes:context];
    [context popScope];

    self.doToken.completionFlags = LXTokenCompletionFlagsBlock;
    self.endToken.completionFlags = LXTokenCompletionFlagsBlock;
}

- (void)compile:(LXLuaWriter *)writer {
    [self.forToken compile:writer];
    [writer writeSpace];
    
    for(LXNode *node in self.vars) {
        [node compile:writer];
    }
    
    [writer writeSpace];
    [self.inToken compile:writer];
    [writer writeSpace];
    
    for(LXNode *node in self.exprs) {
        [node compile:writer];
    }
    
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
@dynamic beginLabelToken, labelToken, endLabelToken;

- (void)resolveTypes:(LXContext *)context {
    self.endLabelToken.completionFlags = LXTokenCompletionFlagsBlock;
}

- (void)compile:(LXLuaWriter *)writer {
    [self.beginLabelToken compile:writer];
    [writer writeSpace];
    [self.labelToken compile:writer];
    [writer writeSpace];
    [self.endLabelToken compile:writer];
}

@end

@implementation LXGotoStmt
@dynamic gotoToken, labelToken;

- (void)resolveTypes:(LXContext *)context {
    self.labelToken.completionFlags = LXTokenCompletionFlagsBlock;
}

- (void)compile:(LXLuaWriter *)writer {
    [self.gotoToken compile:writer];
    [writer writeSpace];
    [self.labelToken compile:writer];
}

@end

@implementation LXBreakStmt
@dynamic breakToken;

- (void)resolveTypes:(LXContext *)context {
    self.breakToken.completionFlags = LXTokenCompletionFlagsBlock;
}

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
    
    self.returnToken.completionFlags = LXTokenCompletionFlagsVariables;
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
            variable = self.isGlobal ? [context createGlobalVariable:node.value type:type] : [scope createVariable:node.value type:type];
            variable.definedLocation = node.location;
        }
    }
    
    for(LXExpr *expr in self.exprs) {
        [expr resolveVariables:context];
    }
}

- (void)resolveTypes:(LXContext *)context {
    LXClass *type = [context findType:self.typeToken.value];

    if(!type.isDefined) {
        [context addWarning:[NSString stringWithFormat:@"Type %@ is undefined.", self.typeToken.value] range:self.typeToken.range line:self.typeToken.line column:self.typeToken.column];
    }
    
    for(LXExpr *expr in self.exprs) {
        [expr resolveTypes:context];
    }
    
    LXNode *lastNode = self.children.lastObject;
    
    while(lastNode) {
        if([lastNode isKindOfClass:[LXTokenNode class]]) {
            LXTokenNode *lastTokenNode = (LXTokenNode *)lastNode;
            lastTokenNode.completionFlags |= LXTokenCompletionFlagsBlock;
            break;
        }
        else {
            lastNode = lastNode.children.lastObject;
        }
    }
    
    self.scopeToken.completionFlags = LXTokenCompletionFlagsTypes;
    self.equalsToken.completionFlags = LXTokenCompletionFlagsVariables;
    self.typeToken.isType = YES;
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
    
    for(LXNode *node in self.vars) {
        [node compile:writer];
    }
    
    [self.equalsToken compile:writer];
    
    for(LXNode *node in self.exprs) {
        [node compile:writer];
    }
}

@end

@implementation LXAssignmentStmt
@dynamic vars, equalsToken, exprs;

+ (LXAssignmentStmt *)assignmentStatementWithVars:(NSArray *)vars {
    LXNode *firstVar = vars.firstObject;
    LXAssignmentStmt *statement = [[LXAssignmentStmt alloc] init];
    statement.line = firstVar.line;
    statement.column = firstVar.line;
    statement.location = firstVar.location;
    statement.vars = vars;
    
    return statement;
}

- (void)resolveVariables:(LXContext *)context {
    BOOL assignable = NO;
    
    for(NSInteger i = 0; i < [self.vars count]; ++i) {
        LXExpr *expr = self.vars[i];
        
        if(![expr isKindOfClass:[LXExpr class]])
            continue;
        
        [expr resolveVariables:context];
        
        assignable = assignable || expr.assignable;
        
        if(i > 0 && !expr.assignable) {
            [context addError:@"Expected assignment statement" range:expr.range line:expr.line column:expr.column];
        }
    }
    
    if(assignable) {
        if(!self.equalsToken) {
            [context addError:@"Expected assignment statement" range:self.range line:self.line column:self.column];
        }
    }
    else {
        if(self.equalsToken) {
            [context addError:[NSString stringWithFormat:@"Unexpected '=' near %@", self.equalsToken.value] range:self.equalsToken.range line:self.equalsToken.line column:self.equalsToken.column];
        }
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
    
    self.equalsToken.completionFlags = LXTokenCompletionFlagsVariables;
    
    LXNode *lastNode = self.children.lastObject;
    
    while(lastNode) {
        if([lastNode isKindOfClass:[LXTokenNode class]]) {
            LXTokenNode *lastTokenNode = (LXTokenNode *)lastNode;
            lastTokenNode.completionFlags |= LXTokenCompletionFlagsBlock;
            break;
        }
        else {
            lastNode = lastNode.children.lastObject;
        }
    }
}

- (void)compile:(LXLuaWriter *)writer {
    for(LXNode *node in self.vars) {
        [node compile:writer];
    }
    
    NSDictionary *assignmentOperators = @{@"+=" : @(YES), @"-=" : @(YES),  @"*=" : @(YES),  @"/=" : @(YES),
                                          @"^=" : @(YES),  @"%=" : @(YES),  @"..=" : @(YES)};
    
    if([assignmentOperators[self.equalsToken.value] boolValue]) {
        NSString *operator = [self.equalsToken.value substringToIndex:[self.equalsToken.value length]-1];

        [writer write:@"="];
        
        for(NSInteger i = 0; i < [self.vars count] && i < [self.exprs count]; ++i) {
            LXNode *var = self.vars[i];
            LXNode *expr = self.exprs[i];
            
            if([var isKindOfClass:[LXExpr class]] && [expr isKindOfClass:[LXExpr class]]) {
                [var compile:writer];
                [writer write:operator];
                [expr compile:writer];
            }
            else {
                [expr compile:writer];
            }
        }
    }
    else {
        [self.equalsToken compile:writer];
        
        for(LXNode *node in self.exprs) {
            [node compile:writer];
        }
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
    
    LXNode *lastNode = self.expr.children.lastObject;
    
    while(lastNode) {
        if([lastNode isKindOfClass:[LXTokenNode class]]) {
            LXTokenNode *lastTokenNode = (LXTokenNode *)lastNode;
            lastTokenNode.completionFlags |= LXTokenCompletionFlagsBlock;
            break;
        }
        else {
            lastNode = lastNode.children.lastObject;
        }
    }
}

- (void)compile:(LXLuaWriter *)writer {
    [self.expr compile:writer];
}

@end
