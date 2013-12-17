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

- (NSString *)autoCompleteString {
    if(self.type) {
        return [NSString stringWithFormat:@"%@ %@", self.type, self.name];
    }
    else {
        return [NSString stringWithFormat:@"(undefined) %@", self.name];
    }
}

- (BOOL)isFunction {
    return NO;
}

@end

@implementation LXFunction

- (BOOL)isFunction {
    return YES;
}

@end
