#import "LXTextView.h"
#import "LXProject.h"
#import "LXNode.h"
#import "LXToken.h"
#import "NSString+JSON.h"
#import "LXProjectWindowController.h"
#import "LXTextFieldCell.h"
#import "LXBlurWindow.h"

@interface LXAutoCompleteTableView : LXTableView
@end

@implementation LXAutoCompleteTableView

- (BOOL)isOpaque {
    return NO;
}

- (void)drawBackgroundInClipRect:(NSRect)clipRect {
}

- (void)highlightSelectionInClipRect:(NSRect)theClipRect {
    NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:self.visibleRect xRadius:4 yRadius:4];
    [path addClip];
    
    [super highlightSelectionInClipRect:theClipRect];
}

@end

@interface LXAutoCompleteCell : NSTextFieldCell
@end

@implementation LXAutoCompleteCell

- (NSColor *)highlightColorWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    return nil;
}

@end

@interface LXErrorView : NSObject
@property (nonatomic, assign) NSRect frame;
@property (nonatomic, strong) LXCompilerError *error;
@end

@implementation LXErrorView
@end

@implementation LXAutoCompleteWindow

- (BOOL)canBecomeKeyWindow {
    return YES;
}

@end

@implementation LXAutoCompleteDefinition

- (id)init {
    if(self = [super init]) {
        _type = @"";
    }
    
    return self;
}

- (NSString *)summary {
    return self.string;
}

@end

@implementation LXTextViewUndoManager
- (void)beginUndoGrouping {
    numberOfOpenGroups++;
    
    [super beginUndoGrouping];
}

- (void)endUndoGrouping {
    numberOfOpenGroups--;
    
    [super endUndoGrouping];
}

- (void)closeAllOpenGroups {
    while(numberOfOpenGroups > 0) {
        [self endUndoGrouping];
    }
}

- (void)undo {
    [self closeAllOpenGroups];
    
    [super undo];
}

@end

@implementation LXTextView

- (id)initWithFrame:(NSRect)frame file:(LXProjectFile *)file {
	if(self = [super initWithFrame:frame]) {
        _file = file;
        
        undoManager = [[LXTextViewUndoManager alloc] init];
        
        identifierCharacterSet = [NSCharacterSet characterSetWithCharactersInString:
                                  @"_0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"];
        NSRect frame = NSMakeRect(0, 0, 150, 150);
        autoCompleteWindow = [[LXBlurWindow alloc] initWithFrame:frame];
        autoCompleteWindow.hasShadow = YES;
        autoCompleteWindow.delegate = self;
        [autoCompleteWindow setBackgroundColor:[NSColor colorWithCalibratedWhite:1 alpha:0.8]];
        
        font = [[NSFontManager sharedFontManager] fontWithFamily:@"Menlo"
                                                                  traits:0
                                                                  weight:4
                                                                    size:11];
        
        NSView *contentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 150, 150)];
        autoCompleteScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 150, 150)];
        [autoCompleteScrollView setDrawsBackground:NO];
        autoCompleteScrollView.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        autoCompleteTableView = [[LXAutoCompleteTableView alloc] initWithFrame:NSMakeRect(0, 0, 150, 150)];
        
        [autoCompleteTableView setAllowsEmptySelection:NO];
        [autoCompleteTableView setAllowsMultipleSelection:NO];
        [autoCompleteTableView setDoubleAction:@selector(finishAutoComplete)];
        
        NSTextFieldCell *cell = [[LXAutoCompleteCell alloc] init];
        [cell setDrawsBackground:NO];
        cell.font = font;
        cell.alignment = NSRightTextAlignment;
        NSTableColumn *tableColumn = [[NSTableColumn alloc] initWithIdentifier:@"Column1"];
        [tableColumn setWidth:75];
        [tableColumn setDataCell:cell];
        
        [autoCompleteTableView addTableColumn:tableColumn];
        
        cell = [[LXAutoCompleteCell alloc] init];
        [cell setDrawsBackground:NO];
        cell.font = font;
        tableColumn = [[NSTableColumn alloc] initWithIdentifier:@"Column2"];
        [tableColumn setWidth:75];
        [tableColumn setDataCell:cell];
        
        [autoCompleteTableView addTableColumn:tableColumn];
        
        [autoCompleteTableView setHeaderView:nil];
        [autoCompleteTableView setDataSource:self];
        [autoCompleteTableView setDelegate:self];
        [autoCompleteScrollView setDocumentView:autoCompleteTableView];
        [autoCompleteScrollView setHasVerticalScroller:YES];
        [contentView addSubview:autoCompleteScrollView];
        
        autoCompleteWindow.contentView = contentView;
        
        errorWindow = [[LXBlurWindow alloc] initWithFrame:NSMakeRect(0, 0, 150, 150)];
        [errorWindow setBackgroundColor:[NSColor colorWithCalibratedRed:1 green:0 blue:0 alpha:0.5]];
        
        contentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 150, 150)];
        errorLabel = [[NSTextField alloc] initWithFrame:contentView.bounds];
        [errorLabel setAutoresizingMask:NSViewWidthSizable | NSViewHeightSizable];
        [errorLabel setFont:[[NSFontManager sharedFontManager]
                             fontWithFamily:@"Menlo"
                             traits:0
                             weight:6
                             size:11]];
        
        [errorLabel setTextColor:[NSColor colorWithDeviceRed:0.943 green:0.943 blue:0.943 alpha:1]];
        [errorLabel setStringValue:@""];
        [errorLabel setBezeled:NO];
        [errorLabel setDrawsBackground:NO];
        [errorLabel setEditable:NO];
        [errorLabel setSelectable:NO];

        [contentView addSubview:errorLabel];
        
        errorWindow.contentView = contentView;
        
		[self setDefaults];     
	}
    
	return self;
}

NSTrackingArea *_trackingArea;

