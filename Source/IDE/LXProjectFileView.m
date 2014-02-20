#import "LXProjectFileView.h"

@interface LXRulerView : NSRulerView
@property (nonatomic, strong) LXProjectFile *file;
@end

@implementation LXRulerView

-(void)drawHashMarksAndLabelsInRect:(NSRect)rect {
    [[NSColor colorWithRed:0.259 green:0.259 blue:0.259 alpha:1] set];
    [NSBezierPath fillRect:rect];

    [[NSColor grayColor] setStroke];
    [NSBezierPath strokeLineFromPoint:NSMakePoint(NSMaxX(rect), NSMinY(rect))
                              toPoint:NSMakePoint(NSMaxX(rect), NSMaxY(rect))];
    
    NSView *documentView = [self.scrollView documentView];
    NSRect baselineRect = [self convertRect:[documentView bounds]  fromView:documentView];
    NSInteger zeroLocation = baselineRect.origin.y;
    
    baselineRect.origin.x = [self baselineLocation];
    baselineRect.size.width = 1;
    
    NSRect visibleBaselineRect = NSIntersectionRect(baselineRect, rect);
    CGFloat firstVisibleLocation = NSMinY(visibleBaselineRect);
    CGFloat lastVisibleLocation = NSMaxY(visibleBaselineRect);
    
    NSInteger numberOfLines = self.file.context.parser.numberOfLines;
    NSInteger firstLine = (firstVisibleLocation-zeroLocation) / 13.0f;
    NSInteger lastLine = MIN(numberOfLines, (lastVisibleLocation-zeroLocation) / 13.0f);
    NSInteger yOffset = zeroLocation < 0 ? -(-zeroLocation % 13) : zeroLocation;
    
    for(NSInteger i = firstLine; i < lastLine+1; ++i) {
        NSInteger line = i+1;
        
        BOOL hasBreakpoint = self.file.breakpoints[@(line)];
        NSDictionary *fontAttributes = nil;
        
        NSRect lineBounds = NSMakeRect(0, yOffset, NSWidth(rect), 13);

        if(hasBreakpoint) {
            [self drawBreakpointInRect:lineBounds];
            
            fontAttributes = @{NSFontAttributeName : [NSFont fontWithName:@"Menlo" size:8],
                                   NSForegroundColorAttributeName : [NSColor whiteColor]};
        }
        else {
            fontAttributes = @{NSFontAttributeName : [NSFont fontWithName:@"Menlo" size:8],
                               NSForegroundColorAttributeName : [NSColor colorWithCalibratedWhite:0.8 alpha:1]};
        }
        
        NSAttributedString *lineNumberString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%ld", line] attributes:fontAttributes];
        NSSize stringSize = [lineNumberString size];
        
        NSRect drawRect = NSMakeRect(NSWidth(rect) - (stringSize.width+5),
                                     NSMidY(lineBounds) - (stringSize.height * 0.5),
                                     NSWidth(rect),
                                     stringSize.height);
        
        [lineNumberString drawInRect:drawRect];
        
        
        yOffset += 13;
    }
}

- (void)drawMarkerInRect:(NSRect)rect
               fillColor:(NSColor *)fill
             strokeColor:(NSColor *)stroke {
    [[NSGraphicsContext currentContext] saveGraphicsState];
    
    rect = NSInsetRect(rect, 1, 1);
    
    NSBezierPath *path = [NSBezierPath bezierPath];
	[path moveToPoint:NSMakePoint(NSMaxX(rect), NSMidY(rect))];
	[path lineToPoint:NSMakePoint(NSMaxX(rect) - 5.0, NSMaxY(rect))];
    
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(rect) + 2.0, NSMaxY(rect) - 2.0) radius:2.0 startAngle:90 endAngle:180];
    
	[path appendBezierPathWithArcWithCenter:NSMakePoint(NSMinX(rect) + 2.0, NSMinY(rect) + 2.0) radius:2.0 startAngle:180 endAngle:270];
	[path lineToPoint:NSMakePoint(NSMaxX(rect) - 5.0, NSMinY(rect))];
	[path closePath];
    
	[fill set];
	[path fill];
    
	[stroke set];
	[path setLineWidth:2.0];
	[path stroke];
    
    [[NSGraphicsContext currentContext] restoreGraphicsState];
}

