//
//  NSView+BackgroundColor.m
//  Luax
//
//  Created by Noah Hilt on 12/5/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "NSView+BackgroundColor.h"

@implementation NSView(BackgroundColor)
- (void)setBackgroundColor:(NSColor *)color {
    [self setWantsLayer:YES];
    
    self.layer.backgroundColor = color.CGColor;
}
@end

@implementation LXBackgroundColorView

- (void)setBackgroundColor:(NSColor *)backgroundColor {
    _backgroundColor = backgroundColor;
    
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(NSRect)dirtyRect {
    [self.backgroundColor setFill];
    [[NSBezierPath bezierPathWithRect:self.bounds] fill];
    
    [super drawRect:dirtyRect];
}

@end