- (void)setDefaults {
	highlightedLine = -1;
	
    textColor = [NSColor colorWithCalibratedRed:0.9 green:0.9 blue:0.9 alpha:1];//[NSColor colorWithCalibratedWhite:0.9 alpha:1];
    commentsColor = [NSColor colorWithCalibratedRed:0.392 green:0.600 blue:0.490 alpha:1];//[NSColor colorWithDeviceRed:0.0f green:0.6f blue:0.0f alpha:1.0f];
    keywordsColor = [NSColor colorWithCalibratedRed:0.937 green:0.902 blue:0.588 alpha:1];//[NSColor colorWithDeviceRed:0.8f green:0.0f blue:0.4f alpha:1.0f];
    numbersColor = [NSColor colorWithCalibratedRed:0.525 green:0.804 blue:0.812 alpha:1];//[NSColor blueColor];
    functionsColor = [NSColor colorWithDeviceRed:0.6f green:0.0f blue:0.8f alpha:1.0f];
    stringsColor = [NSColor colorWithCalibratedRed:0.796 green:0.569 blue:0.573 alpha:1];//[NSColor redColor];
    typesColor = [NSColor colorWithCalibratedRed:0.949 green:0.875 blue:0.710 alpha:1];//[NSColor colorWithDeviceRed:0.314 green:0.506 blue:0.529 alpha:1];
    
    autoCompleteDefinitions = [[NSMutableArray alloc] init];
    currentAutoCompleteDefinitions = [[NSMutableArray alloc] init];
    autoCompleteMarkers = [[NSMutableArray alloc] init];
    
    [self setInsertionPointColor:textColor];
    [self setBackgroundColor:[NSColor colorWithCalibratedWhite:0.20 alpha:1]];
    [self setSelectedTextAttributes:@{NSBackgroundColorAttributeName : [NSColor clearColor]}];

    [self setHighlightedLineColor:[NSColor blueColor] background:[NSColor colorWithDeviceRed:0.8f green:0.8f blue:1.0f alpha:1.0f]];
    
	[self setTabWidth];
	
	[self setVerticallyResizable:YES];
	[self setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
	[self setAutoresizingMask:NSViewWidthSizable];
	[self setAllowsUndo:YES];
	[self setUsesFindPanel:NO];
	[self setAllowsDocumentBackgroundColorChange:NO];
	[self setRichText:NO];
	[self setImportsGraphics:NO];
	[self setUsesFontPanel:NO];
	[self setContinuousSpellCheckingEnabled:NO];
	[self setGrammarCheckingEnabled:NO];
	
	[self setSmartInsertDeleteEnabled:NO];
	[self setAutomaticLinkDetectionEnabled:NO];
	[self setAutomaticQuoteSubstitutionEnabled:NO];

	[self setFont:font];
    
	_trackingArea = [[NSTrackingArea alloc] initWithRect:[self frame] options:(NSTrackingMouseEnteredAndExited | NSTrackingActiveWhenFirstResponder) owner:self userInfo:nil];
	[self addTrackingArea:_trackingArea];
	
	lineHeight = [[[self textContainer] layoutManager] defaultLineHeightForFont:font];
    
    [self setString:self.file.contents];
}

- (void)updateTrackingAreas {
    [super updateTrackingAreas];
    [self removeTrackingArea:_trackingArea];
    _trackingArea = [[NSTrackingArea alloc] initWithRect:[self bounds] options: (NSTrackingMouseMoved | NSTrackingActiveInKeyWindow) owner:self userInfo:nil];
    [self addTrackingArea:_trackingArea];
}

- (void)mouseMoved:(NSEvent *)theEvent {
    NSPoint eventLocation = [theEvent locationInWindow];
    eventLocation = [self convertPoint:eventLocation fromView:nil];
    
    BOOL found = NO;    
    
    NSArray *errors = [self.file.context.errors arrayByAddingObjectsFromArray:self.file.context.warnings];
    
    for(LXCompilerError *error in errors) {
        NSRange range = error.range;
        
        NSRect rangeRect = [[self layoutManager] boundingRectForGlyphRange:range inTextContainer:[self textContainer]];
        rangeRect = NSOffsetRect(rangeRect, [self textContainerOrigin].x, [self textContainerOrigin].y);
        NSRect errorRect = NSMakeRect(rangeRect.origin.x-2, NSMaxY(rangeRect), 4, 4);
        
        if(NSPointInRect(eventLocation, errorRect)) {
            [errorLabel setStringValue:error.error];
            
            NSDictionary *sizeAttribute = @{NSFontAttributeName : font};
            NSRect textRect = [error.error boundingRectWithSize:self.bounds.size options:NSStringDrawingUsesLineFragmentOrigin attributes:sizeAttribute];

            errorRect.origin.x = MIN(errorRect.origin.x, self.bounds.size.width - (textRect.size.width + 6));
            errorRect.origin.y = MIN(errorRect.origin.y, self.bounds.size.height - (textRect.size.height + 6));

            NSRect windowRect = [self convertRect:errorRect toView:nil];
            NSRect screenRect = [[self window] convertRectToScreen:windowRect];
            
            [errorWindow setFrame:NSMakeRect(screenRect.origin.x, screenRect.origin.y - (textRect.size.height + 4), textRect.size.width + 6, textRect.size.height + 4) display:YES];
            
            if(error.isWarning) {
                [errorWindow setBackgroundColor:[NSColor colorWithCalibratedRed:1.0 green:0.865 blue:0.275 alpha:0.5]];
            }
            else {
                [errorWindow setBackgroundColor:[NSColor colorWithCalibratedRed:1 green:0 blue:0 alpha:0.5]];
            }
            
            if(!showingErrorWindow) {
                [self.window addChildWindow:errorWindow ordered:NSWindowAbove];
                [errorWindow setAlphaValue:0.0f];
                [NSAnimationContext beginGrouping];
                [[NSAnimationContext currentContext] setDuration:0.1f];
                [[errorWindow animator] setAlphaValue:1.0f];
                [NSAnimationContext endGrouping];

                showingErrorWindow = YES;
            }
            
            found = YES;
            break;
        }
    }
    
    if(!found && showingErrorWindow) {
        showingErrorWindow = NO;
        
        [NSAnimationContext beginGrouping];
        __block __unsafe_unretained NSWindow *bself = errorWindow;
        [[NSAnimationContext currentContext] setDuration:0.1f];
        [[NSAnimationContext currentContext] setCompletionHandler:^{
            [bself orderOut:nil];
            [self.window removeChildWindow:bself];
        }];
        
        [[errorWindow animator] setAlphaValue:0.0f];
        [NSAnimationContext endGrouping];
    }
}

- (void)setString:(NSString *)string {
    [super setString:string];
    
    [self recompile:string];
}

- (void)recompile:(NSString *)string {
    [self.file.context compile:string];
    [self colorTokensInRange:NSMakeRange(0, [string length])];
    [self setNeedsDisplayInRect:self.visibleRect];
}

- (void)recompile {
    [self recompile:self.string];
}

- (LXToken *)tokenBeforeRange:(NSRange)range {
    LXToken *closestToken = nil;
    
    for(LXToken *token in self.file.context.parser.tokens) {
        if(range.location <= token.range.location) {
            break;
        }
        
        closestToken = token;
    }
    
    return closestToken;
}

- (LXToken *)tokenAfterRange:(NSRange)range {
    LXToken *closestToken = nil;
    
    for(LXToken *token in self.file.context.parser.tokens) {
        if(token.range.location >= NSMaxRange(range)) {
            closestToken = token;
            break;
        }
    }
    
    return closestToken;
}

- (LXScope *)scopeAtLocation:(NSInteger)location {
    return [self.file.context.scope scopeAtLocation:location];
}

- (void)showAutoCompleteWindow {
    if(!showingAutoCompleteWindow) {
        showingAutoCompleteWindow = YES;
        
        [self.window addChildWindow:autoCompleteWindow ordered:NSWindowAbove];
        [autoCompleteWindow setAlphaValue:0.0f];
        [NSAnimationContext beginGrouping];
        [[NSAnimationContext currentContext] setDuration:0.1f];
        [[autoCompleteWindow animator] setAlphaValue:1.0f];
        [NSAnimationContext endGrouping];
        
        eventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSLeftMouseDownMask handler:^(NSEvent *theEvent) {
            if(theEvent.window != autoCompleteWindow) {
                [self cancelAutoComplete];
            }
            
            return theEvent;
        }];
    }
}

