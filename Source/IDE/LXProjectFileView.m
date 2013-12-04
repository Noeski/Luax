#import "LXProjectFileView.h"

@implementation LXProjectFileView

- (id)initWithContentView:(NSView *)contentView file:(LXProjectFileReference *)file {
	if(self = [super initWithFrame:contentView.bounds]) {
        [self setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];

        _file = file;
		_textScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(40, 0, [contentView bounds].size.width - 40, [contentView bounds].size.height)];
		NSSize contentSize = [_textScrollView contentSize];
		[_textScrollView setBorderType:NSNoBorder];
        [_textScrollView setHasHorizontalScroller:YES];
		[_textScrollView setHasVerticalScroller:YES];
		[_textScrollView setAutohidesScrollers:YES];
		[_textScrollView setAutoresizingMask:(NSViewMinXMargin | NSViewMaxXMargin | NSViewWidthSizable | NSViewHeightSizable)];
		[[_textScrollView contentView] setAutoresizesSubviews:YES];
		[self addSubview:_textScrollView];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewBoundsDidChange:) name:NSViewFrameDidChangeNotification object:[_textScrollView contentView]];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewBoundsDidChange:) name:NSViewBoundsDidChangeNotification object:[_textScrollView contentView]];
        
		_textView = [[LXTextView alloc] initWithFrame:NSMakeRect(40, 0, contentSize.width, contentSize.height) file:_file.file];
        _textView.delegate = self;
		[_textView setMinSize:contentSize];
		[_textView setHorizontallyResizable:YES];
		[[_textView textContainer] setContainerSize:NSMakeSize(FLT_MAX, FLT_MAX)];
		[[_textView textContainer] setWidthTracksTextView:NO];
		
		[_textScrollView setDocumentView:_textView];
        
		_gutterScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 40, contentSize.height)];
		[_gutterScrollView setBorderType:NSNoBorder];
		[_gutterScrollView setHasVerticalScroller:NO];
		[_gutterScrollView setHasHorizontalScroller:NO];
		[_gutterScrollView setAutoresizingMask:NSViewHeightSizable];
		[[_gutterScrollView contentView] setAutoresizesSubviews:YES];
        [self addSubview:_gutterScrollView];
        
		_gutterTextView = [[LXGutterView alloc] initWithFrame:NSMakeRect(0, 0, 40, contentSize.height - 50)];
		_gutterTextView.document = self;
		[_gutterScrollView setDocumentView:_gutterTextView];
    }
	
	return self;
}

- (void)resizeSubviewsWithOldSize:(NSSize)oldSize {
    [self.gutterScrollView setFrame:NSMakeRect(0, 0, 40, [self bounds].size.height)];
	[self.textScrollView setFrame:NSMakeRect(40, 0, [self bounds].size.width - 40, [self bounds].size.height)];
}

- (void)save {
    if(self.modified) {
        self.file.file.contents = self.textView.string;
         
        _modified = NO;
     
        if([self.delegate respondsToSelector:@selector(fileWasModified:modified:)]) {
            [self.delegate fileWasModified:self modified:self.modified];
        }
    }
}

- (void)textDidChange:(NSNotification *)notification {
    [self updateLineNumbers];

    _modified = YES;
    
    if([self.delegate respondsToSelector:@selector(fileWasModified:modified:)]) {
        [self.delegate fileWasModified:self modified:self.modified];
    }
}

- (void)resizeViews {	
	[self.gutterScrollView setFrame:NSMakeRect(0, 0, 40, [self bounds].size.height)];
	[self.textScrollView setFrame:NSMakeRect(40, 0, [self bounds].size.width - 40, [self bounds].size.height)];

	[self updateLineNumbers];
}
	
- (void)viewBoundsDidChange:(NSNotification *)notification {
	if([[notification object] isKindOfClass:[NSClipView class]]) {
		[self updateLineNumbersForClipView:[notification object]];
	}
}

- (void)updateLineNumbers {
	[self updateLineNumbersForClipView:[self.textScrollView contentView]];
}

