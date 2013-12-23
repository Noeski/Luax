#import "LXGutterView.h"
#import "LXProjectFileView.h"

#define CORNER_RADIUS	5.0
#define MARKER_HEIGHT	13.0

@implementation LXBreakpointMarker

- (id)initWithImage:(NSImage *)aImage line:(NSUInteger)aLine {
	if(self = [super init]) {
		_yPos = 0.0f;
		_line = aLine;
		_image = aImage;
	}
	
	return self;
}

@end

@implementation LXGutterView

static NSImage *markerImage = nil;

- (void)drawMarkerImageIntoRep:(id)rep {
	NSBezierPath *path;
	NSRect rect;
	
	rect = NSMakeRect(2.0, 0.0, [rep size].width - 2.0, [rep size].height);
	
	path = [NSBezierPath bezierPath];
	[path moveToPoint:NSMakePoint(NSMaxX(rect), NSMinY(rect) + NSHeight(rect) / 2)];
	[path lineToPoint:NSMakePoint(NSMaxX(rect) - 5.0, NSMaxY(rect))];
	
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(rect) + CORNER_RADIUS, NSMaxY(rect) - CORNER_RADIUS) radius:CORNER_RADIUS startAngle:90 endAngle:180];
	
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(rect) + CORNER_RADIUS, NSMinY(rect) + CORNER_RADIUS) radius:CORNER_RADIUS startAngle:180 endAngle:270];
	[path lineToPoint:NSMakePoint(NSMaxX(rect) - 5.0, NSMinY(rect))];
	[path closePath];
	
	[[NSColor colorWithCalibratedRed:0.003 green:0.56 blue:0.85 alpha:1.0] set];
	[path fill];
	
	[[NSColor colorWithCalibratedRed:0 green:0.44 blue:0.8 alpha:1.0] set];
	
	[path setLineWidth:2.0];
	[path stroke];
}

- (NSImage *)markerImage {
	if(markerImage == nil) {
		NSCustomImageRep *rep;
		NSSize size = NSMakeSize(40, 13);
		markerImage = [[NSImage alloc] initWithSize:size];
		rep = [[NSCustomImageRep alloc] initWithDrawSelector:@selector(drawMarkerImageIntoRep:) delegate:self];
		[rep setSize:size];
		[markerImage addRepresentation:rep];
	}
	
	return markerImage;
}

- (id)initWithFrame:(NSRect)frame {
	if (self = [super initWithFrame:frame]) {
		_breakpointMarkers = [[NSMutableArray alloc] init];
		
		[self setAutoresizingMask:NSViewHeightSizable];
    }
    
	return self;
}

- (LXBreakpointMarker *)markerAtLine:(NSUInteger)line {
	for(int i = 0; i < [self.breakpointMarkers count]; ++i) {
		LXBreakpointMarker *marker = [self.breakpointMarkers objectAtIndex:i];
		if(marker.line == line)
			return marker;
	}
	
	return nil;
}

- (void)setOffset:(NSInteger)offset {
    _offset = offset;
    
    [self setNeedsDisplay:YES];
}

- (void)setLineNumberRange:(NSRange)lineNumberRange {
    _lineNumberRange = lineNumberRange;
    
    [self setNeedsDisplay:YES];
}

- (void)drawViewBackgroundInRect:(NSRect)rect {
	[[NSColor colorWithCalibratedWhite:0.2 alpha:1.0] setFill];
    [[NSBezierPath bezierPathWithRect:rect] fill];
    
	NSRect visibleRect = NSZeroRect;//[((NSClipView *)[self superview]) documentVisibleRect];
    
    for(LXBreakpointMarker *marker in self.breakpointMarkers) {
        if(!marker.visible)
            continue;
        
		markerImage = [marker image];
		NSSize markerSize = [markerImage size];
		NSRect markerRect = NSMakeRect(40.0f - [markerImage size].width - 1.0f, self.bounds.size.height - marker.yPos - markerSize.height + visibleRect.origin.y, markerSize.width, markerSize.height);
		
		if(NSIntersectsRect(rect, markerRect)) {
			[markerImage drawInRect:markerRect fromRect:NSMakeRect(0, 0, markerSize.width, markerSize.height) operation:NSCompositeSourceOver fraction:1.0];	
		}
	}
}