- (void)hideAutoCompleteWindow {
    if(!showingAutoCompleteWindow)
        return;
    
    showingAutoCompleteWindow = NO;
    
    //[autoCompleteTableView selectRowIndexes:[NSIndexSet indexSet] byExtendingSelection:NO];
    
    [NSEvent removeMonitor:eventMonitor];

    [NSAnimationContext beginGrouping];
    __block __unsafe_unretained NSWindow *bself = autoCompleteWindow;
    [[NSAnimationContext currentContext] setDuration:0.1f];
    [[NSAnimationContext currentContext] setCompletionHandler:^{
        [bself orderOut:nil];
        [self.window removeChildWindow:bself];
    }];
    
    [[autoCompleteWindow animator] setAlphaValue:0.0f];
    [NSAnimationContext endGrouping];
}

- (void)adjustSpacesForLine:(NSInteger)line {
    LXTokenNode *token = [self.file.context tokenForLine:line];
    
    if(token) {
        LXScope *scope = [self scopeAtLocation:token.location];
        
        NSInteger numberOfSpaces = 0;
        NSInteger expectedSpaces = scope.scopeLevel * 2;
        
        NSInteger location = token.range.location-1;
        
        while(location > 0) {
            char ch = [self.string characterAtIndex:location];
            
            if(ch != ' ')
                break;
            
            numberOfSpaces++;
            location--;
        }
        
        if(numberOfSpaces > expectedSpaces) {
            NSInteger diff = numberOfSpaces-expectedSpaces;
            
            [self shouldChangeTextInRange:NSMakeRange(token.range.location-diff, diff) replacementString:@"" undo:YES];
        }
        else if(numberOfSpaces < expectedSpaces) {
            NSInteger diff = expectedSpaces-numberOfSpaces;
            
            [self shouldChangeTextInRange:NSMakeRange(token.range.location, 0) replacementString:[@"" stringByPaddingToLength:diff withString:@" " startingAtIndex:0] undo:YES];
        }
    }
}

- (void)insertNewline:(id)sender {
    if(insertAutoComplete) {
        [self finishAutoComplete];
        return;
    }
    
    NSInteger currentLocation = [self selectedRange].location;
    NSInteger currentLine = [self lineForLocation:currentLocation];
    
    [self insertText:@"\n"];

    NSInteger nextLocation = [self selectedRange].location;

    LXTokenNode *currentLineToken = [self.file.context tokenForLine:currentLine];

    if(currentLineToken) {
        LXScope *scope = [self scopeAtLocation:currentLineToken.location];
        
        NSInteger numberOfSpaces = 0;
        NSInteger expectedSpaces = scope.scopeLevel * 2;
        
        NSInteger location = currentLineToken.range.location-1;
        
        while(location > 0) {
            char ch = [self.string characterAtIndex:location];
            
            if(ch != ' ')
                break;
            
            numberOfSpaces++;
            location--;
        }
        
        NSInteger diff = expectedSpaces - numberOfSpaces;
        
        if(diff < 0) {
            [self shouldChangeTextInRange:NSMakeRange(currentLineToken.range.location+diff, -diff) replacementString:@"" undo:YES];
        }
        else if(diff > 0) {
            [self shouldChangeTextInRange:NSMakeRange(currentLineToken.range.location, 0) replacementString:[@"" stringByPaddingToLength:diff withString:@" " startingAtIndex:0] undo:YES];
        }
        
        nextLocation += diff;
    }
    
    LXTokenNode *nextLineToken = [self.file.context tokenForLine:currentLine+1];

    if(nextLineToken) {
        LXScope *scope = [self scopeAtLocation:nextLineToken.location];
        
        NSInteger numberOfSpaces = 0;
        NSInteger expectedSpaces = scope.scopeLevel * 2;
        
        NSInteger location = nextLineToken.range.location-1;
        
        while(location > 0) {
            char ch = [self.string characterAtIndex:location];
            
            if(ch != ' ')
                break;
            
            numberOfSpaces++;
            location--;
        }
        
        NSInteger diff = expectedSpaces - numberOfSpaces;
        
        if(diff < 0) {
            [self shouldChangeTextInRange:NSMakeRange(nextLineToken.range.location+diff, -diff) replacementString:@"" undo:YES];
        }
        else if(diff > 0) {
            [self shouldChangeTextInRange:NSMakeRange(nextLineToken.range.location, 0) replacementString:[@"" stringByPaddingToLength:diff withString:@" " startingAtIndex:0] undo:YES];
        }
        
        [self setSelectedRange:NSMakeRange(nextLineToken.range.location+diff, 0)];
    }
    else {
        LXScope *scope = [self scopeAtLocation:nextLocation];
        [self shouldChangeTextInRange:NSMakeRange(nextLocation, 0) replacementString:[@"" stringByPaddingToLength:scope.scopeLevel*2 withString:@" " startingAtIndex:0] undo:YES];
        [self setSelectedRange:NSMakeRange(nextLocation+scope.scopeLevel*2, 0)];
    }
}

- (void)moveUp:(id)sender {
    if(insertAutoComplete) {
        if(autoCompleteTableView.selectedRow > 0) {
            [autoCompleteTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:autoCompleteTableView.selectedRow-1] byExtendingSelection:NO];
            [autoCompleteTableView scrollRowToVisible:autoCompleteTableView.selectedRow];
        }
    
        return;
    }
    
    [super moveUp:sender];
}

