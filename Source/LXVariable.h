//
//  LXVariable.x
//  LuaX
//
//  Created by Noah Hilt on 8/11/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXClass.h"

@interface LXVariable : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) LXClass *type;
@property (nonatomic, assign) NSInteger definedLocation;
@property (nonatomic, assign) BOOL isGlobal;
@property (nonatomic, assign) BOOL isMember;
@property (nonatomic, assign) BOOL isClass;
@property (nonatomic, assign) BOOL isFunction;
@property (nonatomic, assign) BOOL isStatic;
@property (nonatomic, readonly) BOOL isDefined;
@property (nonatomic, strong) NSArray *returnTypes;
@property (nonatomic, strong) NSArray *arguments;

+ (LXVariable *)variableWithName:(NSString *)name type:(LXClass *)type;
+ (LXVariable *)variableWithType:(LXClass *)type;
+ (LXVariable *)functionWithName:(NSString *)name;
@end