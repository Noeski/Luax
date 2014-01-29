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
        
        
        LXFunction *byteFunction = [[LXFunction alloc] init];
        byteFunction.name = @"byte";
        
        {
            LXVariable *retType = [[LXVariable alloc] init];
            retType.type = [LXClassNumber classNumber];
            
            LXVariable *arg1 = [[LXVariable alloc] init];
            arg1.name = @"i";
            arg1.type = [LXClassNumber classNumber];
            
            LXVariable *arg2 = [[LXVariable alloc] init];
            arg2.name = @"j";
            arg2.type = [LXClassNumber classNumber];
            
            byteFunction.returnTypes = @[retType];
            byteFunction.arguments = @[arg1, arg2];
        }
        
        LXFunction *charFunction = [[LXFunction alloc] init];
        charFunction.name = @"char";
        
        {
            LXVariable *retType = [[LXVariable alloc] init];
            retType.type = self;
            
            LXVariable *arg = [[LXVariable alloc] init];
            arg.name = @"...";
            arg.type = [LXClassNumber classNumber];
            
            charFunction.returnTypes = @[retType];
            charFunction.arguments = @[arg];
        }

        LXFunction *dumpFunction = [[LXFunction alloc] init];
        dumpFunction.name = @"dump";
        
        {
            LXVariable *retType = [[LXVariable alloc] init];
            retType.type = self;
            
            LXVariable *arg = [[LXVariable alloc] init];
            arg.name = @"function";
            arg.type = [LXClassFunction classFunction];
            
            dumpFunction.returnTypes = @[retType];
            dumpFunction.arguments = @[arg];
        }
        
        LXFunction *findFunction = [[LXFunction alloc] init];
        findFunction.name = @"find";
        
        {
            LXVariable *retType1 = [[LXVariable alloc] init];
            retType1.type = [LXClassNumber classNumber];
            
            LXVariable *retType2 = [[LXVariable alloc] init];
            retType2.type = [LXClassNumber classNumber];
            
            LXVariable *arg1 = [[LXVariable alloc] init];
            arg1.name = @"pattern";
            arg1.type = self;
            
            LXVariable *arg2 = [[LXVariable alloc] init];
            arg2.name = @"init";
            arg2.type = [LXClassNumber classNumber];
            
            LXVariable *arg3 = [[LXVariable alloc] init];
            arg3.name = @"plain";
            arg3.type = [LXClassBool classBool];
            
            findFunction.returnTypes = @[retType1, retType2];
            findFunction.arguments = @[arg1, arg2, arg3];
        }
        
        LXFunction *formatFunction = [[LXFunction alloc] init];
        formatFunction.name = @"format";
        
        {
            LXVariable *retType = [[LXVariable alloc] init];
            retType.type = self;
            
            LXVariable *arg = [[LXVariable alloc] init];
            arg.name = @"...";
            arg.type = [LXClassNumber classNumber];
            
            formatFunction.returnTypes = @[retType];
            formatFunction.arguments = @[arg];
        }

        LXFunction *gmatchFunction = [[LXFunction alloc] init];
        gmatchFunction.name = @"gmatch";
        
        {
            LXVariable *retType = [[LXVariable alloc] init];
            retType.type = [LXClassFunction classFunction];
            
            LXVariable *arg = [[LXVariable alloc] init];
            arg.name = @"pattern";
            arg.type = self;
            
            gmatchFunction.returnTypes = @[retType];
            gmatchFunction.arguments = @[arg];
        }

        LXFunction *gsubFunction = [[LXFunction alloc] init];
        gsubFunction.name = @"gsub";
        
        {
            LXVariable *retType = [[LXVariable alloc] init];
            retType.type = self;
            
            LXVariable *arg1 = [[LXVariable alloc] init];
            arg1.name = @"pattern";
            arg1.type = self;
            
            LXVariable *arg2 = [[LXVariable alloc] init];
            arg2.name = @"repl";
            arg2.type = self;
            
            LXVariable *arg3 = [[LXVariable alloc] init];
            arg3.name = @"n";
            arg3.type = [LXClassNumber classNumber];
            
            gsubFunction.returnTypes = @[retType];
            gsubFunction.arguments = @[arg1, arg2, arg3];
        }
        
        LXFunction *lenFunction = [[LXFunction alloc] init];
        lenFunction.name = @"len";
        
        {
            LXVariable *retType = [[LXVariable alloc] init];
            retType.type = [LXClassNumber classNumber];
            
            lenFunction.returnTypes = @[retType];
            lenFunction.arguments = @[];
        }

        LXFunction *lowerFunction = [[LXFunction alloc] init];
        lowerFunction.name = @"lower";
        
        {
            LXVariable *retType = [[LXVariable alloc] init];
            retType.type = self;
            
            lowerFunction.returnTypes = @[retType];
            lowerFunction.arguments = @[];
        }

        LXFunction *matchFunction = [[LXFunction alloc] init];
        matchFunction.name = @"match";
        
        {
            LXVariable *retType = [[LXVariable alloc] init];
            retType.type = self;
            
            LXVariable *arg1 = [[LXVariable alloc] init];
            arg1.name = @"pattern";
            arg1.type = self;
            
            LXVariable *arg2 = [[LXVariable alloc] init];
            arg2.name = @"init";
            arg2.type = [LXClassNumber classNumber];
            
            matchFunction.returnTypes = @[retType];
            matchFunction.arguments = @[arg1, arg2];
        }

        LXFunction *repFunction = [[LXFunction alloc] init];
        repFunction.name = @"rep";
        
        {
            LXVariable *retType = [[LXVariable alloc] init];
            retType.type = self;
            
            LXVariable *arg1 = [[LXVariable alloc] init];
            arg1.name = @"n";
            arg1.type = [LXClassNumber classNumber];
            
            LXVariable *arg2 = [[LXVariable alloc] init];
            arg2.name = @"sep";
            arg2.type = self;
            
            repFunction.returnTypes = @[retType];
            repFunction.arguments = @[arg1, arg2];
        }
        
        LXFunction *reverseFunction = [[LXFunction alloc] init];
        reverseFunction.name = @"reverse";
        
        {
            LXVariable *retType = [[LXVariable alloc] init];
            retType.type = self;
            
            reverseFunction.returnTypes = @[retType];
            reverseFunction.arguments = @[];
        }
        
        LXFunction *subFunction = [[LXFunction alloc] init];
        subFunction.name = @"sub";
        
        {
            LXVariable *retType = [[LXVariable alloc] init];
            retType.type = self;
            
            LXVariable *arg1 = [[LXVariable alloc] init];
            arg1.name = @"i";
            arg1.type = [LXClassNumber classNumber];
            
            LXVariable *arg2 = [[LXVariable alloc] init];
            arg2.name = @"j";
            arg2.type = [LXClassNumber classNumber];
            
            subFunction.returnTypes = @[retType];
            subFunction.arguments = @[arg1, arg2];
        }
        
        LXFunction *upperFunction = [[LXFunction alloc] init];
        upperFunction.name = @"upper";

        {
            LXVariable *retType = [[LXVariable alloc] init];
            retType.type = self;
            
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