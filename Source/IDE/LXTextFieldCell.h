//
//  LXTextFieldCell.h
//  Luax
//
//  Created by Noah Hilt on 11/26/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface LXTextFieldCell : NSTextFieldCell {
@private
	NSImage *highlightImage;
}

@property (nonatomic, assign) BOOL modified;
@property (nonatomic, assign) BOOL selected;
@property (nonatomic, retain) NSImage *accessoryImage;

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
- (NSSize)cellSize;
@end
