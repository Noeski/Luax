//
//  LXNode.m
//  LuaX
//
//  Created by Noah Hilt on 8/11/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXNode.h"

@interface LXLuaWriter()
@property (nonatomic, strong) NSMutableString *string;
@end

@implementation LXLuaWriter

- (id)init {
    if(self = [super init]) {
        _string = [[NSMutableString alloc] init];
    }
    
    return self;
}

- (void)write:(NSString *)string {
    [self.string appendString:string];
    
    self.currentColumn += [string length];
}

- (void)writeNewLine {
    [self.string appendString:@"\n"];
    
    self.currentLine += 1;
    self.currentColumn = 0;
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
    LXVariable *variable = [[LXVariable alloc] init];
    variable.name = name;
    variable.type = type;
    variable.isGlobal = [self isGlobalScope];
    
    [self.localVariables addObject:variable];
    
    return variable;
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

@implementation LXNode
NSInteger stringScopeLevel = 0;

- (NSString *)toString {
    NSLog(@"ERROR");
    
    return @"";
}

- (void)openStringScope {
    ++stringScopeLevel;
}

- (void)closeStringScope {
    --stringScopeLevel;
}

- (NSString *)indentedString:(NSString *)input {
    NSArray *lines = [input componentsSeparatedByString:@"\n"];
    NSString *output = @"";
    
    for(NSString *line in lines) {
        output = [output stringByAppendingString:[[@"" stringByPaddingToLength:stringScopeLevel*2 withString:@" " startingAtIndex:0] stringByAppendingString:line]];
        
        if(line != lines.lastObject) {
            output = [output stringByAppendingString:@"\n"];
        }
    }
    
    return output;
}

@end

//Statements
@implementation LXNodeStatement
@end

@implementation LXNodeEmptyStatement

- (NSString *)toString {
    return @";";
}

@end

@implementation LXNodeBlock

- (NSString *)toString {
    NSString *string = @"";
    NSInteger index = 0;
    for(LXNode *statement in self.statements) {
        string = [string stringByAppendingString:[statement toString]];
        
        ++index;
        
        if(index < [self.statements count]) {
            string = [string stringByAppendingString:@"\n"];
        }
    }
    
    return string;
}

@end

@implementation LXNodeIfStatement

- (NSString *)toString {
    NSString *string = [self indentedString:[NSString stringWithFormat:@"if %@ then", [self.condition toString]]];
    string = [string stringByAppendingString:@"\n"];

    if([self.body.statements count] > 0) {
        [self openStringScope];
        string = [string stringByAppendingString:[self.body toString]];
        [self closeStringScope];

        string = [string stringByAppendingString:@"\n"];
    }
    
    for(LXNode *elseIf in self.elseIfStatements) {
        string = [string stringByAppendingString:[elseIf toString]];
    }
    
    if(self.elseStatement) {
        string = [string stringByAppendingString:[self indentedString:@"else"]];
        string = [string stringByAppendingString:@"\n"];

        if([self.elseStatement.statements count] > 0) {
            [self openStringScope];
            string = [string stringByAppendingString:[self.elseStatement toString]];
            [self closeStringScope];
        
            string = [string stringByAppendingString:@"\n"];
        }
    }
    
    string = [string stringByAppendingString:[self indentedString:@"end"]];
    
    return string;
}

@end

@implementation LXNodeElseIfStatement

- (NSString *)toString {
    NSString *string = [self indentedString:[NSString stringWithFormat:@"elseif %@ then", [self.condition toString]]];
    string = [string stringByAppendingString:@"\n"];
    
    if([self.body.statements count] > 0) {
        [self openStringScope];
        string = [string stringByAppendingString:[self.body toString]];
        [self closeStringScope];
        
        string = [string stringByAppendingString:@"\n"];
    }
    
    return string;
}

@end

@implementation LXNodeWhileStatement

- (NSString *)toString {
    NSString *string = [self indentedString:[NSString stringWithFormat:@"while %@ do", [self.condition toString]]];
    
    string = [string stringByAppendingString:@"\n"];

    if([self.body.statements count] > 0) {
        [self openStringScope];
        string = [string stringByAppendingString:[self.body toString]];
        [self closeStringScope];
        string = [string stringByAppendingString:@"\n"];
    }
    
    string = [string stringByAppendingString:[self indentedString:@"end"]];
    
    return string;
}

@end

@implementation LXNodeDoStatement

- (NSString *)toString {
    NSString *string = [self indentedString:@"do"];
    string = [string stringByAppendingString:@"\n"];

    if([self.body.statements count] > 0) {
        [self openStringScope];
        string = [string stringByAppendingString:[self.body toString]];
        [self closeStringScope];
        string = [string stringByAppendingString:@"\n"];
    }
    
    string = [string stringByAppendingString:[self indentedString:@"end"]];
    
    return string;
}

@end

@implementation LXNodeNumericForStatement

- (NSString *)toString {
    NSString *string;
    
    if(self.stepExpression) {
        string = [NSString stringWithFormat:@"for %@=%@,%@,%@ do", self.variable.name, [self.startExpression toString], [self.endExpression toString], [self.stepExpression toString]];
    }
    else {
        string = [NSString stringWithFormat:@"for %@=%@,%@ do", self.variable.name, [self.startExpression toString], [self.endExpression toString]];
    }
    
    string = [string stringByAppendingString:@"\n"];

    if([self.body.statements count] > 0) {
        [self openStringScope];
        string = [string stringByAppendingString:[self.body toString]];
        [self closeStringScope];
        string = [string stringByAppendingString:@"\n"];
    }
    
    string = [string stringByAppendingString:@"end"];
    
    return [self indentedString:string];
}

@end

@implementation LXNodeGenericForStatement

- (NSString *)toString {
    NSString *variableString = @"";
    NSString *generatorString = @"";

    for(NSInteger i = 0; i < [self.variableList count]; ++i) {
        LXVariable *variable = self.variableList[i];
        
        variableString = [variableString stringByAppendingFormat:@"%@", variable.name];
        
        if(i < [self.variableList count]-1) {
            variableString = [variableString stringByAppendingString:@","];
        }
    }
    
    for(NSInteger i = 0; i < [self.generators count]; ++i) {
        LXNodeExpression *generator = self.generators[i];
        
        generatorString = [generatorString stringByAppendingFormat:@"%@", [generator toString]];
        
        if(i < [self.generators count]-1) {
            generatorString = [generatorString stringByAppendingString:@","];
        }
    }
    
    NSString *string = [NSString stringWithFormat:@"for %@ in %@ do\n", variableString, generatorString];

    if([self.body.statements count] > 0) {
        [self openStringScope];
        string = [string stringByAppendingString:[self.body toString]];
        [self closeStringScope];
        string = [string stringByAppendingString:@"\n"];
    }
    
    string = [string stringByAppendingString:@"end"];
    
    return [self indentedString:string];
}

@end

@implementation LXNodeRepeatStatement

- (NSString *)toString {
    NSString *string = @"repeat";
    string = [string stringByAppendingString:@"\n"];

    if([self.body.statements count] > 0) {
        [self openStringScope];
        string = [string stringByAppendingString:[self.body toString]];
        [self closeStringScope];
        string = [string stringByAppendingString:@"\n"];
    }
    string = [string stringByAppendingString:@"until %@"], [self.condition toString];
    return [self indentedString:string];
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:@"repeat"];
    [writer writeNewLine];
    
    if([self.body.statements count] > 0) {
        [self openStringScope];
        [self.body compile:writer];
        [self closeStringScope];
        
        [writer writeNewLine];
    }
    
    [writer write:@"until "];
    [self.condition compile:writer];
}

