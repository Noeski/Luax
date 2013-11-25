#import "LXGutterView.h"
#import "LXDocument.h"

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
	if (markerImage == nil) {
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
		
		[self setContinuousSpellCheckingEnabled:NO];
		[self setAllowsUndo:NO];
		[self setAllowsDocumentBackgroundColorChange:NO];
		[self setRichText:NO];
		[self setUsesFindPanel:NO];
		[self setUsesFontPanel:NO];
		[self setAlignment:NSRightTextAlignment];
		[self setEditable:NO];
		[self setSelectable:NO];
		[[self textContainer] setContainerSize:NSMakeSize(40, FLT_MAX)];
		[self setVerticallyResizable:YES];
		[self setHorizontallyResizable:YES];
		[self setAutoresizingMask:NSViewHeightSizable];
		
		[self setFont:[[NSFontManager sharedFontManager]
                       fontWithFamily:@"Menlo"
                       traits:NSBoldFontMask
                       weight:0
                       size:11]];
        
		[self setTextColor:[NSColor colorWithCalibratedWhite:0.4 alpha:1.0]];
		[self setInsertionPointColor:[NSColor textColor]];
		[self setBackgroundColor:[NSColor colorWithCalibratedWhite:0.94 alpha:1.0]];
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

- (void)drawViewBackgroundInRect:(NSRect)rect {
	[super drawViewBackgroundInRect:rect];
	
	NSRect visibleRect = [((NSClipView *)[self superview]) documentVisibleRect];
    
    for(LXBreakpointMarker *marker in self.breakpointMarkers) {
        if(!marker.visible)
            continue;
        
		markerImage = [marker image];
		NSSize markerSize = [markerImage size];
		NSRect markerRect = NSMakeRect(40.0f - [markerImage size].width - 1.0f, marker.yPos + visibleRect.origin.y, markerSize.width, markerSize.height);
		
		if(NSIntersectsRect(rect, markerRect)) {
			[markerImage drawInRect:markerRect fromRect:NSMakeRect(0, 0, markerSize.width, markerSize.height) operation:NSCompositeSourceOver fraction:1.0];	
		}
	}
}

- (void)drawRect:(NSRect)rect {
	[super drawRect:rect];
	
	NSRect bounds = [self bounds]; 
	
	if([self needsToDrawRect:NSMakeRect(bounds.size.width - 1, 0, 1, bounds.size.height)] == YES) {
		[[NSColor lightGrayColor] set];
		NSBezierPath *dottedLine = [NSBezierPath bezierPathWithRect:NSMakeRect(bounds.size.width, 0, 0, bounds.size.height)];
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

@end