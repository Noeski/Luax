//
//  ConsoleWindowController.m
//  NewGame
//
//  Created by Noah Hilt on 3/12/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import "ConsoleWindowController.h"

@implementation BlockingView

- (BOOL)acceptsFirstResponder {
    return YES;
}

- (BOOL)acceptsFirstMouse:(NSEvent *)event {
    return YES;
}

- (BOOL)acceptsTouchEvents {
    return YES;
}

- (void)mouseDown:(NSEvent *)event {
    
}

- (void)touchesBeganWithEvent:(NSEvent *)event {
    
}

@end

@implementation GradientView

- (void)dealloc {
    [_gradient release];
    [_topBorderColor release];
    [_bottomBorderColor release];
    
    [super dealloc];
}

- (void)drawRect:(NSRect)rect {
    [self.gradient drawInRect:[self bounds] angle:270];
    
    if(self.topBorderColor) {
        NSBezierPath *path = [NSBezierPath bezierPath];
        [path moveToPoint:NSMakePoint(0, self.bounds.size.height)];
        [path lineToPoint:NSMakePoint(self.bounds.size.width, self.bounds.size.height)];
        [self.topBorderColor set];
        [path stroke];
    }
    
    if(self.bottomBorderColor) {
        NSBezierPath *path = [NSBezierPath bezierPath];
        [path moveToPoint:NSMakePoint(0, 0)];
        [path lineToPoint:NSMakePoint(self.bounds.size.width, 0)];
        [self.bottomBorderColor set];
        [path stroke];
    }
}

@end

@implementation LuaCallStackIndex

- (id)init {
	if(self = [super init]) {
	}
	
	return self;
}

- (void)dealloc {
	[_source release];
	[_function release];
    [_localVariables release];
    [_upVariables release];
    
	[super dealloc];
}

@end

@implementation LuaVariable

- (id)init {
	if(self = [super init]) {
        _type = LuaVariableTypeNil;
	}
	
	return self;
}

- (id)copyWithZone:(NSZone *)zone {
    LuaVariable *copy = [[self class] allocWithZone:zone];
    copy->_type = self.type;
    copy->_key = [self.key copyWithZone:zone];
    copy->_value = [self.value copyWithZone:zone];
    
    return copy;
}

- (void)dealloc {
    [_key release];
	[_value release];
	[_children release];
    
	[super dealloc];
}

- (void)setChildren:(NSArray *)children {
    [_children release];
    _children = [children retain];
    
    for(LuaVariable* child in _children) {
        child.parent = self;
    }
}

- (BOOL)isTemporary {
    return [self.key isEqualToString:@"(*temporary)"];
}

@end

@implementation ImageAndTextCell

- (void)dealloc {
	[image release];
	[highlightImage release];
	image = nil;
	highlightImage = nil;
	[super dealloc];	
}

- (id)copyWithZone:(NSZone *)zone {
	ImageAndTextCell *cell = (ImageAndTextCell *)[super copyWithZone:zone];
	
	cell->image = [image retain];
	cell->highlightImage = [highlightImage retain];

	return cell;
}

- (void)setModified:(BOOL)modified {
	isModified = modified;
}

- (BOOL)isModified {
	return isModified;
}