@end

@implementation LXNodeFunctionStatement

- (NSString *)toString {
    NSString *string = [self indentedString:self.isLocal ? @"local " : @""];
    
    return [string stringByAppendingString:[self.expression toString]];
}

- (void)compile:(LXLuaWriter *)writer {
    if(self.isLocal)
        [writer write:@"local"];
    
    [self.expression compile:writer];
}

@end

@implementation LXNodeClassStatement

- (NSString *)toString {
    NSString *string = nil;
    
    if(self.superclass) {
        string = [NSString stringWithFormat:@"%@ = %@ or setmetatable({}, {__call = function(class, ...)\n  local obj = setmetatable({class = \"%@\", super = %@}, {__index = class})\n  obj:init(...)\n  return obj\nend})\n", self.name, self.name, self.name, self.superclass];
        string = [string stringByAppendingFormat:@"for k, v in pairs(%@) do\n  %@[k] = v\nend\n", self.superclass, self.name];
        string = [string stringByAppendingFormat:@"function %@:init(...)\n  %@.init(self, ...)\n", self.name, self.superclass];
    }
    else {
        string = [NSString stringWithFormat:@"%@ = %@ or setmetatable({}, {__call = function(class, ...)\n  local obj = setmetatable({class = \"%@\"}, {__index = class})\n  obj:init(...)\n  return obj\nend})\n", self.name, self.name, self.name];
        string = [string stringByAppendingFormat:@"function %@:init(...)\n", self.name];
    }
    
    for(LXNodeDeclarationStatement *declaration in self.variableDeclarations) {
        for(NSInteger i = 0; i < [declaration.variables count]; ++i) {
            LXVariable *variable = declaration.variables[i];

            LXNode *init = i < [declaration.initializers count] ? declaration.initializers[i] : variable.type.defaultExpression;
            
            string = [string stringByAppendingFormat:@"  self.%@ = %@\n", variable.name, [init toString]];
        }
    }
    
    string = [string stringByAppendingString:@"end"];

    for(LXNode *function in self.functions) {
        string = [string stringByAppendingString:@"\n"];
        string = [string stringByAppendingString:[function toString]];
    }

    return [self indentedString:string];
}

