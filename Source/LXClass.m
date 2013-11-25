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
        
        self.defaultExpression = [[LXNode alloc] initWithChunk:@"0" line:-1 column:-1];
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
        
        self.defaultExpression = [[LXNode alloc] initWithChunk:@"false" line:-1 column:-1];
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
        
        self.defaultExpression = [[LXNode alloc] initWithChunk:@"\"\"" line:-1 column:-1];
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
        
        self.defaultExpression = [[LXNode alloc] initWithChunk:@"{}" line:-1 column:-1];
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
        
        self.defaultExpression = [[LXNode alloc] initWithChunk:@"function() end" line:-1 column:-1];
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
        
        self.defaultExpression = [[LXNode alloc] initWithChunk:@"nil" line:-1 column:-1];
    }
    
    return self;
}

@end