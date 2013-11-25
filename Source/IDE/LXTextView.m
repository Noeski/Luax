#import "LXTextView.h"
#import "LXDocument.h"
#import "LXNode.h"
#import "LXToken.h"
#import "NSString+JSON.h"

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

- (id)initWithFrame:(NSRect)frame document:(LXDocument *)document {
	if(self = [super initWithFrame:frame]) {
        _document = document;
        
        undoManager = [[LXTextViewUndoManager alloc] init];
        
        errors = [[NSMutableArray alloc] init];
        identifierCharacterSet = [NSCharacterSet characterSetWithCharactersInString:
                                  @"_0123456789abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"];
        NSRect frame = NSMakeRect(0, 0, 150, 150);
        window = [[NSWindow alloc] initWithContentRect:frame
                                             styleMask:NSBorderlessWindowMask
                                               backing:NSBackingStoreBuffered
                                                 defer:NO];
        window.alphaValue = 0.0f;
        window.hasShadow = YES;
        
        window.delegate = self;
        [window setBackgroundColor:[NSColor clearColor]];
        
        NSFont *font = [[NSFontManager sharedFontManager] fontWithFamily:@"Menlo"
                                                                  traits:0
                                                                  weight:0
                                                                    size:11];
        
        NSView *contentView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 150, 150)];
        [contentView setWantsLayer:YES];
        [contentView.layer setBackgroundColor:CGColorCreateGenericGray(1, 1)];
        autoCompleteScrollView = [[NSScrollView alloc] initWithFrame:NSMakeRect(0, 0, 150, 150)];
        autoCompleteTableView = [[NSTableView alloc] initWithFrame:NSMakeRect(0, 0, 150, 150)];
        
        [autoCompleteTableView setAllowsEmptySelection:NO];
        [autoCompleteTableView setAllowsMultipleSelection:NO];
        [autoCompleteTableView setDoubleAction:@selector(finishAutoComplete)];
        
        NSTextFieldCell *cell = [[NSTextFieldCell alloc] init];
        cell.font = font;
        cell.alignment = NSRightTextAlignment;
        NSTableColumn *tableColumn = [[NSTableColumn alloc] initWithIdentifier:@"Column1"];
        [tableColumn setWidth:150];
        [tableColumn setDataCell:cell];
        
        [autoCompleteTableView addTableColumn:tableColumn];
        
        cell = [[NSTextFieldCell alloc] init];
        cell.font = font;
        tableColumn = [[NSTableColumn alloc] initWithIdentifier:@"Column2"];
        [tableColumn setWidth:150];
        [tableColumn setDataCell:cell];
        
        [autoCompleteTableView addTableColumn:tableColumn];
        
        [autoCompleteTableView setHeaderView:nil];
        [autoCompleteTableView setDataSource:self];
        [autoCompleteTableView setDelegate:self];
        [autoCompleteScrollView setDocumentView:autoCompleteTableView];
        [autoCompleteScrollView setHasVerticalScroller:YES];
        [contentView addSubview:autoCompleteScrollView];

        autoCompleteDescriptionView = [[NSTextField alloc] initWithFrame:NSMakeRect(0, 0, 150, 150)];
        [autoCompleteDescriptionView setFont:font];
        [autoCompleteDescriptionView setStringValue:@"My Label"];
        [autoCompleteDescriptionView setBezeled:NO];
        [autoCompleteDescriptionView setDrawsBackground:NO];
        [autoCompleteDescriptionView setEditable:NO];
        [autoCompleteDescriptionView setSelectable:NO];
        
        NSView *separatorView = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 150, 1)];
        [separatorView setAutoresizingMask:NSViewWidthSizable | NSViewMaxYMargin];
        [separatorView setWantsLayer:YES];
        [separatorView.layer setBackgroundColor:CGColorCreateGenericGray(0.8, 1)];
        [autoCompleteDescriptionView addSubview:separatorView];
        
        [contentView addSubview:autoCompleteDescriptionView];
        
        window.contentView = contentView;
        
		[self setDefaults];     
	}
    
	return self;
}

