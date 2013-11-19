#import "ScriptDocument.h"
#import "GutterTextView.h"

@implementation ScriptDocument

@synthesize textView, textScrollView, gutterScrollView, syntaxColoring;

- (id)initWithContentView:(NSView*)contentView {
	if(self = [super init]) {		
		textScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(40, 0, [contentView bounds].size.width - 40, [contentView bounds].size.height)];
		NSSize contentSize = [textScrollView contentSize];
		[textScrollView setBorderType:NSNoBorder];
        [textScrollView setHasHorizontalScroller:YES];
		[textScrollView setHasVerticalScroller:YES];
		[textScrollView setAutohidesScrollers:YES];
		[textScrollView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
		[[textScrollView contentView] setAutoresizesSubviews:YES];
		
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewBoundsDidChange:) name:NSViewFrameDidChangeNotification object:[textScrollView contentView]];

		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(viewBoundsDidChange:) name:NSViewBoundsDidChangeNotification object:[textScrollView contentView]];
				
		textView = [[ScriptTextView alloc] initWithFrame:NSMakeRect(40, 0, contentSize.width, contentSize.height)];
		[textView setMinSize:contentSize];
		[textView setHorizontallyResizable:YES];
		[[textView textContainer] setContainerSize:NSMakeSize(FLT_MAX, FLT_MAX)];
		[[textView textContainer] setWidthTracksTextView:NO];
		
		[textScrollView setDocumentView:textView];
		
		gutterScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 40, contentSize.height)];
		[gutterScrollView setBorderType:NSNoBorder];
		[gutterScrollView setHasVerticalScroller:NO];
		[gutterScrollView setHasHorizontalScroller:NO];
		[gutterScrollView setAutoresizingMask:NSViewHeightSizable];
		[[gutterScrollView contentView] setAutoresizesSubviews:YES];
        
		gutterTextView = [[GutterTextView alloc] initWithFrame:NSMakeRect(0, 0, 40, contentSize.height - 50)];
		gutterTextView.document = self;
		[gutterScrollView setDocumentView:gutterTextView];
		
		//syntaxColoring = [[SyntaxColoring alloc] initWithDocument:self];
	}
	
	return self;
}

- (void)resizeViewsForSuperView:(NSView*)view {	
	[gutterScrollView setFrame:NSMakeRect(0, 0, 40, [view bounds].size.height)];
	[textScrollView setFrame:NSMakeRect(40, 0, [view bounds].size.width - 40, [view bounds].size.height)];
	
	[self updateLineNumbers:YES];
}
	
- (void)viewBoundsDidChange:(NSNotification *)notification {
	if (notification != nil && [notification object] != nil && [[notification object] isKindOfClass:[NSClipView class]]) {
		[self updateLineNumbersForClipView:[notification object] recolour:YES];
	}
}

- (void)updateLineNumbers:(BOOL)recolour {
	[self updateLineNumbersForClipView:[textScrollView contentView] recolour:recolour];
}


- (void)updateLineNumbersForClipView:(NSClipView *)clipView recolour:(BOOL)recolour {	
	layoutManager = [textView layoutManager];
	visibleRect = [[textScrollView contentView] documentVisibleRect];
	visibleRange = [layoutManager glyphRangeForBoundingRect:visibleRect inTextContainer:[textView textContainer]];
	textString = [textView string];
	searchString = [textString substringWithRange:NSMakeRange(0,visibleRange.location)];
	
	for (index = 0, lineNumber = 0; index < visibleRange.location; lineNumber++) {
		BreakpointMarker *marker = [gutterTextView markerAtLine:lineNumber];
		
		if(marker != nil) {
			marker.yPos = -FLT_MAX;
		}
		
		index = NSMaxRange([searchString lineRangeForRange:NSMakeRange(index, 0)]);
	}
	
	indexNonWrap = [searchString lineRangeForRange:NSMakeRange(index, 0)].location;
	maxRangeVisibleRange = NSMaxRange([textString lineRangeForRange:NSMakeRange(NSMaxRange(visibleRange), 0)]); // Set it to just after the last glyph on the last visible line 
	numberOfGlyphsInTextString = [layoutManager numberOfGlyphs];
	oneMoreTime = NO;
	if (numberOfGlyphsInTextString != 0) {
		lastGlyph = [textString characterAtIndex:numberOfGlyphsInTextString - 1];
		if (lastGlyph == '\n' || lastGlyph == '\r') {
			oneMoreTime = YES; // Continue one more time through the loop if the last glyph isn't newline
		}
	}
	
    NSMutableAttributedString *lineNumbersString = [[NSMutableAttributedString alloc] init];
    
	firstVisibleLineNumber = lineNumber;
    
	NSTextContainer	*container = [textView textContainer];
	NSRange nullRange = NSMakeRange(NSNotFound, 0);
	NSRectArray	rects;
	NSUInteger rectCount;
	
    for(BreakpointMarker *marker in gutterTextView.breakpointMarkers) {
        marker.visible = NO;
    }
    
    
    NSFont *font = [[NSFontManager sharedFontManager]
                    fontWithFamily:@"Menlo"
                    traits:0
                    weight:0
                    size:11];
    
    CGFloat origin = visibleRect.origin.y;
    currentLineHeight = (NSInteger)[textView lineHeight];

    if(origin < 0.0) {
        while(origin <= 0.0) {
            NSDictionary *fontAttributes = @{NSFontAttributeName : font};

            NSAttributedString *appendedString = [[NSAttributedString alloc] initWithString:@"\n" attributes:fontAttributes];
            
            [lineNumbersString appendAttributedString:appendedString];
            [appendedString release];
            
            origin += currentLineHeight;
        }
    }
    
	while (indexNonWrap <= maxRangeVisibleRange) {
		if (index == indexNonWrap) {
			lineNumber++;
                       			
			BreakpointMarker *marker = [gutterTextView markerAtLine:lineNumber];
          
            
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
            [appendedString release];
            
		} else {
            NSAttributedString *appendedString = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%d\n", 0x00B7] attributes:@{}];
            
            [lineNumbersString appendAttributedString:appendedString];
            [appendedString release];
            
			indexNonWrap = index;
		}
		
		if (index < maxRangeVisibleRange) {
			[layoutManager lineFragmentRectForGlyphAtIndex:index effectiveRange:&range];
			index = NSMaxRange(range);
			indexNonWrap = NSMaxRange([textString lineRangeForRange:NSMakeRange(indexNonWrap, 0)]);
		} else {
			index++;
			indexNonWrap++;
		}
		
		if (index == numberOfGlyphsInTextString && !oneMoreTime) {
			break;
		}
	}
	
    if(origin > textView.frame.size.height - textScrollView.frame.size.height) {        
        while(origin > textView.frame.size.height - textScrollView.frame.size.height) {
            NSDictionary *fontAttributes = @{NSFontAttributeName : font};
            
            NSAttributedString *appendedString = [[NSAttributedString alloc] initWithString:@"\n" attributes:fontAttributes];
            
            [lineNumbersString appendAttributedString:appendedString];
            [appendedString release];
            
            origin -= currentLineHeight;
        }
    }

	if (recolour == YES) {
		[syntaxColoring pageRecolourTextView:textView];
	}
	
	[[[gutterScrollView documentView] textStorage] setAttributedString:lineNumbersString];
    [lineNumbersString release];
	
	[[gutterScrollView contentView] setBoundsOrigin:zeroPoint]; 
	if ((NSInteger)visibleRect.origin.y != 0 && currentLineHeight != 0) {        
        NSInteger point = visibleRect.origin.y < 0.0 ? ((NSInteger)visibleRect.origin.y % currentLineHeight) + currentLineHeight : (NSInteger)visibleRect.origin.y % currentLineHeight;
        
		[[gutterScrollView contentView] scrollToPoint:NSMakePoint(0, point)];
	}
}

