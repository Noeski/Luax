//
//  LXToken.m
//  LuaX
//
//  Created by Noah Hilt on 8/11/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXToken.h"

@implementation LXToken

- (BOOL)isKeyword {
    return self.type >= FIRST_RESERVED && self.type < LX_TK_CONCAT;
}

- (BOOL)isType {
    return self.type == LX_TK_NAME || (self.type >= LX_TK_TYPE_VAR && self.type < LX_TK_CLASS);
}

- (BOOL)isAssignmentOperator {
    return self.type == '=' || (self.type >= LX_TK_PLUS_EQ && self.type < LX_TK_GE);
}

@end