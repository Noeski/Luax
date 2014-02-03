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
    static LXClassNumber *class = nil;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        class = [[LXClassNumber alloc] init];
    });
    
    return class;
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
    static LXClassBool *class = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        class = [[LXClassBool alloc] init];
    });
    
    return class;
}

@end

@implementation LXClassString

- (id)init {
    if(self = [super init]) {
        self.name = @"String";
        self.isDefined = YES;
        
        self.defaultExpression = [[LXNode alloc] initWithChunk:@"\"\"" line:-1 column:-1];
        
        
        LXVariable *byteFunction = [LXVariable functionWithName:@"byte"];
        
        {
            LXVariable *retType = [LXVariable variableWithType:[LXClassNumber classNumber]];
            
            LXVariable *arg1 = [LXVariable variableWithName:@"i" type:[LXClassNumber classNumber]];
            LXVariable *arg2 = [LXVariable variableWithName:@"j" type:[LXClassNumber classNumber]];
            
            byteFunction.returnTypes = @[retType];
            byteFunction.arguments = @[arg1, arg2];
        }
        
        LXVariable *charFunction = [LXVariable functionWithName:@"char"];
        charFunction.isStatic = YES;
        
        {
            LXVariable *retType = [LXVariable variableWithType:self];
            
            LXVariable *arg = [LXVariable variableWithName:@"..." type:[LXClassNumber classNumber]];
            
            charFunction.returnTypes = @[retType];
            charFunction.arguments = @[arg];
        }

        LXVariable *dumpFunction = [LXVariable functionWithName:@"dump"];
        dumpFunction.isStatic = YES;
        
        {
            LXVariable *retType = [LXVariable variableWithType:self];
            
            LXVariable *arg = [LXVariable variableWithName:@"function" type:[LXClassFunction classFunction]];
            
            dumpFunction.returnTypes = @[retType];
            dumpFunction.arguments = @[arg];
        }
        
        LXVariable *findFunction = [LXVariable functionWithName:@"find"];
        
        {
            LXVariable *retType1 = [LXVariable variableWithType:[LXClassNumber classNumber]];
            LXVariable *retType2 = [LXVariable variableWithType:[LXClassNumber classNumber]];

            LXVariable *arg1 = [LXVariable variableWithName:@"pattern" type:self];
            LXVariable *arg2 = [LXVariable variableWithName:@"init" type:[LXClassNumber classNumber]];
            LXVariable *arg3 = [LXVariable variableWithName:@"plain" type:[LXClassBool classBool]];
  
            findFunction.returnTypes = @[retType1, retType2];
            findFunction.arguments = @[arg1, arg2, arg3];
        }
        
        LXVariable *formatFunction = [LXVariable functionWithName:@"format"];
        
        {
            LXVariable *retType = [LXVariable variableWithType:self];
            LXVariable *arg = [LXVariable variableWithName:@"..." type:[LXClassNumber classNumber]];
            
            formatFunction.returnTypes = @[retType];
            formatFunction.arguments = @[arg];
        }

        LXVariable *gmatchFunction = [LXVariable functionWithName:@"gmatch"];
        
        {
            LXVariable *retType = [LXVariable variableWithType:[LXClassFunction classFunction]];

            LXVariable *arg = [LXVariable variableWithName:@"pattern" type:self];
            
            gmatchFunction.returnTypes = @[retType];
            gmatchFunction.arguments = @[arg];
        }

        LXVariable *gsubFunction = [LXVariable functionWithName:@"gsub"];
        
        {
            LXVariable *retType = [LXVariable variableWithType:self];
            
            LXVariable *arg1 = [LXVariable variableWithName:@"pattern" type:self];
            LXVariable *arg2 = [LXVariable variableWithName:@"repl" type:self];
            LXVariable *arg3 = [LXVariable variableWithName:@"n" type:[LXClassNumber classNumber]];
            
            gsubFunction.returnTypes = @[retType];
            gsubFunction.arguments = @[arg1, arg2, arg3];
        }
        
        LXVariable *lenFunction = [LXVariable functionWithName:@"len"];
        
        {
            LXVariable *retType = [LXVariable variableWithType:[LXClassNumber classNumber]];
            
            lenFunction.returnTypes = @[retType];
            lenFunction.arguments = @[];
        }

        LXVariable *lowerFunction = [LXVariable functionWithName:@"lower"];
        
        {
            LXVariable *retType = [LXVariable variableWithType:self];
            
            lowerFunction.returnTypes = @[retType];
            lowerFunction.arguments = @[];
        }

        LXVariable *matchFunction = [LXVariable functionWithName:@"match"];
        
        {
            LXVariable *retType = [LXVariable variableWithType:self];
            
            LXVariable *arg1 = [LXVariable variableWithName:@"pattern" type:self];
            LXVariable *arg2 = [LXVariable variableWithName:@"init" type:[LXClassNumber classNumber]];
            
            matchFunction.returnTypes = @[retType];
            matchFunction.arguments = @[arg1, arg2];
        }

        LXVariable *repFunction = [LXVariable functionWithName:@"rep"];
        
        {
            LXVariable *retType = [LXVariable variableWithType:self];
            
            LXVariable *arg1 = [LXVariable variableWithName:@"n" type:[LXClassNumber classNumber]];
            LXVariable *arg2 = [LXVariable variableWithName:@"sep" type:self];
            
            repFunction.returnTypes = @[retType];
            repFunction.arguments = @[arg1, arg2];
        }
        
        LXVariable *reverseFunction = [LXVariable functionWithName:@"reverse"];
        
        {
            LXVariable *retType = [LXVariable variableWithType:self];
            
            reverseFunction.returnTypes = @[retType];
            reverseFunction.arguments = @[];
        }
        
        LXVariable *subFunction = [LXVariable functionWithName:@"sub"];
        
        {
            LXVariable *retType = [LXVariable variableWithType:self];
            
            LXVariable *arg1 = [LXVariable variableWithName:@"i" type:[LXClassNumber classNumber]];
            LXVariable *arg2 = [LXVariable variableWithName:@"j" type:[LXClassNumber classNumber]];
            
            subFunction.returnTypes = @[retType];
            subFunction.arguments = @[arg1, arg2];
        }
        
        LXVariable *upperFunction = [LXVariable functionWithName:@"upper"];

        {
            LXVariable *retType = [LXVariable variableWithType:self];

            upperFunction.returnTypes = @[retType];
            upperFunction.arguments = @[];
        }
        
        self.variables = @[byteFunction, charFunction, dumpFunction, findFunction, formatFunction,
                           gmatchFunction, gsubFunction, lenFunction, lowerFunction, matchFunction,
                           repFunction, reverseFunction, subFunction, upperFunction];
    }
    
    return self;
}

+ (LXClassString *)classString {
    static LXClassString *class = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        class = [[LXClassString alloc] init];
    });
    
    return class;
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
    static LXClassTable *class = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        class = [[LXClassTable alloc] init];
    });
    
    return class;
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
    static LXClassFunction *class = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        class = [[LXClassFunction alloc] init];
    });
    
    return class;
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