//
//  LXLuaCallStackIndex.h
//  Luax
//
//  Created by Noah Hilt on 12/20/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LXLuaCallStackIndex : NSObject
@property (nonatomic, retain) NSString *source;
@property (nonatomic, retain) NSString *function;
@property (nonatomic) BOOL error;
@property (nonatomic) NSInteger line;
@property (nonatomic) NSInteger firstLine;
@property (nonatomic) NSInteger lastLine;
@property (nonatomic) NSInteger originalLine;
@property (nonatomic, retain) NSArray *localVariables;
@property (nonatomic, retain) NSArray *upVariables;
@end