- (void)setDefaults {
	highlightedLine = -1;
	
    commentsColor = [NSColor colorWithDeviceRed:0.0f green:0.6f blue:0.0f alpha:1.0f];
    keywordsColor = [NSColor colorWithDeviceRed:0.8f green:0.0f blue:0.4f alpha:1.0f];
    numbersColor = [NSColor blueColor];
    functionsColor = [NSColor colorWithDeviceRed:0.6f green:0.0f blue:0.8f alpha:1.0f];
    stringsColor = [NSColor redColor];
    typesColor = [NSColor colorWithDeviceRed:0.314 green:0.506 blue:0.529 alpha:1];
    
    NSString *path = [[NSBundle mainBundle] pathForResource:@"AutoCompleteDefinitions" ofType:@"json"];
    NSError *error;
    NSDictionary *dictionary = [[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:&error] JSONValue];
    NSArray *definitions = dictionary[@"definitions"];
    baseAutoCompleteDefinitions = [[NSMutableArray alloc] initWithCapacity:[definitions count]];
    autoCompleteDefinitions = [[NSMutableArray alloc] init];
    currentAutoCompleteDefinitions = [[NSMutableArray alloc] init];
    
    for(NSDictionary *definition in definitions) {
        LXAutoCompleteDefinition *autoCompleteDefinition = [[LXAutoCompleteDefinition alloc] init];
        
        autoCompleteDefinition.key = definition[@"key"];
        
        NSString *string = definition[@"string"];
        NSMutableArray *autoCompleteDefinitionMarkers = [NSMutableArray array];
        NSRange firstMarkerRange = [string rangeOfString:@"\\m" options:NSLiteralSearch range:NSMakeRange(0, [string length])];
        NSInteger offset = 0;
        
        while(firstMarkerRange.location != NSNotFound) {
            NSRange secondMarkerRange = [string rangeOfString:@"\\m" options:NSLiteralSearch range:NSMakeRange(NSMaxRange(firstMarkerRange), [string length] - NSMaxRange(firstMarkerRange))];
            
            if(secondMarkerRange.location == NSNotFound)
                break;
                        
            NSInteger location = NSMaxRange(firstMarkerRange) - offset - 2;
            NSInteger length = secondMarkerRange.location - location - offset - 2;
            
            [autoCompleteDefinitionMarkers addObject:[NSValue valueWithRange:NSMakeRange(location, length)]];

            firstMarkerRange = [string rangeOfString:@"\\m" options:NSLiteralSearch range:NSMakeRange(NSMaxRange(secondMarkerRange), [string length] - NSMaxRange(secondMarkerRange))];
            
            offset += 4;
        }
        
        autoCompleteDefinition.string = [string stringByReplacingOccurrencesOfString:@"\\m" withString:@""];
        autoCompleteDefinition.title = definition[@"title"];
        autoCompleteDefinition.description = definition[@"description"];
        autoCompleteDefinition.markers = autoCompleteDefinitionMarkers;
        [baseAutoCompleteDefinitions addObject:autoCompleteDefinition];
    }
    
    autoCompleteMarkers = [[NSMutableArray alloc] init];
    
    NSFont *font = [[NSFontManager sharedFontManager]
                    fontWithFamily:@"Menlo"
                    traits:0
                    weight:0
                    size:11];
    
    [self setSelectedTextAttributes:@{NSBackgroundColorAttributeName : [NSColor clearColor]}];

    [self setHighlightedLineColor:[NSColor blueColor] background:[NSColor colorWithDeviceRed:0.8f green:0.8f blue:1.0f alpha:1.0f]];
    
	[self setTabWidth];
	
	[self setVerticallyResizable:YES];
	[self setMaxSize:NSMakeSize(FLT_MAX, FLT_MAX)];
	[self setAutoresizingMask:NSViewWidthSizable];
	[self setAllowsUndo:YES];
	[self setUsesFindPanel:YES];
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
    
	NSTrackingArea *trackingArea = [[NSTrackingArea alloc] initWithRect:[self frame] options:(NSTrackingMouseEnteredAndExited | NSTrackingActiveWhenFirstResponder) owner:self userInfo:nil];
	[self addTrackingArea:trackingArea];
	
	lineHeight = [[[self textContainer] layoutManager] defaultLineHeightForFont:font];    
}

- (void)setString:(NSString *)string {
    [super setString:string];
    
    [self recompile:string];
}

- (void)recompile:(NSString *)string {
    [self.document.context compile:string];
    
    for(LXToken *token in self.document.context.parser.tokens) {
        switch(token.type) {
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
            default:
                if([token isKeyword]) {
                    [self.layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:keywordsColor forCharacterRange:token.range];
                }
                else if(token.isMember) {
                    [self.layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:typesColor forCharacterRange:token.range];
                }
                else if(token.variableType.isDefined) {
                    [self.layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:typesColor forCharacterRange:token.range];
                }
            }
    }
}

- (LXToken *)tokenBeforeRange:(NSRange)range {
    LXToken *closestToken = nil;
    
    for(LXToken *token in self.document.context.parser.tokens) {
        if(range.location <= token.range.location) {
            break;
        }
        
        closestToken = token;
    }
    
    return closestToken;
}

