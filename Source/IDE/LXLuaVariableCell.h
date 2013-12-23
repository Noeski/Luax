//
//  LXLuaVariableCell.h
//  Luax
//
//  Created by Noah Hilt on 12/20/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "LXTextFieldCell.h"

@class LXLuaVariable;
@interface LXLuaVariableCell : LXTextFieldCell {
@private
    NSString *name;
    NSString *type;
    NSString *value;

    LXLuaVariable *variable;

    CGFloat nameWidth;

    NSProgressIndicator *progressView;
}
@end
