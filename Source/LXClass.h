//
//  LXClass.h
//  LuaX
//
//  Created by Noah Hilt on 7/28/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

@interface LXClass : NSObject
@property (nonatomic, retain) NSString *name;
@property (nonatomic, retain) LXClass *parent;
@property (nonatomic, retain) NSArray *variables;
@property (nonatomic, retain) NSArray *functions;
@property (nonatomic, assign) BOOL isDefined;
@end