- (void)moveDown:(id)sender {
    if(insertAutoComplete) {
        if(autoCompleteTableView.selectedRow < autoCompleteTableView.numberOfRows-1) {
            [autoCompleteTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:autoCompleteTableView.selectedRow+1] byExtendingSelection:NO];
            [autoCompleteTableView scrollRowToVisible:autoCompleteTableView.selectedRow];
        }
        
        return;
    }
    
    [super moveDown:sender];
}

- (void)cancelOperation:(id)sender {
    [self cancelAutoComplete];
}

BOOL NSRangesTouch(NSRange range,NSRange otherRange){
    NSUInteger min, loc, max1 = NSMaxRange(range), max2= NSMaxRange(otherRange);
    
    min = (max1 < max2) ? max1 : max2;
    loc = (range.location > otherRange.location) ? range.location : otherRange.location;
    
    return min >= loc;
}

- (void)colorTokensInRange:(NSRange)range {
    [self.layoutManager removeTemporaryAttribute:NSForegroundColorAttributeName forCharacterRange:range];
    [self.layoutManager removeTemporaryAttribute:NSBackgroundColorAttributeName forCharacterRange:range];
    [self.layoutManager removeTemporaryAttribute:NSUnderlineColorAttributeName forCharacterRange:range];
    [self.layoutManager removeTemporaryAttribute:NSUnderlineStyleAttributeName forCharacterRange:range];
    [self.layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:textColor forCharacterRange:range];

    LXTokenNode *token = self.file.context.firstToken;
    
    while(token) {
        if(token.range.location > NSMaxRange(range))
            break;
        
        if(NSRangesTouch(range, token.range)) {
            switch((NSInteger)token.tokenType) {
                case LX_TK_COMMENT:
                case LX_TK_LONGCOMMENT:
                    [self.layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:commentsColor forCharacterRange:token.range];
                    break;
                case LX_TK_NUMBER:
                    [self.layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:numbersColor forCharacterRange:token.range];
                    break;
                case LX_TK_STRING:
                    [self.layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:stringsColor forCharacterRange:token.range];
                    break;
                case '(':
                case ')':
                case '{':
                case '}':
                case '[':
                case ']':
                    [self.layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:keywordsColor forCharacterRange:token.range];
                    break;
                default:
                    if([token isKeyword]) {
                        [self.layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:keywordsColor forCharacterRange:token.range];
                    }
                    else if(token.isMember) {
                        [self.layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:typesColor forCharacterRange:token.range];
                    }
                    else if(token.isType) {
                        [self.layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:typesColor forCharacterRange:token.range];
                    }
            }
        }
        
        token = token.next;
    }
    
    NSArray *errors = [self.file.context.errors arrayByAddingObjectsFromArray:self.file.context.warnings];
    
    for(LXCompilerError *error in errors) {
        if(error.isWarning) {
            [self.layoutManager addTemporaryAttribute:NSUnderlineColorAttributeName value:[NSColor colorWithCalibratedRed:1.0 green:0.865 blue:0.275 alpha:1] forCharacterRange:error.range];
        }
        else {
            [self.layoutManager addTemporaryAttribute:NSUnderlineColorAttributeName value:[NSColor redColor] forCharacterRange:error.range];
        }
        
        [self.layoutManager addTemporaryAttribute:NSUnderlineStyleAttributeName value:@(NSUnderlinePatternDot | NSUnderlineStyleThick | NSUnderlineByWordMask) forCharacterRange:error.range];
    }
}

- (void)finishUndoGroup {
    insideUndoGroup = NO;
    
    [undoManager endUndoGrouping];
}

BOOL LXLocationInRange(NSInteger location, NSRange range) {
    if(location < range.location || location > NSMaxRange(range))
        return NO;
    
    return YES;
}

- (NSInteger)lineForLocation:(NSInteger)location {
    NSInteger numberOfLines, index, stringLength = [[self string] length];
    
    for(index = 0, numberOfLines = 0; index < stringLength; numberOfLines++) {
        NSRange range = [[self string] lineRangeForRange:NSMakeRange(index, 0)];
        
        if(LXLocationInRange(location, range))
            break;
        
        index = NSMaxRange(range);
    }
    
    return numberOfLines;
}

- (void)updateAutoComplete:(NSRange)affectedCharRange replacementString:(NSString *)replacementString {
    unichar ch = 0;
    
    if([replacementString length] == 1) {
        ch = [replacementString characterAtIndex:0];
    }
    
    if(settingAutoComplete) {
        if([identifierCharacterSet characterIsMember:ch]) {
            autoCompleteWordRange.length += 1;
        }
        else if([replacementString length] == 0 && affectedCharRange.length == 1) {
            if(autoCompleteWordRange.length == 0) {
                [self cancelAutoComplete];
            }
            else {
                autoCompleteWordRange.length -= 1;
            }
        }
        else {
            [self cancelAutoComplete];
        }
    }
    else {
        BOOL isMemberAccessor = (ch == '.' || ch == ':');
        
        if([identifierCharacterSet characterIsMember:ch] || isMemberAccessor) {
            NSRange range;
            
            [autoCompleteDefinitions addObjectsFromArray:[self.file.context completionsForLocation:affectedCharRange.location+replacementString.length range:&range]];
            
            if([autoCompleteDefinitions count] > 0) {
                autoCompleteWordRange = range;
                settingAutoComplete = YES;
            }
        }
    }
}

