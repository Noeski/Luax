//
//  LXVariable.m
//  LuaX
//
//  Created by Noah Hilt on 8/11/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXVariable.h"

@implementation LXVariable

- (BOOL)isDefined {
    return self.isFunction || self.type != nil;
}

+ (LXVariable *)variableWithName:(NSString *)name type:(LXClass *)type {
    LXVariable *variable = [[LXVariable alloc] init];
    variable.name = name;
    variable.type = type;
    
    return variable;
}

+ (LXVariable *)variableWithType:(LXClass *)type {
    LXVariable *variable = [[LXVariable alloc] init];
    variable.type = type;
    
    return variable;
}

+ (LXVariable *)functionWithName:(NSString *)name {
    LXVariable *function = [[LXVariable alloc] init];
    function.name = name;
    function.isFunction = YES;
    
    return function;
}

@end