- (void)setImage:(NSImage *)anImage{
	if (anImage != image) {
		[image release];
		[highlightImage release];
		
		image = [anImage retain];
		
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

- (NSImage *)image {
	return image;
}

- (NSRect)imageFrameForCellFrame:(NSRect)cellFrame {
	if (image != nil) {
		NSRect imageFrame;
		
		imageFrame.size = [image size];
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
	
	NSDivideRect (aRect, &imageFrame, &textFrame, 3 + [image size].width, NSMinXEdge);
	
	[super editWithFrame: textFrame inView: controlView editor:textObj delegate:anObject event: theEvent];
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength {
	NSRect textFrame, imageFrame;
	
	NSDivideRect (aRect, &imageFrame, &textFrame, 3 + [image size].width, NSMinXEdge);
	
	[super selectWithFrame: textFrame inView: controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
	if(image != nil) {
		NSSize  imageSize;
		
		NSRect  imageFrame;
		
		imageSize = [image size];
		
		NSDivideRect(cellFrame, &imageFrame, &cellFrame, 3 + imageSize.width, NSMinXEdge);
		
		if ([self drawsBackground]) {
			[[self backgroundColor] set];
			
			NSRectFill(imageFrame);
		}
		
		imageFrame.origin.x += 3;
		imageFrame.size = imageSize;
		
		if(isModified) {
            [highlightImage drawInRect:imageFrame fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0 respectFlipped:YES hints:nil];
		}
		else {
            [image drawInRect:imageFrame fromRect:NSZeroRect operation:NSCompositeSourceOver fraction:1.0 respectFlipped:YES hints:nil];
		}
	}
	
	[super drawWithFrame:cellFrame inView:controlView];
}

- (NSSize)cellSize {
	NSSize cellSize = [super cellSize];
	
	cellSize.width += (image ? [image size].width : 0) + 3;
	
	return cellSize;
}

@end

@implementation VariableCell

- (id)init {
    if(self = [super init]) {
    }
    
    return self;
}

- (void)dealloc {
    [name release];
    [type release];
    [value release];
    
	[super dealloc];
}

- (id)copyWithZone:(NSZone *)zone {
	VariableCell *cell = (VariableCell *)[super copyWithZone:zone];
	
	cell->name = [name copyWithZone:zone];
    cell->type = [type copyWithZone:zone];
    cell->value = [value copyWithZone:zone];
    
	return cell;
}

- (NSString *)stringFromVariable:(LuaVariable *)var {
    switch(var.type) {
        case LuaVariableTypeBoolean:
        case LuaVariableTypeNumber:
            return [var.value stringValue];
        case LuaVariableTypeVector2:
        case LuaVariableTypeVector3:
        case LuaVariableTypeString:
            return var.value;
        case LuaVariableTypeTable:
        case LuaVariableTypeFunction:
        case LuaVariableTypeUserdata:
        case LuaVariableTypeThread:
        case LuaVariableTypeLightuserdata:
            return [NSString stringWithFormat:@"0x%02x", [var.value intValue]];
        default:
        case LuaVariableTypeNil:
            return @"nil";
    }
}

- (NSString *)stringFromVariableType:(LuaVariable *)var {
    switch(var.type) {
        case LuaVariableTypeBoolean:
            return @" = (bool) ";
        case LuaVariableTypeNumber:
            return @" = (number) ";
        case LuaVariableTypeVector2:
            return @" = (vector2) ";
        case LuaVariableTypeVector3:
            return @" = (vector3) ";
        case LuaVariableTypeString:
            return @" = (string) ";
        case LuaVariableTypeTable:
            return @" = (table) ";
        case LuaVariableTypeFunction:
            return @" = (function) ";
        case LuaVariableTypeUserdata:
            return @" = (userdata) ";
        case LuaVariableTypeThread:
            return @" = (thread) ";
        case LuaVariableTypeLightuserdata:
            return @" = (lightuserdata) ";
        default:
        case LuaVariableTypeNil:
            return @" = (nil) ";
    }
}

- (void)setObjectValue:(NSObject<NSCopying> *)obj {
    nameWidth = 0;
    
    if([obj isKindOfClass:[LuaVariable class]]) {
        LuaVariable *var = (LuaVariable *)obj;
        
        [name release];
        [type release];
        [value release];
        
        if(var.scope == LuaVariableScopeLocal) {
            name = [[NSString stringWithFormat:@"[L]%@", var.key] retain];
        }
        else if(var.scope == LuaVariableScopeUpvalue) {
            name = [[NSString stringWithFormat:@"[U]%@", var.key] retain];
        }
        else if(var.scope == LuaVariableScopeGlobal) {
            name = [[NSString stringWithFormat:@"[G]%@", var.key] retain];
        }
        else {
            name = [var.key copy];
        }
        
        type = [[self stringFromVariableType:var] retain];
        value = [[self stringFromVariable:var] retain];
        
        nameWidth += [name sizeWithAttributes:@{NSFontAttributeName : [NSFont boldSystemFontOfSize:12]}].width;
        nameWidth += [type sizeWithAttributes:@{NSFontAttributeName : [NSFont systemFontOfSize:12]}].width;

        [super setObjectValue:value];
    }
    else {
        [super setObjectValue:obj];
    }
}

- (void)editWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject event:(NSEvent *)theEvent {
    aRect.origin.x += nameWidth;
    aRect.size.width -= nameWidth;

	[super editWithFrame: aRect inView:controlView editor:textObj delegate:anObject event: theEvent];
}

- (void)selectWithFrame:(NSRect)aRect inView:(NSView *)controlView editor:(NSText *)textObj delegate:(id)anObject start:(NSInteger)selStart length:(NSInteger)selLength {
	aRect.origin.x += nameWidth;
    aRect.size.width -= nameWidth;
    
	[super selectWithFrame: aRect inView:controlView editor:textObj delegate:anObject start:selStart length:selLength];
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    BOOL highlighted = NO;

    if(self.isHighlighted) {
       highlighted = YES;
        
        if([[[controlView window] firstResponder] isKindOfClass:[NSView class]]) {
            NSView *view = (NSView *)[[controlView window] firstResponder];
            
            if(![view isDescendantOf:controlView]) {
                highlighted = NO;
            }
        }
    }
    
    NSPoint origin = cellFrame.origin;
    
    NSDictionary *nameAttrs = @{NSForegroundColorAttributeName : highlighted ? [NSColor whiteColor] : [NSColor blackColor], NSFontAttributeName : [NSFont boldSystemFontOfSize:12]};
    NSDictionary *typeAttrs = @{NSForegroundColorAttributeName : highlighted ? [NSColor whiteColor] : [NSColor blackColor], NSFontAttributeName : [NSFont systemFontOfSize:12]};
   
    [name drawAtPoint:origin withAttributes:nameAttrs];
    origin.x += [name sizeWithAttributes:nameAttrs].width;
    [type drawAtPoint:origin withAttributes:typeAttrs];
    origin.x += [type sizeWithAttributes:typeAttrs].width;
    
    cellFrame.origin.x += nameWidth;
    cellFrame.size.width -= nameWidth;
    
	[super drawWithFrame:cellFrame inView:controlView];
}

- (NSSize)cellSize {
	NSSize cellSize = [super cellSize];
	
	cellSize.width -= nameWidth;
    
	return cellSize;
}

@end

@implementation BreakpointCellValue

- (id)initWithScriptName:(NSString *)name {
    if(self = [super init]) {
        _scriptName = [name retain];
    }
    
    return self;
}

- (id)initWithPreviewString:(NSString *)preview lineString:(NSString *)line {
    if(self = [super init]) {
        _previewString = [preview retain];
        _lineString = [line retain];
    }
    
    return self;
}

- (id)copyWithZone:(NSZone *)zone {
    BreakpointCellValue *copy = [[self class] allocWithZone:zone];
    copy->_scriptName = [self.scriptName copyWithZone:zone];
    copy->_previewString = [self.previewString copyWithZone:zone];
    copy->_lineString = [self.lineString copyWithZone:zone];
    
    return copy;
}

- (void)dealloc {
    [_scriptName release];
	[_previewString release];
	[_lineString release];
    
	[super dealloc];
}

@end

@implementation BreakpointCell

- (id)copyWithZone:(NSZone *)zone {
	BreakpointCell *cell = (BreakpointCell *)[super copyWithZone:zone];
	
	cell->_value = [_value copyWithZone:zone];
    
	return cell;
}

- (void)dealloc {
    [_value release];
    
    [super dealloc];
}

- (void)setObjectValue:(NSObject<NSCopying> *)obj {
    if([obj isKindOfClass:[BreakpointCellValue class]]) {
        BreakpointCellValue *value = (BreakpointCellValue *)obj;
        
        self.value = value;
    }
    else {
        self.value = nil;
        
        [super setObjectValue:obj];
    }    
}

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView {
    BOOL highlighted = NO;
    
    if(self.isHighlighted) {
        highlighted = YES;
        
        if([[[controlView window] firstResponder] isKindOfClass:[NSView class]]) {
            NSView *view = (NSView *)[[controlView window] firstResponder];
            
            if(![view isDescendantOf:controlView]) {
                highlighted = NO;
            }
        }
    }
    
    NSPoint origin = cellFrame.origin;
    
    if(self.value.scriptName != nil) {
        NSDictionary *nameAttrs = @{NSForegroundColorAttributeName : highlighted ? [NSColor whiteColor] : [NSColor blackColor], NSFontAttributeName : [NSFont systemFontOfSize:12]};
        
        [self.value.scriptName drawWithRect:cellFrame options:NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesLineFragmentOrigin attributes:nameAttrs];
    }
    else {
        NSDictionary *previewAttrs = @{NSForegroundColorAttributeName : highlighted ? [NSColor whiteColor] : [NSColor blackColor], NSFontAttributeName : [NSFont systemFontOfSize:12]};
        NSDictionary *lineAttrs = @{NSForegroundColorAttributeName : highlighted ? [NSColor whiteColor] : [NSColor lightGrayColor], NSFontAttributeName : [NSFont systemFontOfSize:12]};

        [self.value.previewString drawWithRect:NSMakeRect(origin.x, origin.y, cellFrame.size.width-64, 24) options:NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesLineFragmentOrigin attributes:previewAttrs];
        
        [self.value.lineString drawWithRect:NSMakeRect(origin.x+(cellFrame.size.width-64), origin.y, 64, 24) options:NSStringDrawingTruncatesLastVisibleLine | NSStringDrawingUsesLineFragmentOrigin attributes:lineAttrs];
    }
}

@end

@interface ConsoleWindowController()

@property (nonatomic) BOOL readingHeader;
@property (nonatomic) NSInteger headerReceivedBytes;
@property (nonatomic) int pendingPacketSize;
@property (nonatomic) NSInteger packetReceivedBytes;
@property (nonatomic, retain) NSMutableData *pendingData;
@property (nonatomic, retain) NSMutableData *writeBuffer;
@property (nonatomic, retain) NSArray *callStack;
@property (nonatomic, retain) NSArray *localVariables;
@property (nonatomic, retain) LuaVariable *globalTable;
@property (nonatomic, retain) NSArray *lastCallStack;
@property (nonatomic, retain) LuaVariable *lastGlobalTable;
@property (nonatomic, retain) NSMutableDictionary *tablesDictionary;

@end

@implementation ConsoleWindowController

- (id)initWithWindowNibName:(NSString *)windowNibName {
    if(self = [super initWithWindowNibName:windowNibName]) {
        self.pendingData = [NSMutableData data];
        self.writeBuffer = [NSMutableData data];
        
        socket = [[ClientSocket alloc] init];
        socket.delegate = self;
        showLocals = YES;
        currentScriptIndex = -1;
        scriptEditObjects = [[NSMutableArray alloc] init];
        breakpointsDictionary = [[NSMutableDictionary alloc] init];
        consoleString = [[NSMutableAttributedString alloc] init];
    }
    
    return self;
}

- (void)performInsertFirstDocument:(ScriptDocument*)document {		
	[documentView setSubviews:[NSArray array]];
	[documentView addSubview:document.textScrollView];
	[documentView addSubview:document.gutterScrollView];
	
	[document resizeViewsForSuperView:documentView];
	[document updateLineNumbersForClipView:[document.textScrollView contentView] recolour:YES];
}

- (void)windowDidLoad {
    serverSocket = [[ServerSocket alloc] init];
    serverSocket.delegate = self;
    [serverSocket listen:3633];
    
    NSFont *font = [[NSFontManager sharedFontManager] fontWithFamily:@"Menlo"
                                        traits:0
                                        weight:0
                                          size:11];
    
	[consoleInputField setFont:font];

	NSMenu *menu = [[NSMenu alloc] init];
	[menu setAutoenablesItems:NO];
	
	saveItem = [[NSMenuItem alloc] init];
	[saveItem setTitle:@"Save"];
	[saveItem setTarget:self];
	[saveItem setAction:@selector(saveSelectedScript)];
	[menu addItem:saveItem];
	
	startItem = [[NSMenuItem alloc] init];
	[startItem setTitle:@"Start"];
	[startItem setTarget:self];
	[startItem setAction:@selector(startSelectedScript)];
	[menu addItem:startItem];
	
	reloadItem = [[NSMenuItem alloc] init];
	[reloadItem setTitle:@"Reload"];
	[reloadItem setTarget:self];
	[reloadItem setAction:@selector(reloadSelectedScript)];
	[menu addItem:reloadItem];
	
	/*unloadItem = [[NSMenuItem alloc] init];
	[unloadItem setTitle:@"Unload"];
	[unloadItem setTarget:self];
	[unloadItem setAction:@selector(unloadSelectedScript)];
	[menu addItem:unloadItem];*/
	
	[scriptsTableView setMenu:menu];
	
	NSTableColumn* tableColumn = [[scriptsTableView tableColumns] objectAtIndex:0];
	ImageAndTextCell* imageAndTextCell = [[[ImageAndTextCell alloc] init] autorelease];
	[imageAndTextCell setEditable:NO];
	[imageAndTextCell setImage:[NSImage imageNamed:@"scripticon.png"]];
	[tableColumn setDataCell:imageAndTextCell];
    
    tableColumn = [[localVariablesView tableColumns] objectAtIndex:0];
	VariableCell *variableCell = [[[VariableCell alloc] init] autorelease];
	[variableCell setEditable:YES];
	[tableColumn setDataCell:variableCell];
    
    tableColumn = [[breakpointsView tableColumns] objectAtIndex:0];
    
	BreakpointCell *breakpointCell = [[[BreakpointCell alloc] init] autorelease];
	[breakpointCell setEditable:NO];
	[tableColumn setDataCell:breakpointCell];
	
	[callStackView setTarget:self];
	[callStackView setDoubleAction:@selector(jumpToStack)];
    
    NSGradient *gradient = [[NSGradient alloc]
                             initWithStartingColor:[NSColor colorWithCalibratedWhite:0.9 alpha:1.0]
                             endingColor:[NSColor colorWithCalibratedWhite:0.8 alpha:1.0]];
    NSColor *borderColor = [NSColor colorWithDeviceWhite:0.5 alpha:1.0];

    scriptButtonsContainer.gradient = gradient;
    scriptButtonsContainer.bottomBorderColor = borderColor;
    topBarContainer.gradient = gradient;
    topBarContainer.bottomBorderColor = borderColor;
    stackContainer.gradient = gradient;
    stackContainer.bottomBorderColor = borderColor;
    consoleContainer.gradient = gradient;
    consoleContainer.bottomBorderColor = borderColor;
    [gradient release];
    
    gradient = [[NSGradient alloc] initWithColorsAndLocations:[NSColor colorWithCalibratedWhite:0.95 alpha:1.0], 0.0, [NSColor colorWithCalibratedWhite:0.95 alpha:1.0], 0.5, [NSColor colorWithCalibratedWhite:0.85 alpha:1.0], 0.5, [NSColor colorWithCalibratedWhite:0.85 alpha:1.0], 1.0, nil];
    stackButtonsContainer.gradient = gradient;
    stackButtonsContainer.topBorderColor = borderColor;
    [gradient release];
        
    [playButton setAction:@selector(pause:)];
    [playButton setEnabled:NO];
    [stepIntoButton setEnabled:NO];
    [stepOverButton setEnabled:NO];
    [stepOutButton setEnabled:NO];
    
    currentScrollView = self.scriptsScrollView;
    [hostTextField reloadData];
    
    NSArray *args = [[NSProcessInfo processInfo] arguments];
    
    for(NSInteger i = 0; i < [args count]; ++i) {
        NSString *arg = args[i];
        
        if([arg isEqualToString:@"launch"] && i+2 < [args count]) {
            hostTextField.stringValue = args[i+1];
            portTextField.stringValue = args[i+2];
            [self connect:nil];
            break;
        }
    }
}

- (void)dealloc {
	[scriptEditObjects release];
	
	[super dealloc];
}

- (void)sendData:(NSData *)data {
    int length = htonl((int)[data length]);
    [self.writeBuffer appendBytes:&length length:sizeof(length)];
    [self.writeBuffer appendData:data];
    
    if(self.writeBuffer.length > 0) {
        NSInteger bytesSent = [socket send:self.writeBuffer];
        
        if(bytesSent > 0) {
            [self.writeBuffer replaceBytesInRange:NSMakeRange(0, bytesSent) withBytes:NULL length:0];
        }
    }
}

- (void)socketDidConnect:(ClientSocket *)aSocket {
    connecting = NO;
    self.readingHeader = true;
    self.headerReceivedBytes = 0;
    self.packetReceivedBytes = 0;
    
    char *str = "{\"type\":\"request\",\"command\":\"scripts\"}";
    NSData *data = [NSData dataWithBytes:str length:strlen(str)+1];
    
    [self sendData:data];
    
    connectionIndicator.hidden = YES;
    [connectionIndicator stopAnimation:nil];
    connectionLabel.stringValue = @"Connected";
    
    scriptsProgressContainer.hidden = NO;
    [scriptsProgressIndicator startAnimation:nil];
    
    [connectButton setTitle:@"Disconnect"];
    [connectButton setAction:@selector(disconnect:)];
    
    [hostTextField setStringValue:socket.hostAddress];
    [portTextField setStringValue:[NSString stringWithFormat:@"%d", socket.hostPort]];
    
    [playButton setEnabled:YES];
    
    NSArray *array = [[NSUserDefaults standardUserDefaults] arrayForKey:@"cachedHosts"];
    NSMutableArray *mutableArray = nil;
    
    if(array) {
        mutableArray = [NSMutableArray arrayWithArray:array];
    }
    else {
        mutableArray = [NSMutableArray array];
    }
    
    BOOL found = NO;
    for(NSDictionary *dictionary in array) {
        if([[dictionary objectForKey:@"host"] isEqualToString:socket.hostAddress] && [[dictionary objectForKey:@"port"] unsignedShortValue] == socket.hostPort) {
            found = YES;
            break;
        }
    }
    
    
    if(!found) {
        [mutableArray addObject:@{@"host" : socket.hostAddress, @"port" : @(socket.hostPort)}];
        
        if([mutableArray count] >= 5) {
            [mutableArray removeObjectsInRange:NSMakeRange(0, [mutableArray count]-5)];
        }
        
        [[NSUserDefaults standardUserDefaults] setObject:mutableArray forKey:@"cachedHosts"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [hostTextField reloadData];
    }
}

- (void)socket:(ClientSocket *)socket willCloseWithError:(NSError *)error {    
    if(connecting) {
        connecting = NO;
        
        connectionIndicator.hidden = YES;
        [connectionIndicator stopAnimation:nil];
        
        connectionLabel.stringValue = @"Failed to connect!";
    }
    else {
        connectionIndicator.hidden = YES;
        [connectionIndicator stopAnimation:nil];
        
        connectionLabel.stringValue = @"Disconnected";
        
        [connectButton setTitle:@"Connect"];
        [connectButton setAction:@selector(connect:)];
    }
}

- (NSDictionary *)dictionaryWithJSONData:(NSData *)data {
    NSMutableDictionary *obj = nil;
    NSError *error = nil;
                
    obj = [NSJSONSerialization JSONObjectWithData:data
                                          options:NSJSONReadingMutableContainers
                                           error:&error];
#if DEBUG
        if (error) {
            NSString *str = [[[NSString alloc] initWithData:data
                                                   encoding:NSUTF8StringEncoding] autorelease];
            NSLog(@"NSJSONSerialization error %@ parsing %@",
                  error, str);
        }
#endif
    
    return obj;
}

- (NSInteger)socket:(ClientSocket *)socket didReceiveData:(NSData *)data {
    NSInteger totalBytesRead = 0;

    do {        
        if(self.readingHeader) {
            int headerSize = sizeof(int);
            
            char* ptr = (char*)&(_pendingPacketSize)+self.headerReceivedBytes;
            
            NSInteger bytesRead = MIN(headerSize-self.headerReceivedBytes, [data length] - totalBytesRead);
            memcpy(ptr, [data bytes]+totalBytesRead, bytesRead);
            self.headerReceivedBytes += bytesRead;
            totalBytesRead += bytesRead;
            
            if(self.headerReceivedBytes < headerSize)
                return totalBytesRead;
            
            self.readingHeader = false;
            [self.pendingData setLength:ntohl(self.pendingPacketSize)];
        }
        
        NSInteger bytesRead = MIN([self.pendingData length] - self.packetReceivedBytes, [data length] - totalBytesRead);
        memcpy([self.pendingData mutableBytes]+self.packetReceivedBytes, [data bytes]+totalBytesRead, bytesRead);
        self.packetReceivedBytes += bytesRead;
        totalBytesRead += bytesRead;
        
        if(self.packetReceivedBytes < [self.pendingData length])
            return totalBytesRead;
        
        [self processData:self.pendingData];
        
        self.readingHeader = true;
        self.headerReceivedBytes = 0;
        self.packetReceivedBytes = 0;
    } while(true);
        
    return totalBytesRead;
}

- (void)socketCanSend:(ClientSocket *)aSocket {
    if(self.writeBuffer.length > 0) {
        NSInteger bytesSent = [socket send:self.writeBuffer];
        
        if(bytesSent > 0) {
            [self.writeBuffer replaceBytesInRange:NSMakeRange(0, bytesSent) withBytes:NULL length:0];
        }
    }
}

- (void)server:(ServerSocket *)server willCloseWithError:(NSError *)error {
    NSLog(@"CLOSED");
}

- (void)server:(ServerSocket *)server clientConnected:(ClientSocket *)client {
    NSLog(@"Connected!");
    
    [socket release];
    socket = [client retain];
    socket.delegate = self;
}

- (LuaVariable *)variableFromDictionary:(NSDictionary *)dictionary {
    NSString *type = [dictionary objectForKey:@"type"];
    
    LuaVariable *variable = [[[LuaVariable alloc] init] autorelease];

    if([type isEqualToString:@"boolean"]) {
        NSNumber *value = [dictionary objectForKey:@"value"];
        variable.type = LuaVariableTypeBoolean;
        variable.value = value;
    }
    else if([type isEqualToString:@"number"]) {
        NSNumber *value = [dictionary objectForKey:@"value"];
        variable.type = LuaVariableTypeNumber;
        variable.value = value;        
    }
    else if([type isEqualToString:@"vector2"]) {
        NSString *value = [dictionary objectForKey:@"value"];
        variable.type = LuaVariableTypeVector2;
        variable.value = value;
    }
    else if([type isEqualToString:@"vector3"]) {
        NSString *value = [dictionary objectForKey:@"value"];
        variable.type = LuaVariableTypeVector3;
        variable.value = value;
    }
    else if([type isEqualToString:@"string"]) {
        NSString *value = [dictionary objectForKey:@"value"];
        variable.type = LuaVariableTypeString;
        variable.value = value;
    }
    else if([type isEqualToString:@"function"]) {
        NSNumber *value = [dictionary objectForKey:@"value"];
        variable.type = LuaVariableTypeFunction;
        variable.value = value;
    }
    else if([type isEqualToString:@"userdata"]) {
        NSNumber *value = [dictionary objectForKey:@"value"];
        variable.type = LuaVariableTypeUserdata;
        variable.value = value;
    }
    else if([type isEqualToString:@"thread"]) {
        NSNumber *value = [dictionary objectForKey:@"value"];
        variable.type = LuaVariableTypeThread;
        variable.value = value;
    }
    else if([type isEqualToString:@"lightuserdata"]) {
        NSNumber *value = [dictionary objectForKey:@"value"];
        variable.type = LuaVariableTypeLightuserdata;
        variable.value = value;
    }
    else if([type isEqualToString:@"table"]) {
        NSNumber *ptr = [dictionary objectForKey:@"value"];
        variable.type = LuaVariableTypeTable;
        variable.value = ptr;
    }
    
    return variable;
}

- (void)updateVariable:(LuaVariable *)variable fromVariable:(LuaVariable *)otherVariable {
    BOOL wasTable = variable.type == LuaVariableTypeTable;
    
    id newValue = [otherVariable.value copy];
    variable.type = otherVariable.type;
    variable.value = newValue;
    [newValue release];
    
    BOOL isTable = variable.type == LuaVariableTypeTable;
    
    if(wasTable && variable.children != nil) {
        if(isTable) {
            NSArray *children = [self.tablesDictionary objectForKey:variable.value];
            NSMutableArray *newChildren = [NSMutableArray arrayWithCapacity:[children count]];

            for(LuaVariable *child in children) {
                LuaVariable *newChild = nil;
                
                for(LuaVariable *variableChild in variable.children) {
                    if([variableChild.key isEqualToString:child.key]) {
                        newChild = [variableChild retain];
                        break;
                    }
                }
                
                if(newChild == nil) {
                    newChild = [child copy];
                }
                else {
                    [self updateVariable:newChild fromVariable:child]; 
                }
                
                [newChildren addObject:newChild];
                [newChild release];
            }
            
            variable.children = newChildren;

        }
        else {
            variable.children = nil;
            variable.expanded = NO;
        }
    }
}

- (void)updateVariable:(LuaVariable *)variable fromVariable:(LuaVariable *)otherVariable inTable:(LuaVariable *)table {
    if(variable.type == LuaVariableTypeTable) {
        BOOL isTable = [variable.value isEqualTo:table.value];
        
        for(LuaVariable *child in variable.children) {
            if(isTable && [child.key isEqualToString:otherVariable.key]) {
                [self updateVariable:child fromVariable:otherVariable];
                
                [localVariablesView reloadItem:child];
            }
            
            [self updateVariable:child fromVariable:otherVariable inTable:table];
        }
    }
}

- (void)updateVariables:(LuaVariable *)otherVariable inTable:(LuaVariable *)table {
    for(LuaCallStackIndex *index in self.callStack) {
        for(LuaVariable *variable in index.localVariables) {
            [self updateVariable:variable fromVariable:otherVariable inTable:table];
        }
        
        for(LuaVariable *variable in index.upVariables) {
            [self updateVariable:variable fromVariable:otherVariable inTable:table];
        }
    }
    
    [self updateVariable:self.globalTable fromVariable:otherVariable inTable:table];
}

- (void)processData:(NSData *)data {
    NSDictionary *dictionary = [self dictionaryWithJSONData:data];
    NSString *type = [dictionary objectForKey:@"type"];
    
    if([type isEqualToString:@"response"]) {
        NSString *command = [dictionary objectForKey:@"command"];
        
        if([command isEqualToString:@"scripts"]) {
            NSArray *scripts = [dictionary objectForKey:@"scripts"];
            NSMutableArray *scriptObjects = [NSMutableArray arrayWithCapacity:[scripts count]];
            for(NSDictionary *script in scripts) {
                ScriptDocument *document = [[ScriptDocument alloc] initWithContentView:documentView];
                document.delegate = self;
                document.scriptName = [script objectForKey:@"script"];
                document.textView.string = [script objectForKey:@"source"];
                [document updateLineNumbers:YES];
                int i = 0;
                for(; i < [scriptObjects count]; ++i) {
                    ScriptDocument *other = [scriptObjects objectAtIndex:i];
                    
                    if([document.scriptName compare:other.scriptName] == NSLessThanComparison) {
                        break;                        
                    }
                }
                
                [scriptObjects insertObject:document atIndex:i];
            }
            
            [scriptEditObjects release];
            scriptEditObjects = [scriptObjects retain];
            
            NSInteger row = [scriptsTableView selectedRow];
            [scriptsTableView reloadData];
            row = MIN(row, ((NSInteger)[scriptEditObjects count])-1);
            if(row >= 0) {
                [self selectTableIndex:row];
            }
            
            scriptsProgressContainer.hidden = YES;
            [scriptsProgressIndicator stopAnimation:nil];
        }
        else if([command isEqualToString:@"reloadScript"]) {
            NSString *script = [dictionary objectForKey:@"script"];
            NSNumber *error = [dictionary objectForKey:@"error"];
            
            NSAttributedString *attributedMessage = nil;
            
            NSFont *font = [[NSFontManager sharedFontManager]
                            fontWithFamily:@"Menlo"
                            traits:NSBoldFontMask
                            weight:0
                            size:11];
            
            if(error.boolValue) {
                NSString *errorMessage = [dictionary objectForKey:@"errorMessage"];
                
                NSDictionary *fontAttributes = @{NSForegroundColorAttributeName : [NSColor redColor], NSFontAttributeName : font};
                
                attributedMessage = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n", errorMessage] attributes:fontAttributes];
            }
            else {
                NSDictionary *fontAttributes = @{NSForegroundColorAttributeName : [NSColor blackColor], NSFontAttributeName : font};
                
                attributedMessage = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@ Compiled OK\n", script] attributes:fontAttributes];
            }
            
            [[consoleTextView textStorage] appendAttributedString:attributedMessage];
            [attributedMessage release];
            
            NSRange range = NSMakeRange([[consoleTextView string] length], 0);
            [consoleTextView scrollRangeToVisible: range];
        }
        else if([command isEqualToString:@"setglobal"]) {
            if(!((NSNumber *)[dictionary objectForKey:@"error"]).boolValue) {
                NSArray *tables = [dictionary objectForKey:@"tables"];
                
                for(NSDictionary *table in tables) {
                    NSNumber *ptr = [table objectForKey:@"ptr"];
                    NSArray *values = [table objectForKey:@"values"];
                    
                    NSMutableArray *tableValue = [NSMutableArray array];
                    for(NSDictionary *valueDictionary in values) {
                        NSString *key = [valueDictionary objectForKey:@"name"];
                        LuaVariable *variable = [self variableFromDictionary:valueDictionary];
                        
                        variable.key = key;
                        
                        [tableValue addObject:variable];
                    }
                    
                    NSArray *sortedTable = [tableValue sortedArrayUsingComparator:^NSComparisonResult(LuaVariable *a, LuaVariable *b) {
                        return [a.key compare:b.key];
                    }];
                    
                    [self.tablesDictionary setObject:sortedTable forKey:ptr];
                }
                
                NSArray *indices = [dictionary objectForKey:@"indices"];
                NSDictionary *value = [dictionary objectForKey:@"value"];
                            
                LuaVariable *variable = self.globalTable;
                
                if([indices count] == 0) {
                    [self updateVariable:variable fromVariable:[self variableFromDictionary:value]];
                    
                    [localVariablesView reloadItem:variable];
                }
                else {
                    LuaVariable *table = variable;
                    
                    for(NSInteger i = 0; i < ((NSInteger)[indices count])-1; ++i) {
                        NSString *key = [indices objectAtIndex:i];
                        
                        for(LuaVariable *otherVariable in table.children) {
                            if([otherVariable.key isEqualToString:key]) {
                                table = otherVariable;
                                break;
                            }
                        }
                    }
                    
                    NSArray *tableArray = [self.tablesDictionary objectForKey:table.value];
                    
                    NSString *key = [indices objectAtIndex:[indices count]-1];
                    
                    for(LuaVariable *otherVariable in tableArray) {
                        if([otherVariable.key isEqualToString:key]) {
                            variable = otherVariable;
                            break;
                        }
                    }
                    
                    [self updateVariable:variable fromVariable:[self variableFromDictionary:value]];
                    
                    [self updateVariables:variable inTable:table];
                    
                    [localVariablesView reloadItem:variable];
                }
            }
            
            stackProgressContainer.hidden = YES;
            [stackProgressIndicator stopAnimation:nil];
        }
        else if([command isEqualToString:@"setlocal"]) {
            if(!((NSNumber *)[dictionary objectForKey:@"error"]).boolValue) {
                NSArray *tables = [dictionary objectForKey:@"tables"];
                
                for(NSDictionary *table in tables) {
                    NSNumber *ptr = [table objectForKey:@"ptr"];
                    NSArray *values = [table objectForKey:@"values"];
                    
                    NSMutableArray *tableValue = [NSMutableArray array];
                    for(NSDictionary *valueDictionary in values) {
                        NSString *key = [valueDictionary objectForKey:@"name"];
                        LuaVariable *variable = [self variableFromDictionary:valueDictionary];
                        
                        variable.key = key;
                        
                        [tableValue addObject:variable];
                    }
                    
                    NSArray *sortedTable = [tableValue sortedArrayUsingComparator:^NSComparisonResult(LuaVariable *a, LuaVariable *b) {
                        return [a.key compare:b.key];
                    }];
                    
                    [self.tablesDictionary setObject:sortedTable forKey:ptr];
                }
                
                NSNumber *where = [dictionary objectForKey:@"where"];
                NSNumber *varIndex = [dictionary objectForKey:@"index"];
                NSArray *indices = [dictionary objectForKey:@"indices"];
                NSDictionary *value = [dictionary objectForKey:@"value"];

                LuaCallStackIndex *index = [self.callStack objectAtIndex:where.integerValue];
                
                LuaVariable *variable = nil;
                
                for(LuaVariable *otherVariable in index.localVariables) {
                    if(otherVariable.index == varIndex.integerValue) {
                        variable = otherVariable;
                        break;
                    }
                }
                
                if([indices count] == 0) {
                    [self updateVariable:variable fromVariable:[self variableFromDictionary:value]];
                    
                    [localVariablesView reloadItem:variable];
                }
                else {
                    LuaVariable *table = variable;
                    
                    for(NSInteger i = 0; i < ((NSInteger)[indices count])-1; ++i) {
                        NSString *key = [indices objectAtIndex:i];
                        
                        for(LuaVariable *otherVariable in table.children) {
                            if([otherVariable.key isEqualToString:key]) {
                                table = otherVariable;
                                break;
                            }
                        }
                    }
                    
                    NSArray *tableArray = [self.tablesDictionary objectForKey:table.value];
                    
                    NSString *key = [indices objectAtIndex:[indices count]-1];
                    
                    for(LuaVariable *otherVariable in tableArray) {
                        if([otherVariable.key isEqualToString:key]) {
                            variable = otherVariable;
                            break;
                        }
                    }
                    
                    [self updateVariable:variable fromVariable:[self variableFromDictionary:value]];
                    
                    [self updateVariables:variable inTable:table];
                    
                    [localVariablesView reloadItem:variable];
                }
            }
            
            stackProgressContainer.hidden = YES;
            [stackProgressIndicator stopAnimation:nil];
        }
        else if([command isEqualToString:@"setupvalue"]) {
            if(!((NSNumber *)[dictionary objectForKey:@"error"]).boolValue) {
                NSArray *tables = [dictionary objectForKey:@"tables"];
                
                for(NSDictionary *table in tables) {
                    NSNumber *ptr = [table objectForKey:@"ptr"];
                    NSArray *values = [table objectForKey:@"values"];
                    
                    NSMutableArray *tableValue = [NSMutableArray array];
                    for(NSDictionary *valueDictionary in values) {
                        NSString *key = [valueDictionary objectForKey:@"name"];
                        LuaVariable *variable = [self variableFromDictionary:valueDictionary];
                        
                        variable.key = key;
                        
                        [tableValue addObject:variable];
                    }
                    
                    NSArray *sortedTable = [tableValue sortedArrayUsingComparator:^NSComparisonResult(LuaVariable *a, LuaVariable *b) {
                        return [a.key compare:b.key];
                    }];
                    
                    [self.tablesDictionary setObject:sortedTable forKey:ptr];
                }
                
                NSNumber *where = [dictionary objectForKey:@"where"];
                NSNumber *varIndex = [dictionary objectForKey:@"index"];
                NSArray *indices = [dictionary objectForKey:@"indices"];
                NSDictionary *value = [dictionary objectForKey:@"value"];
                
                LuaCallStackIndex *index = [self.callStack objectAtIndex:where.integerValue];
                
                LuaVariable *variable = nil;
                
                for(LuaVariable *otherVariable in index.upVariables) {
                    if(otherVariable.index == varIndex.integerValue) {
                        variable = otherVariable;
                        break;
                    }
                }
                
                if([indices count] == 0) {
                    [self updateVariable:variable fromVariable:[self variableFromDictionary:value]];
                    
                    [localVariablesView reloadItem:variable];
                }
                else {
                    LuaVariable *table = variable;
                    
                    for(NSInteger i = 0; i < ((NSInteger)[indices count])-1; ++i) {
                        NSString *key = [indices objectAtIndex:i];
                        
                        for(LuaVariable *otherVariable in table.children) {
                            if([otherVariable.key isEqualToString:key]) {
                                table = otherVariable;
                                break;
                            }
                        }
                    }
                                    
                    NSArray *tableArray = [self.tablesDictionary objectForKey:table.value];
                    
                    NSString *key = [indices objectAtIndex:[indices count]-1];
                    
                    for(LuaVariable *otherVariable in tableArray) {
                        if([otherVariable.key isEqualToString:key]) {
                            variable = otherVariable;
                            break;
                        }
                    }

                    [self updateVariable:variable fromVariable:[self variableFromDictionary:value]];
                    
                    [self updateVariables:variable inTable:table];
                    
                    [localVariablesView reloadItem:variable];
                }
            }
            
            stackProgressContainer.hidden = YES;
            [stackProgressIndicator stopAnimation:nil];
        }
    }
    else if([type isEqualToString:@"event"]) {
        NSString *event = [dictionary objectForKey:@"event"];
        
        if([event isEqualToString:@"break"]) {            
            NSMutableDictionary *tablesVisited = [NSMutableDictionary dictionary];
            NSArray *tables = [dictionary objectForKey:@"tables"];

            for(NSDictionary *table in tables) {
                NSNumber *ptr = [table objectForKey:@"ptr"];
                NSArray *values = [table objectForKey:@"values"];
                
                NSMutableArray *tableValue = [NSMutableArray array];
                for(NSDictionary *valueDictionary in values) {
                    NSString *key = [valueDictionary objectForKey:@"name"];
                    LuaVariable *variable = [self variableFromDictionary:valueDictionary];
                    
                    variable.key = key;
                    
                    [tableValue addObject:variable];
                }
                
                NSArray *sortedTable = [tableValue sortedArrayUsingComparator:^NSComparisonResult(LuaVariable *a, LuaVariable *b) {
                    return [a.key compare:b.key];
                }];
                
                [tablesVisited setObject:sortedTable forKey:ptr];
            }
            
            self.tablesDictionary = tablesVisited;
            
            NSNumber *error = [dictionary objectForKey:@"error"];
            NSArray *stack = [dictionary objectForKey:@"stack"];
            NSMutableArray *callStack = [NSMutableArray arrayWithCapacity:[stack count]];

            BOOL first = YES;
            for(NSDictionary *call in stack) {
                NSString *source = [call objectForKey:@"source"];
                int firstLine = ((NSNumber *)[call objectForKey:@"firstline"]).intValue;
                int lastLine = ((NSNumber *)[call objectForKey:@"lastline"]).intValue;
                
                LuaCallStackIndex *index = nil;
                
                for(LuaCallStackIndex *otherIndex in self.lastCallStack) {
                    if([otherIndex.source isEqualToString:source] &&
                       firstLine == otherIndex.firstLine &&
                       lastLine == otherIndex.lastLine) {
                        index = [otherIndex retain];
                        break;
                    }
                }
                
                if(index == nil) {
                    index = [[LuaCallStackIndex alloc] init];
                    index.source = source;
                    index.firstLine = firstLine;
                    index.lastLine = lastLine;
                    index.function = [call objectForKey:@"function"];
                }
                
                if(first && error.boolValue) {
                    index.error = YES;
                    first = NO;
                }
                else {
                    index.error = NO;
                }
                
                index.line = ((NSNumber *)[call objectForKey:@"line"]).intValue;

                NSArray *locals = [call objectForKey:@"locals"];
                NSMutableArray *localVariables = [NSMutableArray array];
                
                for(NSDictionary *valueDictionary in locals) {
                    LuaVariable *variable = nil;
                    
                    NSString *key = [valueDictionary objectForKey:@"name"];
                    
                    if(![key isEqualToString:@"(*temporary)"]) {
                        for(LuaVariable *otherLocal in index.localVariables) {
                            if([otherLocal.key isEqualToString:key]) {
                                variable = otherLocal;
                                break;
                            }
                        }
                    }
                    
                    if(variable) {
                        [self updateVariable:variable fromVariable:[self variableFromDictionary:valueDictionary]];
                    }
                    else {
                        variable = [self variableFromDictionary:valueDictionary];
                    }
                    
                    variable.scope = LuaVariableScopeLocal;
                    NSNumber *where = [valueDictionary objectForKey:@"where"];
                    variable.where = where.integerValue;
                    NSNumber *varIndex = [valueDictionary objectForKey:@"index"];
                    variable.index = varIndex.integerValue;
                    variable.key = key;
                    
                    [localVariables addObject:variable];
                }
                
                index.localVariables = [localVariables sortedArrayUsingComparator:^NSComparisonResult(LuaVariable *a, LuaVariable *b) {
                    return [a.key compare:b.key];
                }];
                
                NSArray *upvalues = [call objectForKey:@"upvalues"];
                NSMutableArray *upVariables = [NSMutableArray array];
                
                for(NSDictionary *valueDictionary in upvalues) {
                    NSString *key = [valueDictionary objectForKey:@"name"];
                    NSNumber *varIndex = [valueDictionary objectForKey:@"index"];

                    LuaVariable *variable = [self variableFromDictionary:valueDictionary];
                    
                    for(LuaVariable *otherLocal in index.upVariables) {
                        if(otherLocal.index == varIndex.integerValue &&
                           [otherLocal.key isEqualToString:key]) {
                            variable = otherLocal;
                            break;
                        }
                    }
                    
                    if(variable) {
                        [self updateVariable:variable fromVariable:[self variableFromDictionary:valueDictionary]];
                    }
                    else {
                        variable = [self variableFromDictionary:valueDictionary];
                    }
                    
                    variable.scope = LuaVariableScopeUpvalue;
                    NSNumber *where = [valueDictionary objectForKey:@"where"];
                    variable.where = where.integerValue;
                    variable.index = varIndex.integerValue;
                    variable.key = key;
                    
                    [upVariables addObject:variable];
                }
                
                index.upVariables = [upVariables sortedArrayUsingComparator:^NSComparisonResult(LuaVariable *a, LuaVariable *b) {
                    return [a.key compare:b.key];
                }];
                
                [callStack addObject:index];
                [index release];
            }
            
            self.callStack = callStack;
            self.lastCallStack = callStack;
            
            NSDictionary *globals = [dictionary objectForKey:@"globals"];

            LuaVariable *variable = [self variableFromDictionary:globals];
            
            NSArray *children = [tablesVisited objectForKey:variable.value];
            NSMutableArray *newChildren = [NSMutableArray arrayWithCapacity:[children count]];
            
            for(LuaVariable *global in children) {
                LuaVariable *variable = nil;
                
                for(LuaVariable *otherGlobal in self.lastGlobalTable.children) {
                    if([otherGlobal.key isEqualToString:global.key]) {
                        variable = [otherGlobal retain];
                        break;
                    }
                }
                
                if(variable) {
                    [self updateVariable:variable fromVariable:global];
                }
                else {
                    variable = [global copy];
                }
                
                [newChildren addObject:variable];
                [variable release];
            }
            
            variable.children = newChildren;
            variable.scope = LuaVariableScopeGlobal;

            self.globalTable = variable;
            self.lastGlobalTable = variable;
                        
            stackProgressContainer.hidden = YES;
            [stackProgressIndicator stopAnimation:nil];
            
            [playButton setImage:[NSImage imageNamed:@"resume_co.png"]];
            [playButton setAction:@selector(play:)];
            [playButton setEnabled:YES];
            [stepIntoButton setEnabled:YES];
            [stepOverButton setEnabled:YES];
            [stepOutButton setEnabled:YES];
            
            [self showStackView:nil];
        }
        else if([event isEqualToString:@"message"]) {
            NSString *message = [dictionary objectForKey:@"message"];
            NSString *messageType = [dictionary objectForKey:@"messagetype"];
            
            NSFont *font = [[NSFontManager sharedFontManager]
                            fontWithFamily:@"Menlo"
                            traits:NSBoldFontMask
                            weight:0
                            size:11];

            NSDictionary *fontAttributes = nil;
            
            if([messageType isEqualToString:@"log"]) {
                fontAttributes = @{NSForegroundColorAttributeName : [NSColor blackColor], NSFontAttributeName : font};
            }
            else if([messageType isEqualToString:@"error"]) {
                fontAttributes = @{NSForegroundColorAttributeName : [NSColor redColor], NSFontAttributeName : font};
            }
            
            NSAttributedString *attributedMessage = [[NSAttributedString alloc] initWithString:message attributes:fontAttributes];            
            [consoleString appendAttributedString:attributedMessage];
            [attributedMessage release];
        
            static CFAbsoluteTime lastTime = 0;
            CFAbsoluteTime currentTime = CFAbsoluteTimeGetCurrent();
            
            if(currentTime - lastTime >= 250) {
                [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateConsoleString) object:nil];
                lastTime = currentTime;
                
                [self updateConsoleString];
            }
            else {
                [self performSelector:@selector(updateConsoleString) withObject:nil afterDelay:0.25];
            }
        }
    }
}

- (void)updateConsoleString {    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(updateConsoleString) object:nil];

    BOOL shouldScroll = [[consoleTextView enclosingScrollView] verticalScroller].floatValue == 1.0f;
    
    [[consoleTextView textStorage] appendAttributedString:consoleString];
    [consoleString replaceCharactersInRange:NSMakeRange(0, [consoleString length]) withString:@""];
    
    if(shouldScroll) {
        NSRange range = NSMakeRange([[consoleTextView string] length], 0);
        [consoleTextView scrollRangeToVisible:range];
    }
}

-(NSString *)toQuotedString:(NSString *)input {
    const char *chars = [input UTF8String];
	NSUInteger maxsize = strlen(chars)*2 + 3; // allescaped+quotes+NULL
    
    NSMutableString *result = [NSMutableString stringWithCapacity:maxsize];
	[result appendString:@"\""];

	for(const char* c=chars; *c != 0; ++c) {
		switch(*c) {
			case '\"':
				[result appendString:@"\\\""];
				break;
			case '\\':
				[result appendString:@"\\\\"];
				break;
			case '\b':
				[result appendString:@"\\b"];
				break;
			case '\f':
				[result appendString:@"\\f"];
				break;
			case '\n':
				[result appendString:@"\\n"];
				break;
			case '\r':
				[result appendString:@"\\r"];
				break;
			case '\t':
				[result appendString:@"\\t"];
				break;
            default:
				/*if(isControlCharacter( *c ) ) {
					std::ostringstream oss;
					oss << "\\u" << std::hex << std::uppercase << std::setfill('0') << std::setw(4) << static_cast<int>(*c);
					result += oss.str().c_str();
				}
				else*/
				{
					[result appendFormat:@"%c", *c];
				}
				break;
		}
	}
    
	[result appendString:@"\""];
    
	return result;
}

- (IBAction)connect:(id)sender {
    connecting = YES;
    
    self.readingHeader = true;
    self.headerReceivedBytes = 0;
    self.packetReceivedBytes = 0;
    
    NSString *host = [[hostTextField stringValue] length] > 0 ? [hostTextField stringValue] : @"localhost";
    unsigned short port = [[portTextField stringValue] length]  > 0 ? [portTextField intValue] : 3632;
    
    [socket connect:host port:port];
    
    connectionIndicator.hidden = NO;
    [connectionIndicator startAnimation:nil];
    connectionLabel.stringValue = @"Connecting...";
}

- (IBAction)disconnect:(id)sender {
    [socket close];
    
    connecting = NO;
    
    self.readingHeader = true;
    self.headerReceivedBytes = 0;
    self.packetReceivedBytes = 0;
    
    connectionIndicator.hidden = YES;
    [connectionIndicator stopAnimation:nil];
    connectionLabel.stringValue = @"Disconnected";
    
    [scriptEditObjects removeAllObjects];
    [scriptsTableView reloadData];
    
    [breakpointsDictionary removeAllObjects];
    [breakpointsView reloadData];
    
    self.callStack = nil;
    self.localVariables = nil;
    self.globalTable = nil;
    
    [playButton setImage:[NSImage imageNamed:@"suspend_co.png"]];
	[playButton setAction:@selector(pause:)];
    [playButton setEnabled:NO];
	[stepIntoButton setEnabled:NO];
	[stepOverButton setEnabled:NO];
	[stepOutButton setEnabled:NO];
    
    [connectButton setTitle:@"Connect"];
    [connectButton setAction:@selector(connect:)];
}

- (IBAction)processText:(NSTextField*)sender {
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    NSFont *font = [fontManager fontWithFamily:@"Menlo"
                                              traits:0
                                              weight:0
                                                size:11];
    
    NSAttributedString *attributedMessage = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@">%@\n", [sender stringValue]] attributes:@{NSForegroundColorAttributeName : [NSColor blackColor], NSFontAttributeName : font}];
    [[consoleTextView textStorage] appendAttributedString:attributedMessage];
    [attributedMessage release];
    
	NSRange range = NSMakeRange ([[consoleTextView string] length], 0);
	[consoleTextView scrollRangeToVisible: range];
    
    NSData *data = [[NSString stringWithFormat:@"{\"type\":\"request\",\"command\":\"interpret\",\"source\":%@}", [self toQuotedString:[sender stringValue]]] dataUsingEncoding:NSUTF8StringEncoding];
    [self sendData:data];
    
    [sender setStringValue:@""];
}

- (void)selectTableIndex:(NSInteger)selectedIndex {
	if(selectedIndex == -1) {
        [documentView setSubviews:[NSArray array]];
	}
	else {
		ScriptDocument *document = [scriptEditObjects objectAtIndex:selectedIndex];
		
		[self performInsertFirstDocument:document];
		
		[saveItem setEnabled:document.wasModified];
		//[startItem setEnabled:document.script->isRunnable()];
		[reloadItem setEnabled:YES];
		[unloadItem setEnabled:YES];
	}
	
	currentScriptIndex = selectedIndex;
}

/*- (void)addScript:(Script*)script {
	if(reloadingScript)
		return;
	
	ScriptDocument *document = [[ScriptDocument alloc] initWithContentView:documentView];
	document.script = script;
	document.textView.string = [NSString stringWithCString:script->source().asCharPtr() encoding:NSASCIIStringEncoding];
	[document updateLineNumbers:YES];
	int i = 0;
	for(; i < [scriptEditObjects count]; ++i) {
		ScriptDocument *other = [scriptEditObjects objectAtIndex:i];

		if(document.script->name() < other.script->name()) {
			[scriptEditObjects insertObject:document atIndex:i];
			
			if(currentScriptIndex != -1) {
				if(currentScriptIndex >= i) {
					currentScriptIndex++;
					[scriptsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:currentScriptIndex] byExtendingSelection:NO];
				}
			}
			
			[scriptsTableView reloadData];
			return;
		}
	}
	
	[scriptEditObjects addObject:document];
	[scriptsTableView reloadData];
}

- (void)removeScript:(Script*)script {
	if(reloadingScript)
		return;
	
	int i = 0;
	for(; i < [scriptEditObjects count]; ++i) {
		ScriptDocument *document = [scriptEditObjects objectAtIndex:i];
		if(document.script == script) {
			[scriptEditObjects removeObjectAtIndex:i];
			break;
		}
	}
	
	if([scriptEditObjects count] == 0) {
		[self selectTableIndex:-1];
	}
	else {
		if(i == currentScriptIndex) {
			i = MIN([scriptEditObjects count]-1, i);
			[self selectTableIndex:i];
		}
		else if(currentScriptIndex > i) {
			currentScriptIndex--;
		}
		
		[scriptsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:currentScriptIndex] byExtendingSelection:NO];
	}
	
	[scriptsTableView reloadData];
}*/

#pragma mark - ScriptDocumentDelegate

- (void)documentWasModified:(ScriptDocument *)document modified:(BOOL)modified {
    [saveItem setEnabled:document.wasModified];
    
    [scriptsTableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:[scriptEditObjects indexOfObject:document]] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
}

- (void)documentDidAddBreakpoint:(ScriptDocument *)document line:(NSUInteger)line {
    NSData *data = [[NSString stringWithFormat:@"{\"type\":\"request\",\"command\":\"addbreakpoint\",\"script\":\"%@\",\"line\":%ld}", document.scriptName, line] dataUsingEncoding:NSUTF8StringEncoding];

    [self sendData:data];
    
    NSMutableArray *array = [breakpointsDictionary objectForKey:[NSNumber numberWithInteger:(NSInteger)document]];
    
    if(array == nil) {
        array = [NSMutableArray array];
        [breakpointsDictionary setObject:array forKey:[NSNumber numberWithInteger:(NSInteger)document]];
    }
    
    NSInteger index = 0;
    
    for(; index < [array count]; ++index) {
        if(((NSNumber *)[array objectAtIndex:index]).unsignedIntegerValue > line) {
            [array insertObject:[NSNumber numberWithUnsignedInteger:line] atIndex:index];
            break;
        }
    }
    
    if(index == [array count]) 
        [array addObject:[NSNumber numberWithUnsignedInteger:line]];
    
    [breakpointsView reloadData];
    [breakpointsView expandItem:nil expandChildren:YES];
}

- (void)documentDidRemoveBreakpoint:(ScriptDocument *)document line:(NSUInteger)line {
    NSData *data = [[NSString stringWithFormat:@"{\"type\":\"request\",\"command\":\"removebreakpoint\",\"script\":\"%@\",\"line\":%ld}", document.scriptName, line] dataUsingEncoding:NSUTF8StringEncoding];
    
    [self sendData:data];
    
    NSMutableArray *array = [breakpointsDictionary objectForKey:[NSNumber numberWithInteger:(NSInteger)document]];
    
    if(array != nil) {
        [array removeObjectIdenticalTo:[NSNumber numberWithUnsignedInteger:line]];
        
        if([array count] == 0) {
            [breakpointsDictionary removeObjectForKey:[NSNumber numberWithInteger:(NSInteger)document]];
        }
    }
    
    [breakpointsView reloadData];
    [breakpointsView expandItem:nil expandChildren:YES];
}

#pragma mark - NSWindowDelegate

- (void)windowDidBecomeKey:(NSNotification *)notification {
	eventMonitor = [NSEvent addLocalMonitorForEventsMatchingMask:NSKeyDownMask handler:^(NSEvent *theEvent) {
		if([theEvent modifierFlags] & NSCommandKeyMask) {
			NSString *characters = [theEvent charactersIgnoringModifiers];
			if([characters isEqualToString: @"s"]) {
				if(currentScriptIndex != -1) {
					[self saveSelectedScript];
				}
				
				return (NSEvent *)nil;
			}
		}
		
		return theEvent;
	}];	
}

- (void)windowDidResignKey:(NSNotification *)notification {
	[NSEvent removeMonitor:eventMonitor];
}

#pragma mark - NSComboBoxDataSource

- (NSInteger)numberOfItemsInComboBox:(NSComboBox *)aComboBox {
    NSArray *array = [[NSUserDefaults standardUserDefaults] arrayForKey:@"cachedHosts"];
    
    return [array count];
}

- (id)comboBox:(NSComboBox *)aComboBox objectValueForItemAtIndex:(NSInteger)index {
    NSArray *array = [[NSUserDefaults standardUserDefaults] arrayForKey:@"cachedHosts"];

    NSDictionary *dictionary = [array objectAtIndex:index];
    return [dictionary objectForKey:@"host"];
}

#pragma mark - NSComboBoxDelegate

- (void)comboBoxSelectionDidChange:(NSNotification *)notification {
    NSArray *array = [[NSUserDefaults standardUserDefaults] arrayForKey:@"cachedHosts"];

    NSDictionary *dictionary = [array objectAtIndex:[hostTextField indexOfSelectedItem]];
    [hostTextField setStringValue:[dictionary objectForKey:@"host"]];
    [portTextField setStringValue:((NSNumber *)[dictionary objectForKey:@"port"]).stringValue];
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
	if(tableView == scriptsTableView) {
		return [scriptEditObjects count];
	}
	else if(tableView == callStackView) {
		return [self.callStack count];
	}
	
	return 0;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
	if(tableView == scriptsTableView) {
		ScriptDocument *document = [scriptEditObjects objectAtIndex:row];
            
		return document.scriptName;
	}
	else if(tableView == callStackView) {
		LuaCallStackIndex *index = [self.callStack objectAtIndex:row];
		return [NSString stringWithFormat:@"%@:%@: line %d", index.source, index.function, index.line];
	}
	
	return nil;
}

#pragma mark - NSTableViewDelegate

- (void)tableView:(NSTableView *)aTableView willDisplayCell:(ImageAndTextCell *)aCell forTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
	if(aTableView == scriptsTableView) {
		ScriptDocument *document = [scriptEditObjects objectAtIndex:rowIndex];

		[aCell setModified:document.wasModified];
		
		//if(document.script->isRunnable())
		//	[aCell setFont:[NSFont boldSystemFontOfSize:[NSFont systemFontSize]]];
		//else
			[aCell setFont:[NSFont systemFontOfSize:[NSFont systemFontSize]]];
	}
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
	return NO;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
	if([aNotification object] == scriptsTableView) {		
		[self selectTableIndex:[scriptsTableView selectedRow]];
	}
    else {
        NSInteger idx = [callStackView selectedRow];
        
        if(idx != -1) {
            LuaCallStackIndex *index = [self.callStack objectAtIndex:idx];
            
            for(int i = 0; i < [scriptEditObjects count]; ++i) {
                ScriptDocument *document = [scriptEditObjects objectAtIndex:i];
                
                if([index.source isEqualTo:document.scriptName]) {
                    [self selectTableIndex:i];
                    [scriptsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:i] byExtendingSelection:NO];
                    
                    if(index.error) {
                        [document.textView setHighlightedLineColor:[NSColor redColor] background:[NSColor colorWithDeviceRed:1.0f green:0.8f blue:0.8f alpha:1.0f]];
                    }
                    else {
                        [document.textView setHighlightedLineColor:[NSColor blueColor] background:[NSColor colorWithDeviceRed:0.8f green:0.8f blue:1.0f alpha:1.0f]];
                    }
                    
                    [document.textView setHighlightedLine:index.line];
                    break;
                }
            }
            
            self.localVariables = [index.upVariables arrayByAddingObjectsFromArray:index.localVariables];
        }
    }
}