- (void)updateCurrentAutoCompleteDefinitions {
    NSMutableArray *mutableAutoCompleteDefinitions = [[NSMutableArray alloc] init];
    NSDictionary *sizeAttribute = @{NSFontAttributeName : font};
    
    CGFloat largestTypeWidth = 0;
    CGFloat largestStringWidth = 200;
    
    if(/*autoCompleteWordRange.length && */autoCompleteWordRange.location+autoCompleteWordRange.length <= [[self string] length]) {
        NSString *string = [[self string] substringWithRange:autoCompleteWordRange];
        
        for(LXAutoCompleteDefinition *definition in autoCompleteDefinitions) {
            NSString *autoCompleteKey = definition.key;
            
            if([string isEqualToString:@""] || [autoCompleteKey hasPrefix:string]) {
                [mutableAutoCompleteDefinitions addObject:definition];
                
                CGFloat sizeOfString = [definition.title sizeWithAttributes:sizeAttribute].width + 6;
                
                if(sizeOfString > largestStringWidth) {
                    largestStringWidth = sizeOfString;
                }
                
                sizeOfString = [definition.type sizeWithAttributes:sizeAttribute].width + 6;
                
                if(sizeOfString > largestTypeWidth) {
                    largestTypeWidth = sizeOfString;
                }
            }
        }
    }
    
    [mutableAutoCompleteDefinitions sortUsingComparator:^NSComparisonResult(LXAutoCompleteDefinition *obj1, LXAutoCompleteDefinition *obj2) {
        return [obj1.key compare:obj2.key options:NSCaseInsensitiveSearch];
    }];
    
    CGFloat windowHeight = [mutableAutoCompleteDefinitions count] * (autoCompleteTableView.rowHeight + 2);
    if(windowHeight > 150) {
        windowHeight = 150;
    }
    
    if([mutableAutoCompleteDefinitions count] == 0) {
        [self hideAutoCompleteWindow];
    }
    else {
        [self showAutoCompleteWindow];
    }
    
    [[autoCompleteTableView tableColumnWithIdentifier:@"Column1"] setWidth:largestTypeWidth];
    [[autoCompleteTableView tableColumnWithIdentifier:@"Column2"] setWidth:largestStringWidth];
    
    NSRect rect = [self.layoutManager boundingRectForGlyphRange:autoCompleteWordRange inTextContainer:self.textContainer];
    rect.origin.x -= 3;
    NSRect windowRect = [self convertRect:rect toView:nil];
    NSRect screenRect = [[self window] convertRectToScreen:windowRect];
    
    screenRect.origin.x += [self textContainerOrigin].x;
    screenRect.origin.y += [self textContainerOrigin].y;

    CGFloat width = [autoCompleteTableView tableColumnWithIdentifier:@"Column1"].width + 3;
    
    [autoCompleteWindow setFrame:NSMakeRect(screenRect.origin.x - width, screenRect.origin.y - windowHeight, largestTypeWidth + largestStringWidth + 4, windowHeight) display:YES];
    [currentAutoCompleteDefinitions removeAllObjects];
    [currentAutoCompleteDefinitions addObjectsFromArray:mutableAutoCompleteDefinitions];

    [autoCompleteTableView reloadData];
    [self tableViewSelectionDidChange:nil];
}

- (BOOL)shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString {
    return [self shouldChangeTextInRange:affectedCharRange replacementString:replacementString undo:YES];
}

- (BOOL)shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString undo:(BOOL)undo {    
    settingAutoCompleteRange = YES;
    
    if(insertAutoComplete) {
        insertAutoComplete = NO;

        if(autoCompleteRange.location != NSNotFound) {
            [self shouldChangeTextInRange:autoCompleteRange replacementString:@"" undo:NO];
            autoCompleteRange = NSMakeRange(NSNotFound, 0);
        }
        
        settingAutoCompleteRange = YES;
    }
    
    if(undo) {
        if(![undoManager isUndoing] && ![undoManager isRedoing]) {
            if(!insideUndoGroup) {
                insideUndoGroup = YES;

                [undoManager beginUndoGrouping];            
            }
            
            [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(finishUndoGroup) object:nil];
            [self performSelector:@selector(finishUndoGroup) withObject:nil afterDelay:0.5];
        }
        else {
            if(insideUndoGroup) {
                insideUndoGroup = NO;

                [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(finishUndoGroup) object:nil];
            }
        }
                
        NSRange newAffectedCharRange = NSMakeRange(affectedCharRange.location, [replacementString length]);
        NSString *newReplacementString = [[self string] substringWithRange:affectedCharRange];
        
        [[undoManager prepareWithInvocationTarget:self] shouldChangeTextInRange:newAffectedCharRange replacementString:newReplacementString undo:YES];
    }
    
    NSInteger deletedLines = [[[self.string substringWithRange:affectedCharRange] componentsSeparatedByString:@"\n"] count] - 1;
    NSInteger newLines = [[replacementString componentsSeparatedByString:@"\n"] count] - 1;
    
    NSInteger line = [self lineForLocation:affectedCharRange.location];
    NSInteger lineDiff = newLines - deletedLines;
    
    if(highlightedLine != -1) {
        if(line < highlightedLine-1) {
            highlightedLine += lineDiff;
        }
    }

    [self.file offsetBreakpoints:line diff:lineDiff];
    
    NSMutableArray *newMarkers = [NSMutableArray arrayWithCapacity:[autoCompleteMarkers count]];
    
    [self replaceCharactersInRange:affectedCharRange withString:replacementString];
    [self recompile:self.string];
    
    NSInteger diff = [replacementString length] - affectedCharRange.length;

    for(NSValue *value in autoCompleteMarkers) {
        NSRange range = [value rangeValue];
        
        if(NSIntersectionRange(affectedCharRange, range).length > 0) {
            continue;
        }
        else if(range.location >= NSMaxRange(affectedCharRange)) {
            range.location += diff;
        }
        
        [newMarkers addObject:[NSValue valueWithRange:range]];
    }
    
    autoCompleteMarkers = newMarkers;

    [self scrollRangeToVisible:NSMakeRange(affectedCharRange.location + [replacementString length], 0)];
    [self didChangeText];
    [self setNeedsDisplayInRect:self.visibleRect];

    settingAutoCompleteRange = NO;
    
    if(undo) {
        [self updateAutoComplete:affectedCharRange replacementString:replacementString];
        [self updateCurrentAutoCompleteDefinitions];
    }
    
    return NO;
}

- (NSUndoManager *)undoManager {
    return undoManager;
}

- (NSRange)selectionRangeForProposedRange:(NSRange)proposedSelRange granularity:(NSSelectionGranularity)granularity {    
    for(NSValue *value in autoCompleteMarkers) {
        NSRange range = [value rangeValue];
    
        if(proposedSelRange.location >= range.location && NSMaxRange(proposedSelRange) <= NSMaxRange(range)) {
            return range;
        }
        else {
            NSRange intersection = NSIntersectionRange(range, proposedSelRange);
            
            if(intersection.length > 0 && intersection.length < range.length) {
                if(intersection.length >= range.length * 0.5) {
                    return NSUnionRange(range, proposedSelRange);
                }
                else {
                    if(range.location > proposedSelRange.location) {
                        return NSMakeRange(proposedSelRange.location, range.location-proposedSelRange.location);
                    }
                    else {
                        return NSMakeRange(NSMaxRange(range), NSMaxRange(proposedSelRange)-NSMaxRange(range));
                    }
                }
            }
        }
    }
    
    return [super selectionRangeForProposedRange:proposedSelRange granularity:granularity];
}

