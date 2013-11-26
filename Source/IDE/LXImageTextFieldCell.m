//
//  LXImageTextFieldCell.m
//  Luax
//
//  Created by Noah Hilt on 11/26/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXImageTextFieldCell.h"

@implementation LXImageTextFieldCell

- (id)copyWithZone:(NSZone *)zone {
	LXImageTextFieldCell *cell = (LXImageTextFieldCell *)[super copyWithZone:zone];
	
	cell.image = self.image;
	cell->highlightImage = highlightImage;
    
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

- (NSRect)imageFrameForCellFrame:(NSRect)cellFrame {
	if(self.image != nil) {
		NSRect imageFrame;
		
		imageFrame.size = [self.image size];
		imageFrame.origin = cellFrame.origin;
		imageFrame.origin.x += 3;
		imageFrame.origin.y += ceil((cellFrame.size.height - imageFrame.size.height) / 2);
		
		return imageFrame;
	}
	else
        return NSZeroRect;
}

- (void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent {
	NSRect textFrame, imageFrame;
	
	NSDivideRect (aRect, &imageFrame, &textFrame, 3 + [self.image size].width, NSMinXEdge);
	
	[super editWithFrame: textFrame inView: controlView editor:textObj delegate:anObject event: theEvent];
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength {
	NSRect textFrame, imageFrame;
	
	NSDivideRect (aRect, &imageFrame, &textFrame, 3 + [self.image size].width, NSMinXEdge);
	
	[super selectWithFrame: textFrame inView: controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
	if(self.image != nil) {
		NSSize  imageSize;
		NSRect  imageFrame;
		
		imageSize = [self.image size];
		
		NSDivideRect(cellFrame, &imageFrame, &cellFrame, 3 + imageSize.width, NSMinXEdge);
		
		if ([self drawsBackground]) {
			[[self backgroundColor] set];
			
			NSRectFill(imageFrame);
		}
		
		imageFrame.origin.x += 3;
		imageFrame.size = imageSize;
		
		if(self.modified) {
            [highlightImage drawInRect:imageFrame fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0 respectFlipped:YES hints:nil];
		}
		else {
            [self.image drawInRect:imageFrame fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0 respectFlipped:YES hints:nil];
		}
	}
	
	[super drawWithFrame:cellFrame inView:controlView];
}

- (NSSize)cellSize {
	NSSize cellSize = [super cellSize];
	
	cellSize.width += (self.image ? [self.image size].width : 0) + 3;
	
	return cellSize;
}

@end
