//
//  LXVariable.x
//  LuaX
//
//  Created by Noah Hilt on 8/11/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXClass.h"

@interface LXVariable : NSObject
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) LXClass *type;
@property (nonatomic, assign) BOOL isGlobal;
@property (nonatomic, readonly) BOOL isDefined;

- (NSString *)autoCompleteString;
@end