- (void)setSelectedRange:(NSRange)charRange affinity:(NSSelectionAffinity)affinity stillSelecting:(BOOL)stillSelectingFlag {
    if(insertAutoComplete && !settingAutoCompleteRange) {
        [self cancelAutoComplete];
    }

    for(NSValue *marker in autoCompleteMarkers) {
        NSRange intersection = NSIntersectionRange(marker.rangeValue, charRange);
        
        if(intersection.length > 0) {
            [self.layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:[NSColor colorWithCalibratedWhite:0.2 alpha:1] forCharacterRange:marker.rangeValue];
        }
        else {
            [self.layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:textColor forCharacterRange:marker.rangeValue];
        }
    }
    
    [super setSelectedRange:charRange affinity:affinity stillSelecting:stillSelectingFlag];
}

- (NSArray *)textView:(NSTextView *)textView completions:(NSArray *)words forPartialWordRange:(NSRange)charRange indexOfSelectedItem:(NSInteger *)index {
    return nil;
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	return [currentAutoCompleteDefinitions count];
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    BOOL selected = [tableView selectedRow] == row;
    LXAutoCompleteDefinition *definition = currentAutoCompleteDefinitions[row];
    
    if([tableColumn.identifier isEqualToString:@"Column1"]) {
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
        [paragraphStyle setAlignment:NSRightTextAlignment];
        
        if(selected) {
            NSShadow *shadow = [[NSShadow alloc] init];
            [shadow setShadowBlurRadius:0];
            [shadow setShadowColor:[NSColor blackColor]];
            [shadow setShadowOffset:CGSizeMake(0, -1.0f)];
            
            return [[NSAttributedString alloc] initWithString:definition.type attributes:@{NSForegroundColorAttributeName : [NSColor whiteColor], NSFontAttributeName : [[NSFontManager sharedFontManager]
                                                                                                                                                                         fontWithFamily:@"Menlo"
                                                                                                                                                                         traits:NSBoldFontMask
                                                                                                                                                                         weight:0
                                                                                                                                                                         size:11], NSShadowAttributeName : shadow, NSParagraphStyleAttributeName : paragraphStyle}];
        }
        else {
            return [[NSAttributedString alloc] initWithString:definition.type attributes:@{NSForegroundColorAttributeName : [NSColor blueColor], NSParagraphStyleAttributeName : paragraphStyle}];
        }
    }
    else {
        if(selected) {
            NSShadow *shadow = [[NSShadow alloc] init];
            [shadow setShadowBlurRadius:0];
            [shadow setShadowColor:[NSColor blackColor]];
            [shadow setShadowOffset:CGSizeMake(0, -1.0f)];
            
            return [[NSAttributedString alloc] initWithString:definition.title attributes:@{NSForegroundColorAttributeName : [NSColor whiteColor], NSFontAttributeName : [[NSFontManager sharedFontManager]
                                                                                                                                                                          fontWithFamily:@"Menlo"
                                                                                                                                                                          traits:NSBoldFontMask
                                                                                                                                                                          weight:0
                                                                                                                                                                          size:11], NSShadowAttributeName : shadow}];
        }
        else {
            return [[NSAttributedString alloc] initWithString:definition.title attributes:@{NSForegroundColorAttributeName : [NSColor blackColor]}];
        }
    }
}

- (BOOL)tableView:(NSTableView *)tableView shouldEditTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    return NO;
}

- (void)tableViewSelectionDidChange:(NSNotification *)notification {
    NSInteger selectedRow = [autoCompleteTableView selectedRow];
    
    [self autoCompleteIndexChanged:selectedRow];
}

- (void)autoCompleteIndexChanged:(NSInteger)index {
    if(index != -1) {
        LXAutoCompleteDefinition *definition = currentAutoCompleteDefinitions[index];
        
        NSString *autoCompleteWord = definition.string;
        
        NSString *string = [[self string] substringWithRange:autoCompleteWordRange];

        LXScope *scope = [self scopeAtLocation:autoCompleteWordRange.location];
        
        autoCompleteString = [[autoCompleteWord substringFromIndex:[string length]] stringByReplacingOccurrencesOfString:@"\n" withString:[NSString stringWithFormat:@"\n%@", [@"" stringByPaddingToLength:scope.scopeLevel*2 withString:@" " startingAtIndex:0]]];
        
        [self shouldChangeTextInRange:NSMakeRange(NSMaxRange(autoCompleteWordRange), 0) replacementString:autoCompleteString undo:NO];
        
        autoCompleteRange = NSMakeRange(NSMaxRange(autoCompleteWordRange), [autoCompleteString length]);

        [self.layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:[NSColor colorWithCalibratedRed:0.937 green:0.902 blue:0.588 alpha:0.6] forCharacterRange:autoCompleteRange];
        
        [self setSelectedRange:NSMakeRange(autoCompleteRange.location, 0)];
        
        insertAutoComplete = YES;
        
        if(definition.summary) {
            autoCompleteDescriptionView.stringValue = definition.summary;
            [autoCompleteDescriptionView setHidden:NO];
        }
        else {
            [autoCompleteDescriptionView setHidden:YES];
        }
        
        //TODO: This is retarded
        NSArray *strings = [definition.string componentsSeparatedByString:@"\n"];
        
        for(NSValue *marker in definition.markers) {
            NSRange range = [marker rangeValue];
            
            NSInteger location = 0;
            NSInteger lines = 0;
            for(NSString *string in strings) {
                location += [string length] + 1;

                if(range.location <= location)
                    break;
                
                ++lines;
            }
            
            range.location += lines * (scope.scopeLevel * 2);
            
            [autoCompleteMarkers addObject:[NSValue valueWithRange:NSMakeRange(autoCompleteWordRange.location+range.location, range.length)]];
        }
    }
}

- (void)finishAutoComplete {
    if(insertAutoComplete) {
        settingAutoComplete = NO;
        insertAutoComplete = NO;
        
        [autoCompleteDefinitions removeAllObjects];
        
        [[undoManager prepareWithInvocationTarget:self] shouldChangeTextInRange:autoCompleteRange replacementString:@"" undo:YES];
        [self colorTokensInRange:autoCompleteRange];
        
        NSRange selectedRange = NSMakeRange(NSMaxRange(autoCompleteRange), 0);
        
        for(NSValue *value in autoCompleteMarkers) {
            NSRange range = [value rangeValue];
            
            if(NSIntersectionRange(autoCompleteRange, range).length > 0) {
                selectedRange = range;
                break;
            }
        }
        
        autoCompleteRange = NSMakeRange(NSNotFound, 0);

        //autoCompleteWordRange = NSMakeRange(0, 0);
        [self setSelectedRange:selectedRange];
        
        [self hideAutoCompleteWindow];
    }
}

