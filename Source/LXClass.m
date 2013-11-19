//
//  LXClass.m
//  LuaX
//
//  Created by Noah Hilt on 7/28/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXClass.h"
#import "LXNode.h"

@implementation LXClass

@end

@implementation LXClassNumber

- (id)init {
    if(self = [super init]) {
        self.name = @"Number";
        self.isDefined = YES;
        
        LXNodeNumberExpression *numberExpression = [[LXNodeNumberExpression alloc] init];
        numberExpression.value = @(0);
        self.defaultExpression = numberExpression;
    }
    
    return self;
}

+ (LXClassNumber *)classNumber {
    return [[LXClassNumber alloc] init];
}

@end


@implementation LXClassBool

- (id)init {
    if(self = [super init]) {
        self.name = @"Bool";
        self.isDefined = YES;
        
        LXNodeBoolExpression *booleanExpression = [[LXNodeBoolExpression alloc] init];
        booleanExpression.value = NO;
        self.defaultExpression = booleanExpression;
    }
    
    return self;
}

+ (LXClassBool *)classBool {
    return [[LXClassBool alloc] init];
}

@end

@implementation LXClassString

- (id)init {
    if(self = [super init]) {
        self.name = @"String";
        self.isDefined = YES;
        
        LXNodeStringExpression *stringExpression = [[LXNodeStringExpression alloc] init];
        stringExpression.value = @"";
        self.defaultExpression = stringExpression;
    }
    
    return self;
}

+ (LXClassString *)classString {
    return [[LXClassString alloc] init];
}

@end

@implementation LXClassTable

- (id)init {
    if(self = [super init]) {
        self.name = @"Table";
        self.isDefined = YES;
        
        LXNodeTableConstructorExpression *tableExpression = [[LXNodeTableConstructorExpression alloc] init];
        
        self.defaultExpression = tableExpression;
    }
    
    return self;
}

+ (LXClassTable *)classTable {
    return [[LXClassTable alloc] init];
}

@end

@implementation LXClassFunction

- (id)init {
    if(self = [super init]) {
        self.name = @"Function";
        self.isDefined = YES;
        
        LXNodeFunctionExpression *functionExpression = [[LXNodeFunctionExpression alloc] init];
        functionExpression.body = [[LXNodeBlock alloc] init];
        
        self.defaultExpression = functionExpression;
    }
    
    return self;
}

+ (LXClassFunction *)classFunction {
    return [[LXClassFunction alloc] init];
}

@end

@implementation LXClassBase

- (id)init {
    if(self = [super init]) {
        self.name = @"";
        self.isDefined = NO;
        
        LXNodeNilExpression *nilExpression = [[LXNodeNilExpression alloc] init];
        self.defaultExpression = nilExpression;
    }
    
    return self;
}

@end