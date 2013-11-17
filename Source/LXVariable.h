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
@property (nonatomic, assign) BOOL isGlobal;
@property (nonatomic, assign) BOOL isMember;
@property (nonatomic, readonly) BOOL isDefined;

- (NSString *)autoCompleteString;
@end
