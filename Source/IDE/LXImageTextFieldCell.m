//
//  LXImageTextFieldCell.m
//  Luax
//
//  Created by Noah Hilt on 11/26/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXImageTextFieldCell.h"

@implementation LXImageTextFieldCell

- (id)init {
    if(self = [super init]) {
        _cFlags.vCentered = 1;
    }
    
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
	LXImageTextFieldCell *cell = (LXImageTextFieldCell *)[super copyWithZone:zone];
	
	cell.image = self.image;
    cell.accessoryImage = self.accessoryImage;
    cell->_cFlags.vCentered = 1;
    
	return cell;
}

- (void)setImage:(NSImage *)image{
	if(image != _image) {
		_image = image;
		
		NSSize iconSize = [image size];
		NSRect iconRect = {NSZeroPoint, iconSize};
		highlightImage = [[NSImage alloc] initWithSize:iconSize];
		
		[highlightImage lockFocus];
        
		[image drawInRect: iconRect fromRect:NSZeroRect operation:NSCompositeCopy fraction: 1.0];
		
		[[[NSColor blackColor] colorWithAlphaComponent: .5] set];
		NSRectFillUsingOperation(iconRect, NSCompositeSourceAtop);
		[highlightImage unlockFocus];
	}
}

- (void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent {
	NSRect textFrame, imageFrame, accessoryImageFrame;
	
	NSDivideRect(aRect, &imageFrame, &textFrame, 3 + [self.image size].width, NSMinXEdge);
    NSDivideRect(textFrame, &textFrame, &accessoryImageFrame, textFrame.size.width - (3 + [self.accessoryImage size].width), NSMinXEdge);

	[super editWithFrame:textFrame inView: controlView editor:textObj delegate:anObject event: theEvent];
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength {
	NSRect textFrame, imageFrame, accessoryImageFrame;
	
	NSDivideRect(aRect, &imageFrame, &textFrame, 3 + [self.image size].width, NSMinXEdge);
    NSDivideRect(textFrame, &textFrame, &accessoryImageFrame, textFrame.size.width - (3 + [self.accessoryImage size].width), NSMinXEdge);

	[super selectWithFrame:textFrame inView: controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
	if(self.image != nil) {
		NSSize  imageSize, accessoryImageSize;
		NSRect  imageFrame, accessoryImageFrame;
        
		imageSize = [self.image size];
        accessoryImageSize = [self.accessoryImage size];

		NSDivideRect(cellFrame, &imageFrame, &cellFrame, 3 + imageSize.width, NSMinXEdge);
        NSDivideRect(cellFrame, &cellFrame, &accessoryImageFrame, cellFrame.size.width - (3 + accessoryImageSize.width), NSMinXEdge);

		if([self drawsBackground]) {
			[[self backgroundColor] set];
			
			NSRectFill(imageFrame);
		}
		
		imageFrame.origin.x += 3;
        imageFrame.origin.y += 3;
		imageFrame.size = imageSize;
        
        accessoryImageFrame.origin.x += 3;
        accessoryImageFrame.origin.y += 3;
        accessoryImageFrame.size = accessoryImageSize;

		if(self.modified) {
            [highlightImage drawInRect:imageFrame fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0 respectFlipped:YES hints:nil];
		}
		else {
            [self.image drawInRect:imageFrame fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0 respectFlipped:YES hints:nil];
		}
        
        [self.accessoryImage drawInRect:accessoryImageFrame fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0 respectFlipped:YES hints:nil];
	}
	
	[super drawWithFrame:cellFrame inView:controlView];
}

- (NSSize)cellSize {
	NSSize cellSize = [super cellSize];
	
	cellSize.width += (self.image ? [self.image size].width : 0) + 3;
	
	return cellSize;
}

@end
