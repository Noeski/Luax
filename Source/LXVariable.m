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
    return self.type != nil;
}

- (BOOL)isFunction {
    return NO;
}

@end

@implementation LXFunction

- (BOOL)isDefined {
    return YES;
}

- (BOOL)isFunction {
    return YES;
}

@end