- (void)cancelAutoComplete {
    if(settingAutoComplete) {
        settingAutoComplete = NO;
        [autoCompleteDefinitions removeAllObjects];
        
        insertAutoComplete = NO;
        
        if(autoCompleteRange.location != NSNotFound) {
            [self shouldChangeTextInRange:autoCompleteRange replacementString:@"" undo:NO];
            autoCompleteRange = NSMakeRange(NSNotFound, 0);
        }

        //autoCompleteWordRange = NSMakeRange(0, 0);

        [self hideAutoCompleteWindow];
    }
}

- (BOOL)isOpaque {
	return YES;
}

- (void)insertTab:(id)sender {
    if(insertAutoComplete) {
        [self finishAutoComplete];
        return;
    }
    
    if([autoCompleteMarkers count] > 0) {
        NSRange selectedRange = [self selectedRange];
        NSRange closestRange = NSMakeRange(NSNotFound, 0);
        
        for(NSValue *value in autoCompleteMarkers) {
            NSRange range = [value rangeValue];
         
            if(range.location > selectedRange.location) {
                if(range.location < closestRange.location) {
                    closestRange = range;
                }
            }
        }
        
        if(closestRange.location != NSNotFound) {
            [self setSelectedRange:closestRange];
        }
        
        return;
    }
    
	BOOL shouldShiftText = NO;
	
	if([self selectedRange].length > 0) {
		NSRange rangeOfFirstLine = [[self string] lineRangeForRange:NSMakeRange([self selectedRange].location, 0)];
		NSInteger firstCharacterOfFirstLine = rangeOfFirstLine.location;
		while([[self string] characterAtIndex:firstCharacterOfFirstLine] == ' ' || [[self string] characterAtIndex:firstCharacterOfFirstLine] == '\t') {
			firstCharacterOfFirstLine++;
		}
		
		if([self selectedRange].location <= firstCharacterOfFirstLine) {
			shouldShiftText = YES;
		}
	}
	
	if(!shouldShiftText) {
		NSMutableString *spacesString = [NSMutableString string];
		NSInteger numberOfSpacesPerTab = 2;

		while (numberOfSpacesPerTab--) {
			[spacesString appendString:@" "];
		}
		
		[self insertText:spacesString];
	}
}

- (NSInteger)lineHeight {
    return lineHeight;
}

- (void)setTabWidth {
	NSMutableString *sizeString = [NSMutableString string];
	NSInteger numberOfSpaces = 2;
	while(numberOfSpaces--) {
		[sizeString appendString:@" "];
	}
    
	NSDictionary *sizeAttribute = @{NSFontAttributeName : font};
	CGFloat sizeOfTab = [sizeString sizeWithAttributes:sizeAttribute].width;
	
	NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	
	NSArray *array = [style tabStops];
	for(id item in array) {
		[style removeTabStop:item];
	}
	[style setDefaultTabInterval:sizeOfTab];
	NSDictionary *attributes = [[NSDictionary alloc] initWithObjectsAndKeys:style, NSParagraphStyleAttributeName, nil];
	[self setTypingAttributes:attributes];
}

- (NSRect)highlightRectForRange:(NSRange)aRange {
    NSRange r = aRange;
    NSRange startLineRange = [[self string] lineRangeForRange:NSMakeRange(r.location, 0)];
    NSInteger er = NSMaxRange(r)-1;
    NSString *text = [self string];
	
    if (er >= [text length]) {
        return NSZeroRect;
    }
    if (er < r.location) {
        er = r.location;
    }
	
    NSRange endLineRange = [[self string] lineRangeForRange:NSMakeRange(er, 0)];
	
    NSRange gr = [[self layoutManager] glyphRangeForCharacterRange:NSMakeRange(startLineRange.location, NSMaxRange(endLineRange)-startLineRange.location-1)
                                              actualCharacterRange:NULL];
    NSRect br = [[self layoutManager] boundingRectForGlyphRange:gr inTextContainer:[self textContainer]];
    NSRect b = [self bounds];
    CGFloat h = br.size.height;
    CGFloat w = b.size.width;
    CGFloat y = br.origin.y;
    NSPoint containerOrigin = [self textContainerOrigin];
    NSRect aRect = NSMakeRect(0, y, w, h);
    // Convert from view coordinates to container coordinates
    aRect = NSOffsetRect(aRect, containerOrigin.x, containerOrigin.y);
    return aRect;
}

- (void)drawScope:(LXScope *)scope {
    NSUInteger rectCount;
    NSRectArray rects = [[self layoutManager] rectArrayForCharacterRange:scope.range withinSelectedCharacterRange:NSMakeRange(NSNotFound, 0) inTextContainer:[self textContainer] rectCount:&rectCount];
    
    [[NSColor colorWithDeviceRed:0.9-scope.scopeLevel*0.05 green:0.9-scope.scopeLevel*0.05 blue:0.9-scope.scopeLevel*0.05 alpha:1.0] set];
    
    for(NSUInteger i = 0; i < rectCount; ++i) {
        NSRect rect = rects[i];
        
        if(rect.origin.x == 5)
            [NSBezierPath fillRect:NSMakeRect(1, rect.origin.y, 5, rect.size.height)];
        
            //[NSBezierPath strokeLineFromPoint:NSMakePoint(rect.origin.x, rect.origin.y) toPoint:NSMakePoint(rect.origin.x, NSMaxY(rect))];
    }
    
    for(LXScope *child in scope.children) {
        [self drawScope:child];
    }
}