- (void)drawBreakpointInRect:(NSRect)rect {
    [self drawMarkerInRect:rect
                 fillColor:[NSColor colorWithDeviceRed:0.004 green:0.557 blue:0.851 alpha:1.0]
               strokeColor:[NSColor colorWithDeviceRed:0.0 green:0.404 blue:0.804 alpha:1.0]];
}

- (NSUInteger)lineNumberAtPoint:(NSPoint)point {
    NSView *documentView = [self.scrollView documentView];
    NSRect baselineRect = [self convertRect:[documentView bounds]  fromView:documentView];
    NSInteger zeroLocation = baselineRect.origin.y;
    
    NSInteger line = (point.y - zeroLocation) / 13.0;
    NSInteger numberOfLines = self.file.context.parser.numberOfLines;

    if(line > numberOfLines || line < 0) {
        return NSNotFound;
    }
    
    return line+1;
}

- (void)mouseDown:(NSEvent*)theEvent {
    NSPoint point = [theEvent locationInWindow];
    point = [self convertPoint:point fromView:nil];
    
    NSView *documentView = [self.scrollView documentView];
    NSRect baselineRect = [self convertRect:[documentView bounds]  fromView:documentView];
    NSInteger zeroLocation = baselineRect.origin.y;
    NSInteger line = (point.y - zeroLocation) / 13.0;
    NSInteger numberOfLines = self.file.context.parser.numberOfLines;

    if(line >= 0 && line <= numberOfLines) {
        [self.file setBreakpoint:line+1];
        [self setNeedsDisplay:YES];
    }
}

@end

@interface LXProjectFileView()
@property (nonatomic, strong) LXRulerView *rulerView;
@end

@implementation LXProjectFileView

- (id)initWithContentView:(NSView *)contentView file:(LXProjectFile *)file {
	if(self = [super initWithFrame:contentView.bounds]) {
        [self setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

        _file = file;
		_textScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, [contentView bounds].size.width, [contentView bounds].size.height)];
		NSSize contentSize = [_textScrollView contentSize];
		[_textScrollView setBorderType:NSNoBorder];
        [_textScrollView setScrollerKnobStyle:NSScrollerKnobStyleLight];
        [_textScrollView setHasHorizontalScroller:YES];
		[_textScrollView setHasVerticalScroller:YES];
		[_textScrollView setAutohidesScrollers:YES];
		[_textScrollView setAutoresizingMask:(NSViewMinXMargin | NSViewMaxXMargin | NSViewWidthSizable | NSViewHeightSizable)];
		[[_textScrollView contentView] setAutoresizesSubviews:YES];
		[self addSubview:_textScrollView];
        
		_textView = [[LXTextView alloc] initWithFrame:NSMakeRect(0, 0, contentSize.width, contentSize.height) file:_file];
        _textView.delegate = self;
		[_textView setMinSize:contentSize];
		[_textView setHorizontallyResizable:YES];
		[[_textView textContainer] setContainerSize:NSMakeSize(FLT_MAX, FLT_MAX)];
		[[_textView textContainer] setWidthTracksTextView:NO];
		
		[_textScrollView setDocumentView:_textView];
        
        _rulerView = [[LXRulerView alloc] initWithScrollView:_textScrollView orientation:NSVerticalRuler];
        _rulerView.file = _file;
        [_rulerView setRuleThickness:40];
        [_textScrollView setVerticalRulerView:_rulerView];
        [_textScrollView setHasHorizontalRuler:NO];
        [_textScrollView setHasVerticalRuler:YES];
        [_textScrollView setRulersVisible:YES];
    }
	
	return self;
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
	[self.textScrollView setFrame:NSMakeRect(0, 0, [self bounds].size.width, [self bounds].size.height)];
}

