//
//  LXClass.h
//  LuaX
//
//  Created by Noah Hilt on 7/28/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

@class LXExpr;
@class LXClassStmt;
@interface LXClass : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) LXClass *parent;
@property (nonatomic, strong) NSArray *variables;
@property (nonatomic, strong) NSArray *functions;
@property (nonatomic, assign) BOOL isDefined;
@property (nonatomic, strong) LXExpr *defaultExpression;
@property (nonatomic, weak) LXClassStmt *statement;
@end

@interface LXClassNumber : LXClass
+ (LXClassNumber *)classNumber;
@end

@interface LXClassBool : LXClass
+ (LXClassBool *)classBool;
@end

@interface LXClassString : LXClass
+ (LXClassString *)classString;
@end

@interface LXClassTable : LXClass
+ (LXClassTable *)classTable;
@end

@interface LXClassFunction : LXClass
+ (LXClassFunction *)classFunction;
@end

@interface LXClassVar : LXClass
+ (LXClassVar *)classVar;
@end

@interface LXClassBase : LXClass
@end