//
//  LXLuaVariable.m
//  Luax
//
//  Created by Noah Hilt on 12/20/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXLuaVariable.h"

@implementation LXLuaVariable

- (id)init {
	if(self = [super init]) {
        _type = LXLuaVariableTypeNil;
	}
	
	return self;
}

- (id)copyWithZone:(NSZone *)zone {
    LXLuaVariable *copy = [[self class] allocWithZone:zone];
    copy->_type = self.type;
    copy->_key = [self.key copyWithZone:zone];
    copy->_value = [self.value copyWithZone:zone];
    
    return copy;
}

- (void)setChildren:(NSArray *)children {
    _children = children;
    
    for(LXLuaVariable* child in _children) {
        child.parent = self;
    }
}

- (BOOL)isTemporary {
    return [self.key isEqualToString:@"(*temporary)"];
}

@end