@end

@implementation LXNodeLabelStatement

- (NSString *)toString {
    NSString *string = [NSString stringWithFormat:[self indentedString:@"::%@::"], self.label];
    
    return string;
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:@"::"];
    [writer write:[NSString stringWithFormat:@"%@", self.label]];
    [writer write:@"::"];
}

@end

@implementation LXNodeReturnStatement

- (NSString *)toString {
    NSString *string = [self indentedString:@"return "];
    
    NSInteger index = 0;
    for(LXNode *argument in self.arguments) {
        string = [string stringByAppendingString:[argument toString]];
        
        ++index;
        
        if(index < [self.arguments count]) {
            string = [string stringByAppendingString:@","];
        }
    }
    
    return string;
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:@"return "];
    
    NSInteger index = 0;
    for(LXNode *argument in self.arguments) {
        [argument compile:writer];
        
        ++index;
        
        if(index < [self.arguments count]) {
            [writer write:@","];
        }
    }
}

@end

@implementation LXNodeBreakStatement

- (NSString *)toString {
    return [self indentedString:@"break"];
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:@"break"];
}

@end

@implementation LXNodeGotoStatement

- (NSString *)toString {
    NSString *string = [NSString stringWithFormat:[self indentedString:@"goto %@"], self.label];
    
    return string;
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:@"goto"];
    [writer write:self.label];
}

@end

@implementation LXNodeAssignmentStatement

- (NSString *)toString {
    unichar op = [self.op characterAtIndex:0];
    
    NSString *string = @"";
    NSString *initString = @"";
    
    for(NSInteger i = 0; i < [self.variables count]; ++i) {
        LXNodeExpression *variableExpression = self.variables[i];
        LXNode *init = i < [self.initializers count] ? self.initializers[i] : [[LXNodeNilExpression alloc] init];
        
        string = [string stringByAppendingString:[variableExpression toString]];
        
        if(op != '=') {
            initString = [initString stringByAppendingFormat:@"%@ %@ %@", [variableExpression toString], [self.op substringToIndex:[self.op length]-1], [init toString]];
        }
        else {
            initString = [initString stringByAppendingString:[init toString]];
        }
        
        if(i < [self.variables count]-1) {
            string = [string stringByAppendingString:@", "];
            initString = [initString stringByAppendingString:@", "];
        }
    }
    
    return [self indentedString:[string stringByAppendingFormat:@" = %@", initString]];
}

- (void)compile:(LXLuaWriter *)writer {
    unichar op = [self.op characterAtIndex:0];
    
    for(NSInteger i = 0; i < [self.variables count]; ++i) {
        LXNodeExpression *variableExpression = self.variables[i];
        
        [variableExpression compile:writer];
        
        if(i < [self.variables count]-1) {
            [writer write:@","];
        }
    }
    
    [writer write:@"="];
    
    for(NSInteger i = 0; i < [self.variables count]; ++i) {
        LXNodeExpression *variableExpression = self.variables[i];
        LXNode *init = i < [self.initializers count] ? self.initializers[i] : [[LXNodeNilExpression alloc] init];
        
        if(op != '=') {
            [variableExpression compile:writer];
            [writer write:[self.op substringToIndex:[self.op length]-1]];
            [init compile:writer];
        }
        else {
            [init compile:writer];
        }
        
        if(i < [self.variables count]-1) {
            [writer write:@","];
        }
    }
}

