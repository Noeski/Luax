//
//  LXCompiler.h
//  LuaX
//
//  Created by Noah Hilt on 8/8/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXParser.h"
#import "LXNode.h"

@interface LXContext : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) LXParser *parser;
@property (nonatomic, strong) LXScope *scope;
@property (nonatomic, strong) LXNodeBlock *block;

- (id)initWithName:(NSString *)name;
@end

@interface LXCompiler : NSObject
@property (nonatomic, strong) LXScope *globalScope;
@property (nonatomic, strong) NSMutableDictionary *fileMap;
@property (nonatomic, strong) NSMutableDictionary *baseTypeMap;
@property (nonatomic, strong) NSMutableDictionary *typeMap;

- (void)compile:(NSString *)name string:(NSString *)string;
- (void)save;

@end