- (LXToken *)tokenAfterRange:(NSRange)range {
    LXToken *closestToken = nil;
    
    for(LXToken *token in self.document.context.parser.tokens) {
        if(token.range.location >= NSMaxRange(range)) {
            closestToken = token;
            break;
        }
    }
    
    return closestToken;
}

- (LXScope *)scopeAtLocation:(NSInteger)location {
    return [self.document.context.compiler.globalScope scopeAtLocation:location];
}

- (void)showAutoCompleteWindow {
    if(!showingAutoCompleteWindow) {
        showingAutoCompleteWindow = YES;
        
        [self.window addChildWindow:window ordered:NSWindowAbove];
        [window setAlphaValue:0.0f];
        [NSAnimationContext beginGrouping];
        [[NSAnimationContext currentContext] setDuration:0.1f];
        [[window animator] setAlphaValue:1.0f];
        [NSAnimationContext endGrouping];
        
        eventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSLeftMouseDownMask handler:^(NSEvent *theEvent) {
            if(theEvent.window != window) {
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
    __block __unsafe_unretained NSWindow *bself = window;
    [[NSAnimationContext currentContext] setDuration:0.1f];
    [[NSAnimationContext currentContext] setCompletionHandler:^{
        [bself orderOut:nil];
        [self.window removeChildWindow:bself];
    }];
    
    [[window animator] setAlphaValue:0.0f];
    [NSAnimationContext endGrouping];
}

- (void)insertNewline:(id)sender {
    if(insertAutoComplete) {
        [self finishAutoComplete];
        return;
    }
    
    NSRange currentRange = [self selectedRange];
    LXScope *scope = [self scopeAtLocation:currentRange.location];
    
    NSString *string = [@"" stringByPaddingToLength:scope.scopeLevel * 2 withString:@" " startingAtIndex:0];
    string = [@"\n" stringByAppendingString:string];
    
    [self insertText:string];
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
    
    for(LXToken *token in self.document.context.parser.tokens) {
        if(token.range.location > NSMaxRange(range))
            break;
        
        if(!NSRangesTouch(range, token.range))
            continue;
        
        switch(token.type) {
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
            default: {
                if([token isKeyword]) {
                    [self.layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:keywordsColor forCharacterRange:token.range];
                }
                else {
                    [self.layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:[NSColor blackColor] forCharacterRange:token.range];
                }
                break;
            }
        }        
    }
}

- (void)finishUndoGroup {
    insideUndoGroup = NO;
    
    [undoManager endUndoGrouping];
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
        if([identifierCharacterSet characterIsMember:ch]) {
            NSInteger startIndex = affectedCharRange.location-1;
            
            while(startIndex >= 0) {
                ch = [[self string] characterAtIndex:startIndex];
                
                if(![identifierCharacterSet characterIsMember:ch])
                    break;
                
                startIndex--;
            }
            
            NSString *string = [NSString stringWithFormat:@"%@%@", [[self string] substringWithRange:NSMakeRange(startIndex+1, affectedCharRange.location-(startIndex+1))], replacementString];
            
            if([string length] >= 1 && ![[NSCharacterSet decimalDigitCharacterSet] characterIsMember:[string characterAtIndex:0]]) {
                //Find type of autocomplete
                LXScope *scope = [self scopeAtLocation:affectedCharRange.location];
                
                if(scope.type == LXScopeTypeClass ||
                   scope.type == LXScopeTypeFunction) {
                    for(NSString *key in [self.document.context.compiler.typeMap allKeys]) {
                        if(![self.document.context.compiler.typeMap[key] isDefined])
                            continue;
                        
                        LXAutoCompleteDefinition *autoCompleteDefinition = [[LXAutoCompleteDefinition alloc] init];
                        
                        autoCompleteDefinition.key = key;
                        autoCompleteDefinition.type = @"Class";
                        autoCompleteDefinition.string = key;
                        autoCompleteDefinition.title = key;
                        autoCompleteDefinition.description = nil;
                        autoCompleteDefinition.markers = nil;
                        [autoCompleteDefinitions addObject:autoCompleteDefinition];
                    }
                }
                else {
                    while(scope) {
                        for(LXVariable *variable in scope.localVariables) {
                            BOOL found = NO;
                            
                            for(LXAutoCompleteDefinition *definition in autoCompleteDefinitions) {
                                if([definition.key isEqualToString:variable.name]) {
                                    found = YES;
                                    break;
                                }
                            }
                            
                            if(found)
                                continue;
                            
                            LXAutoCompleteDefinition *autoCompleteDefinition = [[LXAutoCompleteDefinition alloc] init];
                            
                            autoCompleteDefinition.key = variable.name;
                            autoCompleteDefinition.type = variable.type.name ? variable.type.name : @"(Undefined)";
                            autoCompleteDefinition.string = variable.name;
                            autoCompleteDefinition.title = variable.name;
                            autoCompleteDefinition.description = nil;
                            autoCompleteDefinition.markers = nil;
                            [autoCompleteDefinitions addObject:autoCompleteDefinition];
                        }
                        
                        scope = scope.parent;
                    }
                    
                    //
                    for(LXAutoCompleteDefinition *definition in baseAutoCompleteDefinitions) {
                        BOOL found = NO;
                        
                        for(LXAutoCompleteDefinition *otherDefinition in autoCompleteDefinitions) {
                            if([otherDefinition.key isEqualToString:definition.key]) {
                                found = YES;
                                break;
                            }
                        }
                        
                        if(found)
                            continue;
                        
                        [autoCompleteDefinitions addObject:definition];
                    }
                }
                
                if([autoCompleteDefinitions count] > 0) {
                    autoCompleteWordRange = NSMakeRange(startIndex+1, (affectedCharRange.location-(startIndex+1))+[replacementString length]);
                    settingAutoComplete = YES;
                }
            }
        }
        else if(ch == '.' ||
                ch == ':') {
            NSInteger startIndex = affectedCharRange.location-1;

            LXToken *previousToken = [self tokenBeforeRange:NSMakeRange(startIndex+1, 0)];
            LXToken *variableToken = previousToken;
            
            if(variableToken.variable.type.isDefined) {
                LXClass *tokenClass = variableToken.variable.type;
                
                while(tokenClass) {
                    for(LXVariable *variable in tokenClass.variables) {
                        LXAutoCompleteDefinition *autoCompleteDefinition = [[LXAutoCompleteDefinition alloc] init];
                        
                        autoCompleteDefinition.key = variable.name;
                        autoCompleteDefinition.type = variable.type.name ? variable.type.name : @"(Undefined)";
                        autoCompleteDefinition.string = variable.name;
                        autoCompleteDefinition.title = variable.name;
                        autoCompleteDefinition.description = nil;
                        autoCompleteDefinition.markers = nil;
                        [autoCompleteDefinitions addObject:autoCompleteDefinition];
                    }
                    
                    /*for(LXNodeFunctionStatement *functionStatement in tokenClass.functions) {
                        LXNodeFunctionExpression *function = (LXNodeFunctionExpression *)functionStatement.expression;
                        
                        LXAutoCompleteDefinition *autoCompleteDefinition = [[LXAutoCompleteDefinition alloc] init];
                        
                        autoCompleteDefinition.key = [function.name toString];
                        autoCompleteDefinition.type = @"";
                        autoCompleteDefinition.string = [function.name toString];
                        autoCompleteDefinition.title = [function.name toString];
                        autoCompleteDefinition.description = nil;
                        autoCompleteDefinition.markers = nil;
                        [autoCompleteDefinitions addObject:autoCompleteDefinition];
                    }*/
                    
                    tokenClass = tokenClass.parent;
                }
            }
            
            if([autoCompleteDefinitions count] > 0) {
                autoCompleteWordRange = NSMakeRange(startIndex+2, 0);
                settingAutoComplete = YES;
            }
            
            NSLog(@"Type: %@", variableToken.variable.type.name);
        }
        else {
            
        }
        
    }
}

- (void)updateCurrentAutoCompleteDefinitions {
    [currentAutoCompleteDefinitions removeAllObjects];
    
    NSFont *font = [[NSFontManager sharedFontManager]
                    fontWithFamily:@"Menlo"
                    traits:0
                    weight:0
                    size:11];
    
    NSDictionary *sizeAttribute = @{NSFontAttributeName : font};
    
    CGFloat largestTypeWidth = 0;
    CGFloat largestStringWidth = 200;
    
    if(autoCompleteWordRange.length && autoCompleteWordRange.location+autoCompleteWordRange.length <= [[self string] length]) {
        NSString *string = [[self string] substringWithRange:autoCompleteWordRange];
        
        for(LXAutoCompleteDefinition *definition in autoCompleteDefinitions) {
            NSString *autoCompleteKey = definition.key;
            
            if([string isEqualToString:@""] || [autoCompleteKey hasPrefix:string]) {
                [currentAutoCompleteDefinitions addObject:definition];
                
                CGFloat sizeOfString = [definition.string sizeWithAttributes:sizeAttribute].width + 6;
                
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
    
    [currentAutoCompleteDefinitions sortUsingComparator:^NSComparisonResult(LXAutoCompleteDefinition *obj1, LXAutoCompleteDefinition *obj2) {
        return [obj1.key compare:obj2.key options:NSCaseInsensitiveSearch];
    }];
    
    CGFloat windowHeight = [currentAutoCompleteDefinitions count] *(autoCompleteTableView.rowHeight + 2);
    if(windowHeight > 150) {
        windowHeight = 150;
    }
    
    windowHeight += 20;
    
    if([currentAutoCompleteDefinitions count] == 0) {
        [self hideAutoCompleteWindow];
    }
    else {
        [self showAutoCompleteWindow];
    }
    
    [[autoCompleteTableView tableColumnWithIdentifier:@"Column1"] setWidth:largestTypeWidth];
    [[autoCompleteTableView tableColumnWithIdentifier:@"Column2"] setWidth:largestStringWidth];
    
    [autoCompleteTableView reloadData];
    [self tableViewSelectionDidChange:nil];
    
    NSRect rect = [self.layoutManager boundingRectForGlyphRange:autoCompleteWordRange inTextContainer:self.textContainer];
    rect.origin.x -= 3;
    NSRect windowRect = [self convertRect:rect toView:nil];
    NSRect screenRect = [[self window] convertRectToScreen:windowRect];
    
    CGFloat width = [autoCompleteTableView tableColumnWithIdentifier:@"Column1"].width + 3;
    
    [window setFrame:NSMakeRect(screenRect.origin.x - width, screenRect.origin.y - windowHeight, largestStringWidth, windowHeight) display:YES];
    [autoCompleteScrollView setFrame:NSMakeRect(0, 20, largestTypeWidth + largestStringWidth, windowHeight - 20)];
    [autoCompleteDescriptionView setFrame:NSMakeRect(0, 5, largestTypeWidth + largestStringWidth, 15)];
}

- (BOOL)shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString {
    return [self shouldChangeTextInRange:affectedCharRange replacementString:replacementString undo:YES];
}

- (BOOL)shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString undo:(BOOL)undo {
    settingAutoCompleteRange = YES;
    
    if(insertAutoComplete) {
        insertAutoComplete = NO;

        [self shouldChangeTextInRange:autoCompleteRange replacementString:@"" undo:NO];
        autoCompleteRange = NSMakeRange(0, 0);
        
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
                
    NSMutableArray *newMarkers = [NSMutableArray arrayWithCapacity:[autoCompleteMarkers count]];
    
    if(undo) {
        [self updateAutoComplete:affectedCharRange replacementString:replacementString];
    }
    
    if(NO && undo && [replacementString length] == 1 && [[replacementString stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] length] == 1) {
        {
            NSCharacterSet *charSet = [NSCharacterSet alphanumericCharacterSet];
            NSInteger startIndex = affectedCharRange.location-1;
            char ch = [replacementString characterAtIndex:0];
            
            if([charSet characterIsMember:ch]) {
                while(startIndex >= 0) {
                    ch = [[self string] characterAtIndex:startIndex];
                    
                    if(![charSet characterIsMember:ch])
                        break;
                    
                    startIndex--;
                }
            }
            
            NSString *string = [NSString stringWithFormat:@"%@%@", [[self string] substringWithRange:NSMakeRange(startIndex+1, affectedCharRange.location-(startIndex+1))], replacementString];
            
            autoCompleteWordRange = NSMakeRange(startIndex+1, (affectedCharRange.location-(startIndex+1))+[replacementString length]);
            
            NSFont *font = [[NSFontManager sharedFontManager]
                            fontWithFamily:@"Menlo"
                            traits:0
                            weight:0
                            size:11];
            
            NSDictionary *sizeAttribute = @{NSFontAttributeName : font};
            
            CGFloat largestTypeWidth = 0;
            CGFloat largestStringWidth = 200;
            
            NSMutableArray *allDefinitions = nil;
            
            LXToken *previousToken = [self tokenBeforeRange:NSMakeRange(startIndex+1, 0)];
            LXToken *variableToken = nil;

            if([replacementString isEqualToString:@"."] ||
               [replacementString isEqualToString:@":"]) {
                autoCompleteWordRange = NSMakeRange(autoCompleteWordRange.location+1, 0);
                string = @"";
                variableToken = previousToken;
            }
            else if(previousToken.type == '.' ||
                    previousToken.type == ':') {
                variableToken = [self tokenBeforeRange:previousToken.range];
            }
            
            if(variableToken.variable.type.isDefined) {
                allDefinitions = [NSMutableArray array];
                
                LXClass *tokenClass = variableToken.variable.type;
                
                while(tokenClass) {
                    for(LXVariable *variable in tokenClass.variables) {
                        LXAutoCompleteDefinition *autoCompleteDefinition = [[LXAutoCompleteDefinition alloc] init];
                        
                        autoCompleteDefinition.key = variable.name;
                        autoCompleteDefinition.type = variable.type.name ? variable.type.name : @"(Undefined)";
                        autoCompleteDefinition.string = variable.name;
                        autoCompleteDefinition.title = variable.name;
                        autoCompleteDefinition.description = nil;
                        autoCompleteDefinition.markers = nil;
                        [allDefinitions addObject:autoCompleteDefinition];
                    }
                    
                    /*for(LXNodeFunctionExpression *function in tokenClass.functions) {
                        LXAutoCompleteDefinition *autoCompleteDefinition = [[LXAutoCompleteDefinition alloc] init];
                        
                        autoCompleteDefinition.key = [function.name toString];
                        autoCompleteDefinition.type = @"";
                        autoCompleteDefinition.string = [function.name toString];
                        autoCompleteDefinition.title = [function.name toString];
                        autoCompleteDefinition.description = nil;
                        autoCompleteDefinition.markers = nil;
                        [allDefinitions addObject:autoCompleteDefinition];
                    }*/
                    
                    tokenClass = tokenClass.parent;
                }
            }
            else {
                allDefinitions = [NSMutableArray array];
                
                LXScope *scope = [self scopeAtLocation:affectedCharRange.location];

                while(scope) {
                    for(LXVariable *variable in scope.localVariables) {
                        BOOL found = NO;
                        
                        for(LXAutoCompleteDefinition *definition in allDefinitions) {
                            if([definition.key isEqualToString:variable.name]) {
                                found = YES;
                                break;
                            }
                        }
                        
                        if(found)
                            continue;
                        
                        LXAutoCompleteDefinition *autoCompleteDefinition = [[LXAutoCompleteDefinition alloc] init];
                    
                        autoCompleteDefinition.key = variable.name;
                        autoCompleteDefinition.type = variable.type.name ? variable.type.name : @"(Undefined)";
                        autoCompleteDefinition.string = variable.name;
                        autoCompleteDefinition.title = variable.name;
                        autoCompleteDefinition.description = nil;
                        autoCompleteDefinition.markers = nil;
                        [allDefinitions addObject:autoCompleteDefinition];
                    }
                    
                    scope = scope.parent;
                }
                
                for(LXAutoCompleteDefinition *definition in autoCompleteDefinitions) {
                    BOOL found = NO;
                    
                    for(LXAutoCompleteDefinition *otherDefinition in allDefinitions) {
                        if([otherDefinition.key isEqualToString:definition.key]) {
                            found = YES;
                            break;
                        }
                    }
                    
                    if(found)
                        continue;
                    
                    [allDefinitions addObject:definition];
                }
            }
            
            for(LXAutoCompleteDefinition *definition in allDefinitions) {
                NSString *autoCompleteKey = definition.key;
                
                if([string isEqualToString:@""] || [autoCompleteKey hasPrefix:string]) {
                    [currentAutoCompleteDefinitions addObject:definition];
                    
                    CGFloat sizeOfString = [definition.string sizeWithAttributes:sizeAttribute].width + 6;
                    
                    if(sizeOfString > largestStringWidth) {
                        largestStringWidth = sizeOfString;
                    }
                    
                    sizeOfString = [definition.type sizeWithAttributes:sizeAttribute].width + 6;
                    
                    if(sizeOfString > largestTypeWidth) {
                        largestTypeWidth = sizeOfString;
                    }
                }
            }
            
            CGFloat windowHeight = [currentAutoCompleteDefinitions count] *(autoCompleteTableView.rowHeight + 2);
            if(windowHeight > 150) {
                windowHeight = 150;
            }
            
            windowHeight += 20;
            
            [[autoCompleteTableView tableColumnWithIdentifier:@"Column1"] setWidth:largestTypeWidth];
            [[autoCompleteTableView tableColumnWithIdentifier:@"Column2"] setWidth:largestStringWidth];

            [window setFrame:NSMakeRect(window.frame.origin.x, window.frame.origin.y, largestStringWidth, windowHeight) display:NO];
            [autoCompleteScrollView setFrame:NSMakeRect(0, 20, largestTypeWidth + largestStringWidth, windowHeight - 20)];
            [autoCompleteDescriptionView setFrame:NSMakeRect(0, 5, largestTypeWidth + largestStringWidth, 15)];
        }
    }
    
    [self replaceCharactersInRange:affectedCharRange withString:replacementString];
    
    [self.layoutManager removeTemporaryAttribute:NSForegroundColorAttributeName forCharacterRange:NSMakeRange(0, [self.string length])];
    [self.layoutManager removeTemporaryAttribute:NSBackgroundColorAttributeName forCharacterRange:NSMakeRange(0, [self.string length])];
    
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
    [self setNeedsDisplay:YES];

    settingAutoCompleteRange = NO;
    
    if(undo) {
        [self updateCurrentAutoCompleteDefinitions];
    }
        
    return NO;
}

- (NSUndoManager *)undoManagerForTextView:(NSTextView *)view {
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
            [self.layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:[NSColor whiteColor] forCharacterRange:marker.rangeValue];
        }
        else {
            [self.layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:[NSColor blackColor] forCharacterRange:marker.rangeValue];
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
            NSFont *font = [[NSFontManager sharedFontManager]
                            fontWithFamily:@"Menlo"
                            traits:NSBoldFontMask
                            weight:0
                            size:11];
            
            NSShadow *shadow = [[NSShadow alloc] init];
            [shadow setShadowBlurRadius:0];
            [shadow setShadowColor:[NSColor blackColor]];
            [shadow setShadowOffset:CGSizeMake(0, -1.0f)];
            
            return [[NSAttributedString alloc] initWithString:definition.type attributes:@{NSForegroundColorAttributeName : [NSColor whiteColor], NSFontAttributeName : font, NSShadowAttributeName : shadow, NSParagraphStyleAttributeName : paragraphStyle}];
        }
        else {
            return [[NSAttributedString alloc] initWithString:definition.type attributes:@{NSForegroundColorAttributeName : [NSColor blueColor], NSParagraphStyleAttributeName : paragraphStyle}];
        }
    }
    else {
        if(selected) {
            NSFont *font = [[NSFontManager sharedFontManager]
                            fontWithFamily:@"Menlo"
                            traits:NSBoldFontMask
                            weight:0
                            size:11];
            
            NSShadow *shadow = [[NSShadow alloc] init];
            [shadow setShadowBlurRadius:0];
            [shadow setShadowColor:[NSColor blackColor]];
            [shadow setShadowOffset:CGSizeMake(0, -1.0f)];
            
            return [[NSAttributedString alloc] initWithString:definition.string attributes:@{NSForegroundColorAttributeName : [NSColor whiteColor], NSFontAttributeName : font, NSShadowAttributeName : shadow}];
        }
        else {
            return [[NSAttributedString alloc] initWithString:definition.string attributes:@{NSForegroundColorAttributeName : [NSColor blackColor]}];
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
        
        [self.layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:[NSColor colorWithDeviceWhite:0.0 alpha:0.5] forCharacterRange:autoCompleteRange];
        
        [self setSelectedRange:NSMakeRange(autoCompleteRange.location, 0)];
        
        insertAutoComplete = YES;
        
        if(definition.description) {
            autoCompleteDescriptionView.stringValue = definition.description;
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
        
        autoCompleteRange = NSMakeRange(0, 0);
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
        [self shouldChangeTextInRange:autoCompleteRange replacementString:@"" undo:NO];
        autoCompleteRange = NSMakeRange(0, 0);
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
	
	if ([self selectedRange].length > 0) { 
		NSRange rangeOfFirstLine = [[self string] lineRangeForRange:NSMakeRange([self selectedRange].location, 0)];
		NSInteger firstCharacterOfFirstLine = rangeOfFirstLine.location;
		while ([[self string] characterAtIndex:firstCharacterOfFirstLine] == ' ' || [[self string] characterAtIndex:firstCharacterOfFirstLine] == '\t') {
			firstCharacterOfFirstLine++;
		}
		
		if ([self selectedRange].location <= firstCharacterOfFirstLine) {
			shouldShiftText = YES;
		}
	}
	
	if (shouldShiftText) {
		//[[SMLTextMenuController sharedInstance] shiftRightAction:nil];
	}
	else {
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
	while (numberOfSpaces--) {
		[sizeString appendString:@" "];
	}
    
    NSFont *font = [[NSFontManager sharedFontManager]
                    fontWithFamily:@"Menlo"
                    traits:0
                    weight:0
                    size:11];
    
	NSDictionary *sizeAttribute = @{NSFontAttributeName : font};
	CGFloat sizeOfTab = [sizeString sizeWithAttributes:sizeAttribute].width;
	
	NSMutableParagraphStyle *style = [[NSParagraphStyle defaultParagraphStyle] mutableCopy];
	
	NSArray *array = [style tabStops];
	for (id item in array) {
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

- (void)drawViewBackgroundInRect:(NSRect)rect {
    [super drawViewBackgroundInRect:rect];
	
    NSUInteger rectCount;
    NSRectArray rects = [[self layoutManager] rectArrayForCharacterRange:[self selectedRange] withinSelectedCharacterRange:NSMakeRange(NSNotFound, 0) inTextContainer:[self textContainer] rectCount:&rectCount];
    
    [[NSColor colorWithDeviceRed:0.7 green:0.835 blue:1.0 alpha:1.0] set];

    for(NSUInteger i = 0; i < rectCount; ++i) {
        NSRect rect = rects[i];
        
        [NSBezierPath fillRect:rect];
    }
    
    for(LXCompilerError *error in self.document.context.errors) {
        NSRange range = error.range;
        
        NSRect rangeRect = [[self layoutManager] boundingRectForGlyphRange:range inTextContainer:[self textContainer]];
        NSBezierPath *path = [NSBezierPath bezierPath];
        [path moveToPoint:NSMakePoint(rangeRect.origin.x, NSMaxY(rangeRect))];
        [path lineToPoint:NSMakePoint(rangeRect.origin.x+2, NSMaxY(rangeRect)+2)];
        [path lineToPoint:NSMakePoint(rangeRect.origin.x-2, NSMaxY(rangeRect)+2)];
        [path closePath];
        [[NSColor colorWithDeviceRed:0.8 green:0.0 blue:0.0 alpha:1.0] set];
        [path fill];
    }
    
    for(NSValue *value in autoCompleteMarkers) {
        NSRange range = [value rangeValue];
        
        NSRect rangeRect = [[self layoutManager] boundingRectForGlyphRange:range inTextContainer:[self textContainer]];
        rangeRect = NSInsetRect(rangeRect, -3, 0);
        
        if(NSIntersectsRect(rect, rangeRect)) {
            NSRange intersection = NSIntersectionRange(range, [self selectedRange]);
            
            NSBezierPath *path = [NSBezierPath bezierPathWithRoundedRect:rangeRect xRadius:8 yRadius:8];
                        
            if(intersection.length > 0) {
                [[NSColor colorWithDeviceRed:0.6 green:0.6 blue:1.0 alpha:1.0] set];
                [path fill];
            }
            else {
                [[NSColor colorWithDeviceRed:0.9 green:0.9 blue:1.0 alpha:1.0] set];
                [path fill];
                [[NSColor colorWithDeviceRed:0.8 green:0.8 blue:1.0 alpha:1.0] set];
                [path stroke];
            }
           
        }
    }
    
    if(highlightedLine == -1)
        return;
    
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

- (BOOL)resignFirstResponder {
    if (![super resignFirstResponder]) {
        return NO;
    } else {
        [self setSelectedRange:NSMakeRange(NSNotFound, 0)];
        return YES;
    }
}

- (NSString *)stringForLine:(int)line {
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

- (void)scrollToLine:(int)line {
    NSInteger lineNumber;
	NSInteger index;
	NSString *completeString = [self string];
	NSInteger completeStringLength = [completeString length];
	NSInteger numberOfLinesInDocument;
	for (index = 0, numberOfLinesInDocument = 1; index < completeStringLength; numberOfLinesInDocument++) {
		index = NSMaxRange([completeString lineRangeForRange:NSMakeRange(index, 0)]);
	}
    
	if (line > numberOfLinesInDocument) {
		NSBeep();
		return;
	}
	
	for (index = 0, lineNumber = 1; lineNumber < line; lineNumber++) {
		index = NSMaxRange([completeString lineRangeForRange:NSMakeRange(index, 0)]);
	}
	
	[self scrollRangeToVisible:[completeString lineRangeForRange:NSMakeRange(index, 0)]];
}

- (void)setHighlightedLine:(int)line {
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
	for (index = 0, numberOfLinesInDocument = 1; index < completeStringLength; numberOfLinesInDocument++) {
		index = NSMaxRange([completeString lineRangeForRange:NSMakeRange(index, 0)]);
	}
	if (highlightedLine > numberOfLinesInDocument) {
		NSBeep();
		return;
	}
	
	for (index = 0, lineNumber = 1; lineNumber < highlightedLine; lineNumber++) {
		index = NSMaxRange([completeString lineRangeForRange:NSMakeRange(index, 0)]);
	}
	
	[self scrollRangeToVisible:[completeString lineRangeForRange:NSMakeRange(index, 0)]];
}

- (void)setHighlightedLineColor:(NSColor *)color background:(NSColor *)background {	
	highlightedLineColor = [color copy];
	highlightedLineBackgroundColor = [background copy];
}

@end