@end

@implementation LXNodeDeclarationStatement

- (NSString *)toString {
    NSString *string = self.isLocal ? @"local " : @"";
    NSString *initString = @"";
    
    for(NSInteger i = 0; i < [self.variables count]; ++i) {
        LXVariable *variable = self.variables[i];
        LXNode *init = i < [self.initializers count] ? self.initializers[i] : variable.type.defaultExpression;
        
        string = [string stringByAppendingString:variable.name];
        initString = [initString stringByAppendingString:[init toString]];
        
        if(i < [self.variables count]-1) {
            string = [string stringByAppendingString:@", "];
            initString = [initString stringByAppendingString:@", "];
        }
    }
    
    return [self indentedString:[string stringByAppendingFormat:@" = %@", initString]];
}

- (void)compile:(LXLuaWriter *)writer {
    if(self.isLocal)
        [writer write:@"local"];
    
    for(NSInteger i = 0; i < [self.variables count]; ++i) {
        LXVariable *variable = self.variables[i];
        
        [writer write:variable.name];

        if(i < [self.variables count]-1) {
            [writer write:@","];
        }
    }
    
    [writer write:@"="];

    for(NSInteger i = 0; i < [self.variables count]; ++i) {
        LXVariable *variable = self.variables[i];
        LXNode *init = i < [self.initializers count] ? self.initializers[i] : variable.type.defaultExpression;
        
        [init compile:writer];
        
        if(i < [self.variables count]-1) {
            [writer write:@","];
        }
    }
}

@end

@implementation LXNodeExpressionStatement

- (NSString *)toString {
    return [self indentedString:[self.expression toString]];
}

- (void)compile:(LXLuaWriter *)writer {
    [self.expression compile:writer];
}

@end

//Expressions
@implementation LXNodeExpression
@end

@implementation LXNodeVariableExpression

- (NSString *)toString {
    return self.scriptVariable.isMember ? [NSString stringWithFormat:@"self.%@", self.variable] : self.variable;
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:self.scriptVariable.isMember ? [NSString stringWithFormat:@"self.%@", self.variable] : self.variable];
}

@end

@implementation LXNodeUnaryOpExpression

- (NSString *)toString {
    return [NSString stringWithFormat:@"%@%@", self.op, [self.rhs toString]];
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:self.op];
    [self.rhs compile:writer];
}

@end

@implementation LXNodeBinaryOpExpression

- (NSString *)toString {
    return [NSString stringWithFormat:@"%@%@%@", [self.lhs toString], self.op, [self.rhs toString]];
}

- (void)compile:(LXLuaWriter *)writer {
    [self.lhs compile:writer];
    [writer write:self.op];
    [self.rhs compile:writer];
}

@end

@implementation LXNodeNumberExpression

- (NSString *)toString {
    return [NSString stringWithFormat:@"%@", self.value];
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:[NSString stringWithFormat:@"%@", self.value]];
}

@end

@implementation LXNodeStringExpression

- (NSString *)toString {
    return [NSString stringWithFormat:@"%@", self.value];
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:self.value];
}

@end

@implementation LXNodeBoolExpression

- (NSString *)toString {
    return [NSString stringWithFormat:@"%@", self.value ? @"true" : @"false"];
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:self.value ? @"true" : @"false"];
}

@end

@implementation LXNodeNilExpression

- (NSString *)toString {
    return @"nil";
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:@"nil"];
}

@end

@implementation LXNodeVarArgExpression

- (NSString *)toString {
    return @"...";
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:@"..."];
}

@end

@implementation LXKeyValuePair
@end

@implementation LXNodeTableConstructorExpression