- (void)drawRect:(NSRect)rect {
	[super drawRect:rect];
	
    [self drawViewBackgroundInRect:rect];
    
	NSRect bounds = [self bounds]; 
	
	if([self needsToDrawRect:NSMakeRect(bounds.size.width - 1, 0, 1, bounds.size.height)] == YES) {
        NSFont *font = [[NSFontManager sharedFontManager]
                        fontWithFamily:@"Menlo"
                        traits:0
                        weight:0
                        size:8];
        NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
        [style setAlignment:NSRightTextAlignment];
        
        NSMutableDictionary *textAttributes = [NSMutableDictionary dictionaryWithDictionary:@{NSFontAttributeName : font, NSParagraphStyleAttributeName : style}];
        
        NSPoint point = NSMakePoint(0, self.bounds.size.height + self.offset - self.document.textView.lineHeight);
        
        for(NSInteger i = 0; i < self.lineNumberRange.length; ++i) {
            textAttributes[NSForegroundColorAttributeName] = [NSColor colorWithCalibratedWhite:0.8 alpha:1];

            NSInteger lineNumber = self.lineNumberRange.location+i+1;
            
            for(LXBreakpointMarker *marker in self.breakpointMarkers) {
                if(marker.line == lineNumber) {
                    textAttributes[NSForegroundColorAttributeName] = [NSColor whiteColor];
                    break;
                }
            }
            
            NSRect stringBounds = NSMakeRect(point.x, point.y, self.bounds.size.width-4, self.document.textView.lineHeight);
            NSString *st = [NSString stringWithFormat:@"%ld", lineNumber];
            NSSize stringSize = [st sizeWithAttributes:textAttributes];
            NSPoint stringOrigin = NSMakePoint(point.x, NSMidY(stringBounds) - (stringSize.height * 0.5));
            
            [st drawInRect:NSMakeRect(stringOrigin.x, stringOrigin.y, stringBounds.size.width, stringSize.height) withAttributes:textAttributes];
            point.y -= self.document.textView.lineHeight;
        }
        
		[[NSColor lightGrayColor] set];
        
        NSInteger offset = self.offset < 0 ? self.offset % self.document.textView.lineHeight + self.document.textView.lineHeight : self.offset;
        
		NSBezierPath *dottedLine = [NSBezierPath bezierPathWithRect:NSMakeRect(bounds.size.width, -offset, 0, bounds.size.height + offset)];
		CGFloat dash[2];
		dash[0] = 1.0;
		dash[1] = 2.0;
		[dottedLine setLineDash:dash count:2 phase:1.0];
		[dottedLine stroke];
	}
}

- (BOOL)isOpaque {
	return YES;
}

- (void)mouseDown:(NSEvent *)theEvent {
	NSUInteger line = [self.document lineNumberForLocation:[theEvent locationInWindow]];
	
	if (line != NSNotFound) {
		for(int i = 0; i < [self.breakpointMarkers count]; ++i) {
			LXBreakpointMarker *marker = [self.breakpointMarkers objectAtIndex:i];
			if(marker.line == line) {
				[self.breakpointMarkers removeObjectAtIndex:i];
				[self setNeedsDisplay:YES];
				
                [self.document updateLineNumbers];

                [self.document removeBreakpoint:line];
				return;
			}
		}
		
		LXBreakpointMarker *marker = [[LXBreakpointMarker alloc] initWithImage:[self markerImage] line:line];
		[self.breakpointMarkers addObject:marker];
		
		[self.document updateLineNumbers];
        [self.document addBreakpoint:line];
	}
}

- (void)scrollWheel:(NSEvent *)theEvent {
   //Disable scroll view gesture
}

@end
