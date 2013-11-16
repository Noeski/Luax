//
//  LXNode.m
//  LuaX
//
//  Created by Noah Hilt on 8/11/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXNode.h"

@implementation LXScope

- (id)initWithParent:(LXScope *)parent openScope:(BOOL)openScope {
    if(self = [super init]) {
        _type = LXScopeTypeBlock;
        _parent = [parent retain];
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

- (void)dealloc {
    [_parent release];
    [_children release];
    [_localVariables release];
    [super dealloc];
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
    [variable release];
    
    return variable;
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

@end

@implementation LXNode
NSInteger stringScopeLevel = 0;

- (void)dealloc {
    [_error release];
    [super dealloc];
}

- (void)setError:(NSString *)error {
    [_error release];
    _error = [error retain];
    
    NSLog(@"%@", error);
}

- (NSString *)toString {
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

- (void)dealloc {
    [_scope release];
    [_statements release];
    [super dealloc];
}

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

- (void)dealloc {
    [_condition release];
    [_body release];
    [_elseIfStatements release];
    [_elseStatement release];
    [super dealloc];
}

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

- (void)dealloc {
    [_condition release];
    [_body release];
    [super dealloc];
}

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

- (void)dealloc {
    [_condition release];
    [_body release];
    [super dealloc];
}

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

- (void)dealloc {
    [_body release];
    [super dealloc];
}

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

- (void)dealloc {
    [_variable release];
    [_startExpression release];
    [_endExpression release];
    [_stepExpression release];
    [_body release];
    [super dealloc];
}

- (NSString *)toString {
    NSString *string;
    
    if(self.stepExpression) {
        string = [self indentedString:[NSString stringWithFormat:@"for %@=%@,%@,%@ do", self.variable, self.startExpression, self.endExpression, self.stepExpression]];
    }
    else {
        string = [self indentedString:[NSString stringWithFormat:@"for %@=%@,%@ do", self.variable, self.startExpression, self.endExpression]];
    }
    
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

@implementation LXNodeGenericForStatement

- (void)dealloc {
    [_variableList release];
    [_generators release];
    [_body release];
    [super dealloc];
}

@end

@implementation LXNodeRepeatStatement

- (void)dealloc {
    [_condition release];
    [_body release];
    [super dealloc];
}

- (NSString *)toString {
    NSString *string = [self indentedString:@"repeat"];
    string = [string stringByAppendingString:@"\n"];

    if([self.body.statements count] > 0) {
        [self openStringScope];
        string = [string stringByAppendingString:[self.body toString]];
        [self closeStringScope];
        string = [string stringByAppendingString:@"\n"];
    }
    string = [string stringByAppendingString:[self indentedString:@"until %@"]], [self.condition toString];
    return string;
}

@end

@implementation LXNodeFunctionStatement

- (void)dealloc {
    [_expression release];
    [super dealloc];
}

- (NSString *)toString {
    NSString *string = [self indentedString:self.isLocal ? @"local " : @""];
    
    return [string stringByAppendingString:[self.expression toString]];
}

@end

@implementation LXNodeClassStatement

- (void)dealloc {
    [_name release];
    [_superclass release];
    [_functions release];
    [_variables release];
    [super dealloc];
}

- (NSString *)toString {
    NSString *string = nil;
    
    if(self.superclass) {
        string = [NSString stringWithFormat:@"%@ = %@ or setmetatable({}, {__index = %@})\n", self.name, self.name, self.superclass];
        string = [string stringByAppendingFormat:@"function %@.new()\n  local obj = %@:new()\n", self.name, self.superclass];
    }
    else {
        string = [NSString stringWithFormat:@"%@ = %@ or {}\n", self.name, self.name];
        string = [string stringByAppendingFormat:@"function %@.new()\n  obj = setmetatable({}, {__index = %@})\n", self.name, self.name];
    }
    
    for(LXNodeDeclarationStatement *declaration in self.variableDeclarations) {
        for(NSInteger i = 0; i < [declaration.varList count]; ++i) {
            LXVariable *variable = declaration.varList[i];
            LXNode *init = i < [declaration.initList count] ? declaration.initList[i] : nil;//Default initializer?
            
            string = [string stringByAppendingFormat:@"  obj.%@ = %@\n", variable.name, [init toString]];
        }
    }
    
    string = [string stringByAppendingString:@"  return obj\nend"];

    return [self indentedString:string];
    
    /*NSString *string = [NSString stringWithFormat:[self indentedString:@"%@class %@%@\n"], self.isLocal ? @"local " : @"", self.name, self.superclass ? [NSString stringWithFormat:@" extends %@", self.superclass] : @""];
    
    [self openStringScope];

    for(LXNode *variable in self.variables) {
        string = [string stringByAppendingString:[variable toString]];
        string = [string stringByAppendingString:@"\n"];
    }
    
    for(LXNode *function in self.functions) {
        string = [string stringByAppendingString:[function toString]];
        string = [string stringByAppendingString:@"\n"];
    }
    
    [self closeStringScope];
    
    string = [string stringByAppendingString:[self indentedString:@"end"]];
    
    return string;*/
}

@end

@implementation LXNodeLocalStatement

- (void)dealloc {
    [_varList release];
    [_initList release];
    [super dealloc];
}

- (NSString *)toString {
    NSString *string = [self indentedString:@"local "];
    
    NSInteger index = 0;
    for(LXVariable *variable in self.varList) {
        string = [string stringByAppendingString:variable.name];
        
        ++index;
        
        if(index < [self.varList count]) {
            string = [string stringByAppendingString:@","];
        }
    }
    
    if([self.initList count] > 0) {
        string = [string stringByAppendingString:@" = "];
        
        index = 0;
        for(LXNode *init in self.initList) {
            string = [string stringByAppendingString:[init toString]];
            
            ++index;
            
            if(index < [self.initList count]) {
                string = [string stringByAppendingString:@","];
            }
        }
    }
    
    return string;
}

@end

@implementation LXNodeLabelStatement

- (void)dealloc {
    [_label release];
    [super dealloc];
}

- (NSString *)toString {
    NSString *string = [NSString stringWithFormat:[self indentedString:@"::%@::"], self.label];
    
    return string;
}

@end

@implementation LXNodeReturnStatement

- (void)dealloc {
    [_arguments release];
    [super dealloc];
}

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

@end

@implementation LXNodeBreakStatement

- (NSString *)toString {
    return [self indentedString:@"break"];
}

@end

@implementation LXNodeGotoStatement

- (void)dealloc {
    [_label release];
    [super dealloc];
}

- (NSString *)toString {
    NSString *string = [NSString stringWithFormat:[self indentedString:@"goto %@"], self.label];
    
    return string;
}

@end

@implementation LXNodeAssignmentStatement

- (void)dealloc {
    [_varList release];
    [_initList release];
    [super dealloc];
}

- (NSString *)toString {
    NSString *string = [self indentedString:@""];
    
    NSInteger index = 0;
    for(LXNode *variable in self.varList) {
        string = [string stringByAppendingString:[variable toString]];
        
        ++index;
        
        if(index < [self.varList count]) {
            string = [string stringByAppendingString:@","];
        }
    }
    
    if([self.initList count] > 0) {
        string = [string stringByAppendingString:@" = "];
        
        index = 0;
        for(LXNode *init in self.initList) {
            string = [string stringByAppendingString:[init toString]];
            
            ++index;
            
            if(index < [self.initList count]) {
                string = [string stringByAppendingString:@","];
            }
        }
    }
    
    return string;
}

@end

@implementation LXNodeDeclarationStatement

- (void)dealloc {
    [_varList release];
    [_initList release];
    [super dealloc];
}

- (NSString *)toString {
    NSString *string = [self indentedString:@""];
    
    NSInteger index = 0;
    for(LXVariable *variable in self.varList) {
        string = [string stringByAppendingString:variable.name];
        
        ++index;
        
        if(index < [self.varList count]) {
            string = [string stringByAppendingString:@","];
        }
    }
    
    if([self.initList count] > 0) {
        string = [string stringByAppendingString:@" = "];
        
        index = 0;
        for(LXNode *init in self.initList) {
            string = [string stringByAppendingString:[init toString]];
            
            ++index;
            
            if(index < [self.initList count]) {
                string = [string stringByAppendingString:@","];
            }
        }
    }
    
    return string;
}

@end

@implementation LXNodeExpressionStatement

- (void)dealloc {
    [_expression release];
    [super dealloc];
}

- (NSString *)toString {
    return [self indentedString:[self.expression toString]];
}

@end

//Expressions
@implementation LXNodeExpression
@end

@implementation LXNodeVariableExpression

- (void)dealloc {
    [_variable release];
    [super dealloc];
}

- (NSString *)toString {
    return self.variable;
}

@end

@implementation LXNodeUnaryOpExpression

- (void)dealloc {
    [_op release];
    [_rhs release];
    [super dealloc];
}

- (NSString *)toString {
    return [NSString stringWithFormat:@"%@%@", self.op, [self.rhs toString]];
}

@end

@implementation LXNodeBinaryOpExpression

- (void)dealloc {
    [_op release];
    [_lhs release];
    [_rhs release];
    [super dealloc];
}

- (NSString *)toString {
    return [NSString stringWithFormat:@"%@%@%@", [self.lhs toString], self.op, [self.rhs toString]];
}

@end

@implementation LXNodeNumberExpression

- (void)dealloc {
    [_value release];
    [super dealloc];
}

- (NSString *)toString {
    return [NSString stringWithFormat:@"%@", self.value];
}

@end

@implementation LXNodeStringExpression

- (void)dealloc {
    [_value release];
    [super dealloc];
}

- (NSString *)toString {
    return [NSString stringWithFormat:@"%@", self.value];
}

@end

@implementation LXNodeBoolExpression

- (NSString *)toString {
    return [NSString stringWithFormat:@"%@", self.value ? @"true" : @"false"];
}

@end

@implementation LXNodeNilExpression

- (NSString *)toString {
    return @"nil";
}

@end

@implementation LXNodeVarArgExpression

- (NSString *)toString {
    return @"...";
}

@end

@implementation KeyValuePair

- (void)dealloc {
    [_key release];
    [_value release];
    [super dealloc];
}

@end

@implementation LXNodeTableConstructorExpression

- (void)dealloc {
    [_keyValuePairs release];
    [super dealloc];
}

- (NSString *)toString {
    return @"{}";
}

@end

@implementation LXNodeMemberExpression

- (void)dealloc {
    [_base release];
    [_value release];
    [super dealloc];
}

- (NSString *)toString {
    return [NSString stringWithFormat:@"%@%@%@", [self.base toString], self.useColon ? @":" : @".", self.value];
}

@end

@implementation LXNodeIndexExpression

- (void)dealloc {
    [_base release];
    [_index release];
    [super dealloc];
}

- (NSString *)toString {
    return [NSString stringWithFormat:@"%@[%@]", [self.base toString], [self.index toString]];
}

@end

@implementation LXNodeCallExpression

- (void)dealloc {
    [_base release];
    [_arguments release];
    [super dealloc];
}

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

@end

@implementation LXNodeStringCallExpression

- (void)dealloc {
    [_base release];
    [_value release];
    [super dealloc];
}

@end

@implementation LXNodeTableCallExpression

- (void)dealloc {
    [_base release];
    [_table release];
    [super dealloc];
}

@end

@implementation LXNodeFunctionExpression

- (void)dealloc {
    [_name release];
    [_arguments release];
    [_body release];
    [super dealloc];
}

- (NSString *)toString {
    NSString *string = @"";
    
    if(self.name) {
        string = [string stringByAppendingFormat:@"function %@(", self.name];
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