#pragma mark - NSOutlineViewDataSource

- (void)initExpansions:(LuaVariable *)variable {    
    BOOL expanded = variable.expanded;
    
    if([variable.children count] > 0) {
        [localVariablesView expandItem:variable];
        
        for(LuaVariable *child in variable.children) {
            [self initExpansions:child];
        }
        
        if(!expanded) {
            [localVariablesView collapseItem:variable];
        }
    }
    else if(expanded) {
        [localVariablesView expandItem:variable];
    }
}

- (IBAction)switchToLocals:(id)sender {
	showLocals = YES;

	[self reloadLocalVariables];
}

- (IBAction)switchToGlobals:(id)sender {
	showLocals = NO;

	[self reloadGlobalVariables];
}

- (IBAction)showTemporaries:(id)sender {
    if(showLocals) {
        [self reloadLocalVariables];
    }
}

- (void)setCallStack:(NSArray *)callStack {
    [_callStack release];
    _callStack = [callStack retain];
    
    NSInteger lastSelectedRow = callStackView.selectedRow;
    
    [callStackView reloadData];
    
    if([self.callStack count] == 0)
        return;
    
    NSInteger selectedRow = callStackView.selectedRow;

    if(lastSelectedRow == 0) {
        LuaCallStackIndex *index = [self.callStack objectAtIndex:0];
        
        for(int i = 0; i < [scriptEditObjects count]; ++i) {
            ScriptDocument *document = [scriptEditObjects objectAtIndex:i];
            
            if([index.source isEqualTo:document.scriptName]) {
                [self selectTableIndex:i];
                [scriptsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:i] byExtendingSelection:NO];
                
                if(index.error) {
                    [document.textView setHighlightedLineColor:[NSColor redColor] background:[NSColor colorWithDeviceRed:1.0f green:0.8f blue:0.8f alpha:1.0f]];
                }
                else {
                    [document.textView setHighlightedLineColor:[NSColor blueColor] background:[NSColor colorWithDeviceRed:0.8f green:0.8f blue:1.0f alpha:1.0f]];
                }
                
                [document.textView setHighlightedLine:index.line];
                break;
            }
        }
        
        self.localVariables = [index.upVariables arrayByAddingObjectsFromArray:index.localVariables];
    }
    else if(selectedRow != 0) {
        [callStackView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
    }
}

