#import "LXProjectFileView.h"

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
    
    if([self.delegate respondsToSelector:@selector(fileDidAddBreakpoint:line:)]) {
        [self.delegate fileDidAddBreakpoint:self line:line];
    }
}

- (void)removeBreakpoint:(NSUInteger)line {
    [self.file removeBreakpoint:line];

    if([self.delegate respondsToSelector:@selector(fileDidRemoveBreakpoint:line:)]) {
        [self.delegate fileDidRemoveBreakpoint:self line:line];
    }
}

- (NSUndoManager *)undoManagerForTextView:(NSTextView *)view {
    return [self.textView undoManager];
}

@end
