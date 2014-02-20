//
//  LXBlurWindow.m
//  Luax
//
//  Created by Noah Hilt on 2/17/14.
//  Copyright (c) 2014 Noah Hilt. All rights reserved.
//

#import "LXBlurWindow.h"

typedef void * CGSConnection;
extern OSStatus CGSSetWindowBackgroundBlurRadius(CGSConnection connection, NSInteger windowNumber, int radius);
extern CGSConnection CGSDefaultConnectionForThread();

@interface LXBlurWindow()
@property (nonatomic, strong) NSColor *windowColor;
@end

@implementation LXBlurWindow

- (id)initWithFrame:(CGRect)frame {
    if(self = [super initWithContentRect:frame
                               styleMask:NSBorderlessWindowMask
                                 backing:NSBackingStoreBuffered
                                   defer:NO]) {
        self.alphaValue = 0.0f;
        self.hasShadow = NO;
        
        [self setOpaque:NO];
        
        CGSConnection connection = CGSDefaultConnectionForThread();
        CGSSetWindowBackgroundBlurRadius(connection, [self windowNumber], 8);
    }
    
    return self;
}

- (void)setFrame:(NSRect)frameRect display:(BOOL)flag {
    [self updateBackground:frameRect];
    
    [super setFrame:frameRect display:YES];
}

- (void)setBackgroundColor:(NSColor *)color {
    self.windowColor = color;
    
    [self updateBackground:self.frame];
}

- (void)updateBackground:(NSRect)frame {
    [super setBackgroundColor:[self backgroundColorPatternImage:frame color:self.windowColor]];
}

- (NSColor *)backgroundColorPatternImage:(CGRect)frame color:(NSColor *)color {
    if(frame.size.width <= 0 || frame.size.height <= 0)
        return nil;
    
    NSImage *bg = [[NSImage alloc] initWithSize:frame.size];
    NSRect bgRect = NSZeroRect;
    bgRect.size = [bg size];
    
    [bg lockFocus];
    NSBezierPath *bgPath = [NSBezierPath bezierPathWithRoundedRect:CGRectMake(0, 0, frame.size.width, frame.size.height) xRadius:4 yRadius:4];
    [NSGraphicsContext saveGraphicsState];
    [bgPath addClip];
    
    // Draw background.
    [color set];
    [bgPath fill];
    
    [NSGraphicsContext restoreGraphicsState];
    [bg unlockFocus];
    
    return [NSColor colorWithPatternImage:bg];
}

@end