- (NSUInteger)lineNumberForLocation:(NSPoint)point {
	CGFloat location = [textView convertPoint:point fromView:nil].y;

	NSTextContainer	*container = [textView textContainer];
	NSRange nullRange = NSMakeRange(NSNotFound, 0);
	NSRectArray	rects;
	NSUInteger rectCount;
	
	layoutManager = [textView layoutManager];
	visibleRect = [[textScrollView contentView] documentVisibleRect];
	visibleRange = [layoutManager glyphRangeForBoundingRect:visibleRect inTextContainer:[textView textContainer]];
	textString = [textView string];
	searchString = [textString substringWithRange:NSMakeRange(0,visibleRange.location)];
	
	for (index = 0, lineNumber = 0; index < visibleRange.location; lineNumber++) {
		index = NSMaxRange([searchString lineRangeForRange:NSMakeRange(index, 0)]);
	}
	
	indexNonWrap = [searchString lineRangeForRange:NSMakeRange(index, 0)].location;
	maxRangeVisibleRange = NSMaxRange([textString lineRangeForRange:NSMakeRange(NSMaxRange(visibleRange), 0)]); // Set it to just after the last glyph on the last visible line 
	numberOfGlyphsInTextString = [layoutManager numberOfGlyphs];
	oneMoreTime = NO;
	if (numberOfGlyphsInTextString != 0) {
		lastGlyph = [textString characterAtIndex:numberOfGlyphsInTextString - 1];
		if (lastGlyph == '\n' || lastGlyph == '\r') {
			oneMoreTime = YES; // Continue one more time through the loop if the last glyph isn't newline
		}
	}

	while (indexNonWrap <= maxRangeVisibleRange) {
		rects = [layoutManager rectArrayForCharacterRange:NSMakeRange(index, 0)
												 withinSelectedCharacterRange:nullRange
																			inTextContainer:container
																						rectCount:&rectCount];
		
		for (int i = 0; i < rectCount; i++) {
			if((location >= NSMinY(rects[i])) && (location < NSMaxY(rects[i]))) {
				return lineNumber + 1;
			}
		}
		
		if (index == indexNonWrap) {
			lineNumber++;
		} else {
			indexNonWrap = index;
		}
		
		if (index < maxRangeVisibleRange) {
			[layoutManager lineFragmentRectForGlyphAtIndex:index effectiveRange:&range];
			index = NSMaxRange(range);
			indexNonWrap = NSMaxRange([textString lineRangeForRange:NSMakeRange(indexNonWrap, 0)]);
		} else {
			index++;
			indexNonWrap++;
		}
		
		if (index == numberOfGlyphsInTextString && !oneMoreTime) {
			break;
		}
	}
	
	return NSNotFound;
}

- (void)addBreakpoint:(NSUInteger)line {
    if([self.delegate respondsToSelector:@selector(documentDidAddBreakpoint:line:)]) {
        [self.delegate documentDidAddBreakpoint:self line:line];
    }
}

- (void)removeBreakpoint:(NSUInteger)line {
    if([self.delegate respondsToSelector:@selector(documentDidRemoveBreakpoint:line:)]) {
        [self.delegate documentDidRemoveBreakpoint:self line:line];
    }
}

- (void)setWasModified:(BOOL)wasModified {
    _wasModified = wasModified;
    
    if([self.delegate respondsToSelector:@selector(documentWasModified:modified:)]) {
        [self.delegate documentWasModified:self modified:self.wasModified];
    }
}

@end