- (void)updateLineNumbersForClipView:(NSClipView *)clipView {
	NSLayoutManager *layoutManager = [self.textView layoutManager];
	NSRect visibleRect = [[self.textScrollView contentView] documentVisibleRect];
	NSRange visibleRange = [layoutManager glyphRangeForBoundingRect:visibleRect inTextContainer:[self.textView textContainer]];
	NSString *textString = [self.textView string];
	NSString *searchString = [textString substringWithRange:NSMakeRange(0,visibleRange.location)];
	
    NSInteger index, lineNumber;
    
	for(index = 0, lineNumber = 0; index < visibleRange.location; lineNumber++) {
		LXBreakpointMarker *marker = [_gutterTextView markerAtLine:lineNumber];
		
		if(marker != nil) {
			marker.yPos = -FLT_MAX;
		}
		
		index = NSMaxRange([searchString lineRangeForRange:NSMakeRange(index, 0)]);
	}
	
	NSInteger indexNonWrap;
	NSInteger maxRangeVisibleRange;
    
    if(visibleRange.length == 0) {
        indexNonWrap = 0;
        maxRangeVisibleRange = -1;
    }
    else {
        indexNonWrap = [searchString lineRangeForRange:NSMakeRange(index, 0)].location;
        maxRangeVisibleRange = NSMaxRange([textString lineRangeForRange:NSMakeRange(NSMaxRange(visibleRange), 0)]);
    }
    
	NSInteger numberOfGlyphsInTextString = [layoutManager numberOfGlyphs];
	BOOL oneMoreTime = NO;
    
	if(numberOfGlyphsInTextString != 0) {
		unichar lastGlyph = [textString characterAtIndex:numberOfGlyphsInTextString - 1];
		if(lastGlyph == '\n' || lastGlyph == '\r') {
			oneMoreTime = YES; // Continue one more time through the loop if the last glyph isn't newline
		}
	}
	
    NSMutableAttributedString *lineNumbersString = [[NSMutableAttributedString alloc] init];
        
	NSTextContainer	*container = [self.textView textContainer];
	NSRange nullRange = NSMakeRange(NSNotFound, 0);
	NSRectArray	rects;
	NSUInteger rectCount;
	
    for(LXBreakpointMarker *marker in _gutterTextView.breakpointMarkers) {
        marker.visible = NO;
    }
    
    NSFont *font = [[NSFontManager sharedFontManager]
                    fontWithFamily:@"Menlo"
                    traits:0
                    weight:0
                    size:11];
    
    CGFloat origin = visibleRect.origin.y;
    NSInteger currentLineHeight = (NSInteger)[self.textView lineHeight];
    
    if(origin < 0.0) {
        while(origin <= 0.0) {
            NSDictionary *fontAttributes = @{NSFontAttributeName : font};

            NSAttributedString *appendedString = [[NSAttributedString alloc] initWithString:@"\n" attributes:fontAttributes];
            
            [lineNumbersString appendAttributedString:appendedString];
            
            origin += currentLineHeight;
        }
    }
    
	while(indexNonWrap <= maxRangeVisibleRange) {
		if(index == indexNonWrap) {
			lineNumber++;
            
			LXBreakpointMarker *marker = [_gutterTextView markerAtLine:lineNumber];
          
            
            NSDictionary *fontAttributes = nil;

			if(marker != nil) {
                fontAttributes = @{NSForegroundColorAttributeName : [NSColor whiteColor], NSFontAttributeName : font};

				rects = [layoutManager rectArrayForCharacterRange:NSMakeRange(index, 0)
														 withinSelectedCharacterRange:nullRange
																					inTextContainer:container
																								rectCount:&rectCount];
				
                marker.visible = YES;
				marker.yPos = NSMinY(rects[0]) - NSMinY(visibleRect);
			}
            else {
                fontAttributes = @{NSForegroundColorAttributeName : [NSColor darkGrayColor], NSFontAttributeName : font};
            }
            
            NSAttributedString *appendedString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%li\n", lineNumber] attributes:fontAttributes];
            
            [lineNumbersString appendAttributedString:appendedString];
            
		}
        else {
            NSAttributedString *appendedString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%d\n", 0x00B7] attributes:@{}];
            
            [lineNumbersString appendAttributedString:appendedString];
            
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
	
    if(origin > self.textView.frame.size.height - self.textScrollView.frame.size.height) {
        while(origin > self.textView.frame.size.height - self.textScrollView.frame.size.height) {
            NSDictionary *fontAttributes = @{NSFontAttributeName : font};
            
            NSAttributedString *appendedString = [[NSAttributedString alloc] initWithString:@"\n" attributes:fontAttributes];
            
            [lineNumbersString appendAttributedString:appendedString];
            
            origin -= currentLineHeight;
        }
    }

	[[[self.gutterScrollView documentView] textStorage] setAttributedString:lineNumbersString];
	
	[[self.gutterScrollView contentView] setBoundsOrigin:CGPointZero];
    
	if((NSInteger)visibleRect.origin.y != 0 && currentLineHeight != 0) {
        NSInteger point = visibleRect.origin.y < 0.0 ? ((NSInteger)visibleRect.origin.y % currentLineHeight) + currentLineHeight : (NSInteger)visibleRect.origin.y % currentLineHeight;
        
		[[self.gutterScrollView contentView] scrollToPoint:NSMakePoint(0, point)];
	}
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
    if([self.delegate respondsToSelector:@selector(fileDidAddBreakpoint:line:)]) {
        [self.delegate fileDidAddBreakpoint:self line:line];
    }
}

- (void)removeBreakpoint:(NSUInteger)line {
    if([self.delegate respondsToSelector:@selector(fileDidRemoveBreakpoint:line:)]) {
        [self.delegate fileDidRemoveBreakpoint:self line:line];
    }
}

@end
