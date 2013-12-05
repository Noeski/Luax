//
//  NSView+BackgroundColor.h
//  Luax
//
//  Created by Noah Hilt on 12/5/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface NSView(BackgroundColor)
- (void)setBackgroundColor:(NSColor *)color;
@end

@interface LXBackgroundColorView : NSView
@property (nonatomic, strong) NSColor *backgroundColor;
@end