- (NSString *)toString {
    NSString *string = @"{";
    
    for(NSInteger i = 0; i < [self.keyValuePairs count]; ++i) {
        LXKeyValuePair *kvp = self.keyValuePairs[i];
        
        if(kvp.key) {
            if(kvp.isBoxed)
                string = [string stringByAppendingFormat:@"[%@]=%@", [kvp.key toString], [kvp.value toString]];
            else
                string = [string stringByAppendingFormat:@"%@=%@", [kvp.key toString], [kvp.value toString]];
        }
        else {
            string = [string stringByAppendingFormat:@"%@", [kvp.value toString]];
        }
        
        if(i < [self.keyValuePairs count]-1) {
            string = [string stringByAppendingString:@", "];
        }
    }
    
    string = [string stringByAppendingString:@"}"];
    
    return string;
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:@"{"];
    
    for(NSInteger i = 0; i < [self.keyValuePairs count]; ++i) {
        LXKeyValuePair *kvp = self.keyValuePairs[i];
        
        if(kvp.key) {
            if(kvp.isBoxed)
                [writer write:@"["];
        
            [kvp.key compile:writer];
            
            if(kvp.isBoxed)
                [writer write:@"]"];
            
            [writer write:@"="];
            [kvp.value compile:writer];
        }
        else {
            [kvp.value compile:writer];
        }
        
        if(i < [self.keyValuePairs count]-1) {
            [writer write:@","];
        }
    }
    
    [writer write:@"}"];
}


@end

@implementation LXNodeMemberExpression

- (NSString *)toString {
    return [NSString stringWithFormat:@"%@%@%@", [self.base toString], self.useColon ? @":" : @".", self.value];
}

- (void)compile:(LXLuaWriter *)writer {
    [self.base compile:writer];
    [writer write:[NSString stringWithFormat:@"%@%@", self.useColon ? @":" : @".", self.value]];
}

@end

@implementation LXNodeIndexExpression

- (NSString *)toString {
    return [NSString stringWithFormat:@"%@[%@]", [self.base toString], [self.index toString]];
}

- (void)compile:(LXLuaWriter *)writer {
    [self.base compile:writer];
    [writer write:@"["];
    [self.index compile:writer];
    [writer write:@"]"];
}

@end

@implementation LXNodeCallExpression

- (NSString *)toString {
    NSString *string = [NSString stringWithFormat:@"%@(", [self.base toString]];
    
    NSInteger index = 0;
    for(LXNode *variable in self.arguments) {
        string = [string stringByAppendingString:[variable toString]];
        
        ++index;
        
        if(index < [self.arguments count]) {
            string = [string stringByAppendingString:@","];
        }
    }
    
    string = [string stringByAppendingString:@")"];

    return string;
}

- (void)compile:(LXLuaWriter *)writer {
    [self.base compile:writer];
    [writer write:@"("];
    
    NSInteger index = 0;
    for(LXNode *variable in self.arguments) {
        [variable compile:writer];
        
        ++index;
        
        if(index < [self.arguments count]) {
            [writer write:@","];
        }
    }
    
    [writer write:@")"];
}

@end

@implementation LXNodeStringCallExpression

- (NSString *)toString {
    return [NSString stringWithFormat:@"%@ %@", [self.base toString], self.value];
}

- (void)compile:(LXLuaWriter *)writer {
    [self.base compile:writer];
    
    [writer write:self.value];
}

@end

@implementation LXNodeTableCallExpression

- (NSString *)toString {
    return [NSString stringWithFormat:@"%@ %@", [self.base toString], [self.table toString]];
}

- (void)compile:(LXLuaWriter *)writer {
    [self.base compile:writer];
    [self.table compile:writer];
}

@end

@implementation LXNodeFunctionExpression

- (NSString *)toString {
    NSString *string = @"";
    
    if(self.name) {
        string = [string stringByAppendingFormat:@"function %@(", [self.name toString]];
    }
    else {
        string = [string stringByAppendingString:@"function("];
    }
    
    NSInteger index = 0;
    for(LXVariable *argument in self.arguments) {
        string = [string stringByAppendingString:argument.name];
        
        ++index;
        
        if(index < [self.arguments count]) {
            string = [string stringByAppendingString:@","];
        }
    }
    
    string = [string stringByAppendingString:@")\n"];
    
    [self openStringScope];
    string = [string stringByAppendingString:[self.body toString]];
    [self closeStringScope];
    
    if([self.body.statements count] > 0) {
        string = [string stringByAppendingString:@"\n"];
    }
    
    string = [string stringByAppendingString:[self indentedString:@"end"]];
    
    return string;
}

@end