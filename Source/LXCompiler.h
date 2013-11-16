//
//  LXCompiler.h
//  LuaX
//
//  Created by Noah Hilt on 8/8/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXNode.h"
#import "LXClass.h"

@interface LXCompiler : NSObject

@property (nonatomic, retain) NSString *string;
@property (nonatomic, retain) LXScope *globalScope;
@property (nonatomic, retain) NSMutableDictionary *baseTypeMap;
@property (nonatomic, retain) NSMutableDictionary *typeMap;
@property (nonatomic, retain) NSMutableArray *tokens;

- (void)compile:(NSString *)string;
@end