- (void)drawViewBackgroundInRect:(NSRect)rect {
    [super drawViewBackgroundInRect:rect];
    
    if(highlightedLine != -1) {
        NSInteger index, lineNumber;
        for(index = 0, lineNumber = 0; lineNumber < highlightedLine-1; lineNumber++) {
            index = NSMaxRange([[self string] lineRangeForRange:NSMakeRange(index, 0)]);
        }
        
        NSRange sel = [[self string] lineRangeForRange:NSMakeRange(index, 0)];
        NSString *str = [self string];
        
        if(sel.location <= [str length]) {
            NSRange lineRange = [str lineRangeForRange:NSMakeRange(sel.location,0)];
            NSRect lineRect = [self highlightRectForRange:lineRange];
            
            [highlightedLineBackgroundColor set];
            [NSBezierPath fillRect:lineRect];
            [highlightedLineColor set];
            [NSBezierPath strokeLineFromPoint:lineRect.origin toPoint:NSMakePoint(lineRect.origin.x+lineRect.size.width, lineRect.origin.y)];
            [NSBezierPath strokeLineFromPoint:NSMakePoint(lineRect.origin.x, lineRect.origin.y+lineRect.size.height) toPoint:NSMakePoint(lineRect.origin.x+lineRect.size.width, lineRect.origin.y+lineRect.size.height)];
        }
    }
    
    NSUInteger rectCount;
    NSRectArray rects = [[self layoutManager] rectArrayForCharacterRange:[self selectedRange] withinSelectedCharacterRange:NSMakeRange(NSNotFound, 0) inTextContainer:[self textContainer] rectCount:&rectCount];
    
    [[NSColor colorWithCalibratedRed:0.176 green:0.263 blue:0.251 alpha:1] set];
    
    for(NSUInteger i = 0; i < rectCount; ++i) {
        NSRect rect = rects[i];
        rect = NSOffsetRect(rect, [self textContainerOrigin].x, [self textContainerOrigin].y);
        
        [NSBezierPath fillRect:rect];
    }
    
    NSArray *errors = [self.file.context.errors arrayByAddingObjectsFromArray:self.file.context.warnings];

    for(LXCompilerError *error in errors) {
        NSRange range = error.range;
        
        NSRect rangeRect = [[self layoutManager] boundingRectForGlyphRange:range inTextContainer:[self textContainer]];
        rangeRect = NSOffsetRect(rangeRect, [self textContainerOrigin].x, [self textContainerOrigin].y);
        NSBezierPath *path = [NSBezierPath bezierPath];
        [path moveToPoint:NSMakePoint(rangeRect.origin.x, NSMaxY(rangeRect))];
        [path lineToPoint:NSMakePoint(rangeRect.origin.x+2, NSMaxY(rangeRect)+2)];
        [path lineToPoint:NSMakePoint(rangeRect.origin.x-2, NSMaxY(rangeRect)+2)];
        [path closePath];
        
        if(error.isWarning) {
            [[NSColor colorWithCalibratedRed:0.865 green:0.665 blue:0.275 alpha:1] set];
        }
        else {
            [[NSColor colorWithDeviceRed:0.8 green:0.0 blue:0.0 alpha:1.0] set];
        }
        
        [path fill];
    }
    
    for(NSValue *value in autoCompleteMarkers) {
        NSRange range = [value rangeValue];
        
        NSRect rangeRect = [[self layoutManager] boundingRectForGlyphRange:range inTextContainer:[self textContainer]];
        rangeRect = NSOffsetRect(rangeRect, [self textContainerOrigin].x, [self textContainerOrigin].y);
        rangeRect = NSInsetRect(rangeRect, -3, 0);
        
        if(NSIntersectsRect(rect, rangeRect)) {
            NSRange intersection = NSIntersectionRange(range, [self selectedRange]);
            
            NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rangeRect xRadius:8 yRadius:8];
                        
            if(intersection.length > 0) {
                [[NSColor colorWithDeviceRed:0 green:0.665 blue:0.845 alpha:1.0] set];
                [path fill];
            }
            else {
                [[NSColor colorWithCalibratedRed:0 green:0.376 blue:0.573 alpha:1] set];
                [path fill];
                [[NSColor colorWithCalibratedRed:0 green:0.565 blue:0.745 alpha:1] set];
                [path stroke];
            }
           
        }
    }
}

- (BOOL)resignFirstResponder {
    if(![super resignFirstResponder]) {
        return NO;
    }
    else {
        [self setSelectedRange:NSMakeRange(NSNotFound, 0)];
        
        return YES;
    }
}

- (NSString *)stringForLine:(NSInteger)line {
	NSInteger index;
	NSString *completeString = [self string];
	NSInteger completeStringLength = [completeString length];
	NSInteger currentLine;
	for(index = 0, currentLine = 1; index < completeStringLength; currentLine++) {
        if(currentLine == line) {
            return [completeString substringWithRange:[completeString lineRangeForRange:NSMakeRange(index, 0)]];
        }
        
		index = NSMaxRange([completeString lineRangeForRange:NSMakeRange(index, 0)]);
	}
    
    return @"";
}

- (void)scrollToLine:(NSInteger)line {
    NSInteger lineNumber;
	NSInteger index;
	NSString *completeString = [self string];
	NSInteger completeStringLength = [completeString length];
	NSInteger numberOfLinesInDocument;
	for(index = 0, numberOfLinesInDocument = 1; index < completeStringLength; numberOfLinesInDocument++) {
		index = NSMaxRange([completeString lineRangeForRange:NSMakeRange(index, 0)]);
	}
    
	if(line > numberOfLinesInDocument) {
		NSBeep();
		return;
	}
	
	for(index = 0, lineNumber = 1; lineNumber < line; lineNumber++) {
		index = NSMaxRange([completeString lineRangeForRange:NSMakeRange(index, 0)]);
	}
	
	[self scrollRangeToVisible:[completeString lineRangeForRange:NSMakeRange(index, 0)]];
}

- (void)setHighlightedLine:(NSInteger)line {
	highlightedLine = line;
    
	if(highlightedLine == -1) {
		[self setNeedsDisplay:YES];
		return;
	}
	
	NSInteger lineNumber;
	NSInteger index;
	NSString *completeString = [self string];
	NSInteger completeStringLength = [completeString length];
	NSInteger numberOfLinesInDocument;
	for(index = 0, numberOfLinesInDocument = 1; index < completeStringLength; numberOfLinesInDocument++) {
		index = NSMaxRange([completeString lineRangeForRange:NSMakeRange(index, 0)]);
	}
    
	if(highlightedLine > numberOfLinesInDocument) {
		NSBeep();
		return;
	}
	
	for(index = 0, lineNumber = 1; lineNumber < highlightedLine; lineNumber++) {
		index = NSMaxRange([completeString lineRangeForRange:NSMakeRange(index, 0)]);
	}
	
	[self scrollRangeToVisible:[completeString lineRangeForRange:NSMakeRange(index, 0)]];
}

- (void)setHighlightedLineColor:(NSColor *)color background:(NSColor *)background {	
	highlightedLineColor = [color copy];
	highlightedLineBackgroundColor = [background copy];
}

@end
