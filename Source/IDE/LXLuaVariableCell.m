//
//  LXLuaVariableCell.m
//  Luax
//
//  Created by Noah Hilt on 12/20/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXLuaVariableCell.h"
#import "LXLuaVariable.h"

@implementation LXLuaVariableCell

- (id)copyWithZone:(NSZone *)zone {
	LXLuaVariableCell *cell = (LXLuaVariableCell *)[super copyWithZone:zone];
	
	cell->name = [name copyWithZone:zone];
    cell->type = [type copyWithZone:zone];
    cell->value = [value copyWithZone:zone];

	return cell;
}

- (NSString *)stringFromVariable:(LXLuaVariable *)var {
    switch(var.type) {
        case LXLuaVariableTypeBoolean:
        case LXLuaVariableTypeNumber:
            return [var.value stringValue];
        case LXLuaVariableTypeString:
            return var.value;
        case LXLuaVariableTypeTable:
        case LXLuaVariableTypeFunction:
        case LXLuaVariableTypeUserdata:
        case LXLuaVariableTypeThread:
        case LXLuaVariableTypeLightuserdata:
            return [NSString stringWithFormat:@"0x%02x", [var.value intValue]];
        default:
        case LXLuaVariableTypeNil:
            return @"nil";
    }
}

- (NSString *)stringFromVariableType:(LXLuaVariable *)var {
    switch(var.type) {
        case LXLuaVariableTypeBoolean:
            return @" = (bool) ";
        case LXLuaVariableTypeNumber:
            return @" = (number) ";
        case LXLuaVariableTypeString:
            return @" = (string) ";
        case LXLuaVariableTypeTable:
            return @" = (table) ";
        case LXLuaVariableTypeFunction:
            return @" = (function) ";
        case LXLuaVariableTypeUserdata:
            return @" = (userdata) ";
        case LXLuaVariableTypeThread:
            return @" = (thread) ";
        case LXLuaVariableTypeLightuserdata:
            return @" = (lightuserdata) ";
        default:
        case LXLuaVariableTypeNil:
            return @" = (nil) ";
    }
}

- (void)setObjectValue:(NSObject<NSCopying> *)obj {
    nameWidth = 0;
    
    if([obj isKindOfClass:[LXLuaVariable class]]) {
        LXLuaVariable *var = (LXLuaVariable *)obj;
        
        if(var.scope == LXLuaVariableScopeLocal) {
            name = [NSString stringWithFormat:@"[L]%@", var.key];
        }
        else if(var.scope == LXLuaVariableScopeUpvalue) {
            name = [NSString stringWithFormat:@"[U]%@", var.key];
        }
        else if(var.scope == LXLuaVariableScopeGlobal) {
            name = [NSString stringWithFormat:@"[G]%@", var.key];
        }
        else {
            name = [var.key copy];
        }
        
        type = [self stringFromVariableType:var];
        value = [self stringFromVariable:var];
        
        nameWidth += [name sizeWithAttributes:@{NSFontAttributeName : [NSFont boldSystemFontOfSize:12]}].width;
        nameWidth += [type sizeWithAttributes:@{NSFontAttributeName : [NSFont systemFontOfSize:12]}].width;
        
        [super setObjectValue:value];
    }
    else {
        [super setObjectValue:obj];
    }
}

- (void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent {
    aRect.origin.x += nameWidth;
    aRect.size.width -= nameWidth;
    
	[super editWithFrame: aRect inView:controlView editor:textObj delegate:anObject event: theEvent];
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength {
	aRect.origin.x += nameWidth;
    aRect.size.width -= nameWidth;
    
	[super selectWithFrame: aRect inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    BOOL highlighted = NO;
    
    if(self.isHighlighted) {
        highlighted = YES;
        
        if([[[controlView window] firstResponder] isKindOfClass:[NSView class]]) {
            NSView *view = (NSView *)[[controlView window] firstResponder];
            
            if(![view isDescendantOf:controlView]) {
                highlighted = NO;
            }
        }
    }
    
    NSDictionary *nameAttrs = @{NSForegroundColorAttributeName : highlighted ? [NSColor whiteColor] : [NSColor colorWithCalibratedWhite:0.8 alpha:1], NSFontAttributeName : [NSFont boldSystemFontOfSize:12]};
    NSDictionary *typeAttrs = @{NSForegroundColorAttributeName : highlighted ? [NSColor whiteColor] : [NSColor colorWithCalibratedWhite:0.8 alpha:1], NSFontAttributeName : [NSFont systemFontOfSize:12]};
    
    NSRect bounds = NSInsetRect(cellFrame, 2, 0);
    NSRect titleRect = [self titleRectForBounds:bounds];
    NSPoint origin = NSMakePoint(titleRect.origin.x, CGRectGetMidY(titleRect)-[name sizeWithAttributes:nameAttrs].height * 0.5);

    [name drawAtPoint:origin withAttributes:nameAttrs];
    origin.x += [name sizeWithAttributes:nameAttrs].width;
    [type drawAtPoint:origin withAttributes:typeAttrs];
    origin.x += [type sizeWithAttributes:typeAttrs].width;

    cellFrame.origin.x += nameWidth;
    cellFrame.size.width -= nameWidth;
    
	[super drawWithFrame:cellFrame inView:controlView];
}

- (NSSize)cellSize {
	NSSize cellSize = [super cellSize];
	
	cellSize.width -= nameWidth;
    
	return cellSize;
}

@end