- (void)reloadLocalVariables {
    [localVariablesView reloadData];
    for(LuaVariable *variable in self.localVariables) {
        if(showTemporariesButton.state == NSOffState && [variable isTemporary])
            continue;
        
        [self initExpansions:variable];
    }
}

- (void)reloadGlobalVariables {
    [localVariablesView reloadData];
    for(LuaVariable *variable in self.globalTable.children) {
        [self initExpansions:variable];
    }
}

- (void)setLocalVariables:(NSArray *)locals {
    [_localVariables release];
	_localVariables = [locals retain];
	
	if(showLocals) {
		[self reloadLocalVariables];
    }
}

- (void)setGlobalTable:(LuaVariable *)globalTable {
    if(globalTable != _globalTable) {
        [_globalTable release];
        _globalTable = [globalTable retain];
    }
    
    if(!showLocals) {
        [self reloadGlobalVariables];
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    if(outlineView == localVariablesView) {
        if([item isKindOfClass:[LuaVariable class]]) {
            LuaVariable *var = item;
            
            if(var.type == LuaVariableTypeTable) {
                NSArray *children = var.children ? var.children : [self.tablesDictionary objectForKey:var.value];

                return ([children count] > 0);
            }
        }
    }
    else if(outlineView == breakpointsView) {
        if([item isKindOfClass:[ScriptDocument class]]) {            
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)theColumn item:(id)item {
    if(outlineView == localVariablesView) {
        return YES;
    }
    
    return NO;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldExpandItem:(id)item {
    if(outlineView == localVariablesView) {
        if([item isKindOfClass:[LuaVariable class]]) {
            LuaVariable *var = item;
            var.expanded = YES;
        }
    }
    
    return YES;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldCollapseItem:(id)item {
    if(outlineView == localVariablesView) {
        if([item isKindOfClass:[LuaVariable class]]) {
            LuaVariable *var = item;
            
            BOOL visible = YES;
            LuaVariable *parent = var.parent;
            
            while(parent != nil) {
                if(!parent.expanded) {
                    visible = NO;
                    break;
                }
                
                parent = parent.parent;
            }
            
            if(visible) {
                var.expanded = NO;
            }        
        }
    }
    
    return YES;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if(outlineView == localVariablesView) {
        if(item == nil) {
            if(showLocals) {
                if(showTemporariesButton.state == NSOnState) {
                    return [self.localVariables count];
                }
                else {
                    NSInteger count = 0;
                    
                    for(LuaVariable *var in self.localVariables) {
                        if(![var isTemporary])
                            count++;
                    }
                    
                    return count;
                }
            }
            else {
                 return [self.globalTable.children count];
            }
        }
        else if([item isKindOfClass:[LuaVariable class]]) {
            LuaVariable *var = item;
            
            if(var.type == LuaVariableTypeTable) {
                NSArray *children = var.children ? var.children : [self.tablesDictionary objectForKey:var.value];
                
                return [children count];
            }
        }
    }
    else if(outlineView == breakpointsView) {
        if(item == nil) {
            return [breakpointsDictionary count];
        }
        else {
            NSArray *array = [breakpointsDictionary objectForKey:[NSNumber numberWithInteger:(NSInteger)item]];
            
            return [array count];
        }
    }
	
	return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    if(outlineView == localVariablesView) {
        if(item == nil) {
            if(showLocals) {
                if(showTemporariesButton.state == NSOnState) {
                    return [self.localVariables objectAtIndex:index];
                }
                else {
                    NSInteger count = 0;
                    
                    for(LuaVariable *var in self.localVariables) {
                        if(![var isTemporary]) {
                            if(count == index)
                                return var;
                            
                            count++;
                        }
                    }                
                }
            }
            else {
                return [self.globalTable.children objectAtIndex:index];
            }
        }
        
        if([item isKindOfClass:[LuaVariable class]]) {
            LuaVariable *var = item;
            
            if(var.type == LuaVariableTypeTable) {
                if(!var.children) {
                    NSArray *children = [self.tablesDictionary objectForKey:var.value];
                    NSArray *childrenCopy = [[NSArray alloc] initWithArray:children copyItems:YES];
                    var.children = childrenCopy;
                    [childrenCopy release];
                }
                
                return [var.children objectAtIndex:index];
            }
        }
    }
    else if(outlineView == breakpointsView) {
        if(item == nil) {
            NSNumber *ptr = [[breakpointsDictionary allKeys] objectAtIndex:index];
            
            return (ScriptDocument *)[ptr integerValue];
        }
        else {
            NSArray *array = [breakpointsDictionary objectForKey:[NSNumber numberWithInteger:(NSInteger)item]];
            
            return [array objectAtIndex:index];
        }
    }
	
	return nil;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)theColumn byItem:(id)item {
    if(outlineView == localVariablesView) {
        if([item isKindOfClass:[LuaVariable class]]) {
            LuaVariable *var = item;
            
            return var;
        }
    }
    else if(outlineView == breakpointsView) {
        if([item isKindOfClass:[ScriptDocument class]]) {
            ScriptDocument *document = item;
           
            return [[[BreakpointCellValue alloc] initWithScriptName:document.scriptName] autorelease];
        }
        else if([item isKindOfClass:[NSNumber class]]) {
            ScriptDocument *document = [breakpointsView parentForItem:item];
            
            int lineNumber = (int)[item unsignedIntegerValue];
            
            NSString *previewString = [[document.textView stringForLine:lineNumber] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            NSString *lineString = [NSString stringWithFormat:@"line %d", lineNumber];

            return [[[BreakpointCellValue alloc] initWithPreviewString:previewString lineString:lineString] autorelease];
        }
    }
    
    return item;
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)theColumn byItem:(id)item {
    if(outlineView == localVariablesView) {
        VariableCell *cell = [theColumn dataCellForRow:[outlineView rowForItem:item]];
        if([cell.stringValue isEqualToString:object])
            return;
        
        if([item isKindOfClass:[LuaVariable class]]) {
            LuaVariable *var = item;
            NSString *indices = @"";
            
            while(var.parent != nil) {
                if([indices length] == 0) {
                    indices = [self toQuotedString:var.key];
                }
                else {
                    indices = [[self toQuotedString:var.key] stringByAppendingFormat:@",%@", indices];
                }

                var = var.parent;
            }
                    
            if(var.scope == LuaVariableScopeLocal) {
                NSData *data = [[NSString stringWithFormat:@"{\"type\":\"request\",\"command\":\"setlocal\",\"indices\":[%@],\"where\":%d,\"index\":%d,\"value\":%@}", indices, (int)var.where, (int)var.index, [self toQuotedString:[NSString stringWithFormat:@"return %@", object]]] dataUsingEncoding:NSUTF8StringEncoding];
                [self sendData:data];
       
            }
            else if(var.scope == LuaVariableScopeUpvalue) {
                NSData *data = [[NSString stringWithFormat:@"{\"type\":\"request\",\"command\":\"setupvalue\",\"indices\":[%@],\"where\":%d,\"index\":%d,\"value\":%@}", indices, (int)var.where, (int)var.index, [self toQuotedString:[NSString stringWithFormat:@"return %@", object]]] dataUsingEncoding:NSUTF8StringEncoding];
                [self sendData:data];
            }
            else if(var.scope == LuaVariableScopeGlobal) {
                NSData *data = [[NSString stringWithFormat:@"{\"type\":\"request\",\"command\":\"setglobal\",\"indices\":[%@],\"value\":%@}", indices, [self toQuotedString:[NSString stringWithFormat:@"return %@", object]]] dataUsingEncoding:NSUTF8StringEncoding];
                [self sendData:data];
            }
            
            stackProgressContainer.hidden = NO;
            [stackProgressIndicator startAnimation:nil];
            
            [localVariablesView reloadItem:item];
        }
    }
}

- (void)outlineViewSelectionDidChange:(NSNotification *)aNotification {
	if([aNotification object] == breakpointsView) {
        id selectedRow = [breakpointsView itemAtRow:[breakpointsView selectedRow]];

        ScriptDocument *document = [breakpointsView parentForItem:selectedRow];
        
        int line = -1;
        if(document == nil) {
            document = selectedRow;
        }
        else {
            line = (int)[selectedRow unsignedIntegerValue];
        }
        
        NSInteger i = 0;
        for(ScriptDocument *otherDocument in scriptEditObjects) {
            if(document == otherDocument) {
                [self selectTableIndex:i];
                [scriptsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:i] byExtendingSelection:NO];
                
                if(line != -1) {
                    [document.textView scrollToLine:line];
                }
                
                break;
            }
            
            ++i;
        }
	}
}

#pragma mark - NSSplitViewDelegate 

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview {
    if(splitView == stackSplitView) {
        if(subview == stackSplitViewLeftView) {
            return YES;
        }
    }
    else if(splitView == consoleSplitView) {
        return YES;
    }
    else if(splitView == documentSplitView) {
        return YES;
    }
    
    return NO;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex {
    if(splitView == stackSplitView) {
        return proposedMinimumPosition + 150.0f;
    }
    else if(splitView == consoleSplitView) {
        return proposedMinimumPosition + 150.0f;
    }
    else if(splitView == documentSplitView) {
        return proposedMinimumPosition + 150.0f;
    }
    
    return proposedMinimumPosition;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex {
    if(splitView == stackSplitView) {
        return proposedMinimumPosition - 400.0f;
    }
    else if(splitView == consoleSplitView) {
        return proposedMinimumPosition - 150.0f;
    }
    else if(splitView == documentSplitView) {
        return proposedMinimumPosition - 150.0f;
    }
    
    return proposedMinimumPosition;
}

- (void)splitView:(NSSplitView *)sender resizeSubviewsWithOldSize:(NSSize)oldSize {
    if(sender == stackSplitView) {
        CGFloat dividerThickness = [sender dividerThickness];
        NSRect frame = [sender frame];
        
        if([stackSplitView isSubviewCollapsed:stackSplitViewLeftView]) {
            stackSplitViewRightView.frame = NSMakeRect(+dividerThickness, 0, frame.size.width-dividerThickness, frame.size.height);
        }
        else {
            CGFloat rightWidth = MAX(frame.size.width-stackSplitViewLeftView.frame.size.width-dividerThickness, 400.0f);
            CGFloat leftWidth = frame.size.width-rightWidth-dividerThickness;

            stackSplitViewLeftView.frame = NSMakeRect(0, 0, leftWidth, frame.size.height);
            stackSplitViewRightView.frame = NSMakeRect(leftWidth+dividerThickness, 0, rightWidth, frame.size.height);
        }
    }
    else if(sender == documentSplitView) {
        CGFloat dividerThickness = [sender dividerThickness];
        NSRect frame = [sender frame];
        
        if([documentSplitView isSubviewCollapsed:documentSplitViewBottomView]) {
            documentSplitViewTopView.frame = NSMakeRect(0, 0, frame.size.width, frame.size.height-dividerThickness);
        }
        else {
            CGFloat topHeight = MAX(frame.size.height-documentSplitViewBottomView.frame.size.height-dividerThickness, 150.0f);
            CGFloat bottomHeight = frame.size.height-topHeight-dividerThickness;
            
            documentSplitViewTopView.frame = NSMakeRect(0, 0, frame.size.width, topHeight);
            documentSplitViewBottomView.frame = NSMakeRect(0, topHeight+dividerThickness, frame.size.width, bottomHeight);
        }
    }
    else {
        [sender adjustSubviews];
    }
}

- (void)saveSelectedScript {
	if(currentScriptIndex != -1) {
		ScriptDocument *document = [scriptEditObjects objectAtIndex:currentScriptIndex];
				
		if(document.wasModified) {
            NSData *data = [[NSString stringWithFormat:@"{\"type\":\"request\",\"command\":\"reloadScript\",\"script\":%@,\"source\":%@}", [self toQuotedString:document.scriptName], [self toQuotedString:document.textView.string]] dataUsingEncoding:NSUTF8StringEncoding];
            [self sendData:data];
			
			document.wasModified = NO;
			
			[scriptsTableView reloadDataForRowIndexes:[NSIndexSet indexSetWithIndex:currentScriptIndex] columnIndexes:[NSIndexSet indexSetWithIndex:0]];
		}
	}
}

- (void)startSelectedScript {
	if(currentScriptIndex != -1) {
		ScriptDocument *document = [scriptEditObjects objectAtIndex:currentScriptIndex];
		
		/*if(document.wasModified) {
			reloadingScript = YES;
			document.script->reload();
			reloadingScript = NO;
		}
		
		ScriptManager::Instance()->startRunning(document.script);*/
	}
}

- (void)reloadSelectedScript {
	if(currentScriptIndex != -1) {
		ScriptDocument *document = [scriptEditObjects objectAtIndex:currentScriptIndex];
		
        NSData *data = [[NSString stringWithFormat:@"{\"type\":\"request\",\"command\":\"reloadScript\",\"script\":%@,\"source\":%@}", [self toQuotedString:document.scriptName], [self toQuotedString:document.textView.string]] dataUsingEncoding:NSUTF8StringEncoding];
        [self sendData:data];
	}
}

- (void)unloadSelectedScript {
	if(currentScriptIndex != -1) {
		ScriptDocument *document = [scriptEditObjects objectAtIndex:currentScriptIndex];
		
		//document.script->unload();
	}
}

- (void)disableStackButtons {
    [playButton setEnabled:NO];
	[stepIntoButton setEnabled:NO];
	[stepOverButton setEnabled:NO];
	[stepOutButton setEnabled:NO];
}

- (IBAction)play:(id)sender {
	if(currentScriptIndex != -1) {
		ScriptDocument *document = [scriptEditObjects objectAtIndex:currentScriptIndex];
		[document.textView setHighlightedLine:-1];
	}
	
    self.callStack = nil;
	self.localVariables = nil;
	self.globalTable = nil;
	
    [self disableStackButtons];
    
	[playButton setImage:[NSImage imageNamed:@"suspend_co.png"]];
	[playButton setAction:@selector(pause:)];
	[playButton setEnabled:YES];
    
    char *str = "{\"type\":\"request\",\"command\":\"continue\"}";
    NSData *data = [NSData dataWithBytes:str length:strlen(str)+1];
    
    [self sendData:data];
}

- (IBAction)pause:(id)sender {
    char *str = "{\"type\":\"request\",\"command\":\"break\"}";
    NSData *data = [NSData dataWithBytes:str length:strlen(str)+1];
    
    [self sendData:data];
    
    [self disableStackButtons];
    stackProgressContainer.hidden = NO;
    [stackProgressIndicator startAnimation:nil];
}

- (IBAction)stepInto:(id)sender {
    char *str = "{\"type\":\"request\",\"command\":\"stepinto\"}";
    NSData *data = [NSData dataWithBytes:str length:strlen(str)+1];
    
    [self sendData:data];
    
	if(currentScriptIndex != -1) {
		ScriptDocument *document = [scriptEditObjects objectAtIndex:currentScriptIndex];
		[document.textView setHighlightedLine:-1];
	}
	
    self.callStack = nil;
	self.localVariables = nil;
	self.globalTable = nil;
    
    [self disableStackButtons];
	stackProgressContainer.hidden = NO;
    [stackProgressIndicator startAnimation:nil];
}

- (IBAction)stepOut:(id)sender {
    char *str = "{\"type\":\"request\",\"command\":\"stepout\"}";
    NSData *data = [NSData dataWithBytes:str length:strlen(str)+1];
    
    [self sendData:data];
    
	if(currentScriptIndex != -1) {
		ScriptDocument *document = [scriptEditObjects objectAtIndex:currentScriptIndex];
		[document.textView setHighlightedLine:-1];
	}
	
    self.callStack = nil;
	self.localVariables = nil;
	self.globalTable = nil;
    
	[self disableStackButtons];
	stackProgressContainer.hidden = NO;
    [stackProgressIndicator startAnimation:nil];
}

- (IBAction)stepOver:(id)sender {
    char *str = "{\"type\":\"request\",\"command\":\"stepover\"}";
    NSData *data = [NSData dataWithBytes:str length:strlen(str)+1];
    
    [self sendData:data];
    
	if(currentScriptIndex != -1) {
		ScriptDocument *document = [scriptEditObjects objectAtIndex:currentScriptIndex];
		[document.textView setHighlightedLine:-1];
	}
    
    self.callStack = nil;
	self.localVariables = nil;
	self.globalTable = nil;
    
    [self disableStackButtons];
	stackProgressContainer.hidden = NO;
    [stackProgressIndicator startAnimation:nil];
}

- (IBAction)showScriptsView:(NSButton *)sender {
    if([self.scriptsScrollView superview])
        return;

    buttonBackground.frame = showScriptsButton.frame;

    self.scriptsScrollView.frame = currentScrollView.frame;
    
    [[currentScrollView superview] replaceSubview:currentScrollView with:self.scriptsScrollView];
    
    currentScrollView = self.scriptsScrollView;
}

- (IBAction)showStackView:(NSButton *)sender {
    if([self.callStackScrollView superview])
        return;
    
    buttonBackground.frame = showStackButton.frame;
    
    self.callStackScrollView.frame = currentScrollView.frame;

    [[currentScrollView superview] replaceSubview:currentScrollView with:self.callStackScrollView];
    
    currentScrollView = self.callStackScrollView;
}

- (IBAction)showBreakpointView:(NSButton *)sender {
    if([self.breakpointScrollView superview])
        return;
    
    buttonBackground.frame = showBreakpointsButton.frame;
    
    self.breakpointScrollView.frame = currentScrollView.frame;
    
    [[currentScrollView superview] replaceSubview:currentScrollView with:self.breakpointScrollView];
    
    currentScrollView = self.breakpointScrollView;
}

- (IBAction)clearConsole:(id)sender {
    [consoleTextView setString:@""];
}

- (void)jumpToStack {
	NSInteger idx = [callStackView clickedRow];
	
	if(idx != -1) {
		LuaCallStackIndex *index = [self.callStack objectAtIndex:idx];
		        
		for(int i = 0; i < [scriptEditObjects count]; ++i) {
			ScriptDocument *document = [scriptEditObjects objectAtIndex:i];
			
			if([index.source isEqualTo:document.scriptName]) {
				[self selectTableIndex:i];
				[scriptsTableView selectRowIndexes:[NSIndexSet indexSetWithIndex:i] byExtendingSelection:NO];				
				break;
			}
		}
        
        self.localVariables = [index.upVariables arrayByAddingObjectsFromArray:index.localVariables];
	}
}

@end