- (void)save {
    if(self.modified) {
        self.file.contents = self.textView.string;
         
        _modified = NO;
     
        if([self.delegate respondsToSelector:@selector(fileWasModified:modified:)]) {
            [self.delegate fileWasModified:self modified:self.modified];
        }
    }
}

- (void)textDidChange:(NSNotification *)notification {
    _modified = YES;
    
    [self.rulerView setNeedsDisplay:YES];
    
    if([self.delegate respondsToSelector:@selector(fileWasModified:modified:)]) {
        [self.delegate fileWasModified:self modified:self.modified];
    }
}

- (void)viewWillMoveToSuperview:(NSView *)newSuperview {
    if(newSuperview) {
        self.frame = newSuperview.bounds;
        
        [self resizeViews];
    }
}

- (void)resizeViews {	
	[self.textScrollView setFrame:NSMakeRect(0, 0, [self bounds].size.width, [self bounds].size.height)];
}

- (NSUInteger)lineNumberForLocation:(NSPoint)point {
	CGFloat location = [self.textView convertPoint:point fromView:nil].y;

	NSTextContainer	*container = [self.textView textContainer];
	NSRange nullRange = NSMakeRange(NSNotFound, 0);
	NSRectArray	rects;
	NSUInteger rectCount;
	
	NSLayoutManager *layoutManager = [self.textView layoutManager];
	NSRect visibleRect = [[self.textScrollView contentView] documentVisibleRect];
	NSRange visibleRange = [layoutManager glyphRangeForBoundingRect:visibleRect inTextContainer:[self.textView textContainer]];
	NSString *textString = [self.textView string];
	NSString *searchString = [textString substringWithRange:NSMakeRange(0, visibleRange.location)];
	
    NSInteger index, lineNumber;
    
	for(index = 0, lineNumber = 0; index < visibleRange.location; lineNumber++) {
		index = NSMaxRange([searchString lineRangeForRange:NSMakeRange(index, 0)]);
	}
    
    NSInteger indexNonWrap = [searchString lineRangeForRange:NSMakeRange(index, 0)].location;
	NSInteger maxRangeVisibleRange = NSMaxRange([textString lineRangeForRange:NSMakeRange(NSMaxRange(visibleRange), 0)]); // Set it to just after the last glyph on the last visible line
	NSInteger numberOfGlyphsInTextString = [layoutManager numberOfGlyphs];
	BOOL oneMoreTime = NO;
	if(numberOfGlyphsInTextString != 0) {
		unichar lastGlyph = [textString characterAtIndex:numberOfGlyphsInTextString - 1];
		if(lastGlyph == '\n' || lastGlyph == '\r') {
			oneMoreTime = YES; // Continue one more time through the loop if the last glyph isn't newline
		}
	}

	while(indexNonWrap <= maxRangeVisibleRange) {
		rects = [layoutManager rectArrayForCharacterRange:NSMakeRange(index, 0)
                             withinSelectedCharacterRange:nullRange
                                          inTextContainer:container
												rectCount:&rectCount];
		
		for(int i = 0; i < rectCount; i++) {
			if((location >= NSMinY(rects[i])) && (location < NSMaxY(rects[i]))) {
				return lineNumber + 1;
			}
		}
		
		if(index == indexNonWrap) {
			lineNumber++;
		}
        else {
			indexNonWrap = index;
		}
		
		if(index < maxRangeVisibleRange) {
            NSRange range;
            
			[layoutManager lineFragmentRectForGlyphAtIndex:index effectiveRange:&range];
			index = NSMaxRange(range);
			indexNonWrap = NSMaxRange([textString lineRangeForRange:NSMakeRange(indexNonWrap, 0)]);
		}
        else {
			index++;
			indexNonWrap++;
		}
		
		if(index == numberOfGlyphsInTextString && !oneMoreTime) {
			break;
		}
	}
	
	return NSNotFound;
}

- (void)addBreakpoint:(NSUInteger)line {
    [self.file addBreakpoint:line];
}

- (void)removeBreakpoint:(NSUInteger)line {
    [self.file removeBreakpoint:line];
}

- (NSUndoManager *)undoManagerForTextView:(NSTextView *)view {
    return [self.textView undoManager];
}

@end
