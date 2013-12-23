//
//  LXLuaVariable.h
//  Luax
//
//  Created by Noah Hilt on 12/20/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef enum {
    LXLuaVariableScopeNone,
    LXLuaVariableScopeLocal,
    LXLuaVariableScopeUpvalue,
    LXLuaVariableScopeGlobal
} LXLuaVariableScope;

typedef enum {
    LXLuaVariableTypeNil,
    LXLuaVariableTypeBoolean,
    LXLuaVariableTypeNumber,
    LXLuaVariableTypeString,
    LXLuaVariableTypeTable,
    LXLuaVariableTypeFunction,
    LXLuaVariableTypeUserdata,
    LXLuaVariableTypeThread,
    LXLuaVariableTypeLightuserdata
} LXLuaVariableType;

@interface LXLuaVariable : NSObject
@property (nonatomic, assign) LXLuaVariableType type;
@property (nonatomic, assign) LXLuaVariableScope scope;
@property (nonatomic, assign) NSInteger where;
@property (nonatomic, assign) NSInteger index;
@property (nonatomic, strong) NSString *key;
@property (nonatomic, strong) id value;
@property (nonatomic, weak) LXLuaVariable *parent;
@property (nonatomic, retain) NSArray *children;
@property (nonatomic, assign) BOOL expanded;
- (BOOL)isTemporary;
@end
