//
//  LXWindowController.m
//  Luax
//
//  Created by Noah Hilt on 11/24/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "LXProjectWindowController.h"
#import "LXTextFieldCell.h"
#import "LXLuaVariableCell.h"
#import "LXLuaCallStackIndex.h"
#import "LXLuaVariable.h"
#import "NSString+JSON.h"

@implementation LXTableView

- (void)highlightSelectionInClipRect:(NSRect)theClipRect {
    NSGradient *gradient;
    
    if(self == [[self window] firstResponder] && [[self window] isMainWindow] && [[self window] isKeyWindow]) {
        gradient = [[NSGradient alloc] initWithColorsAndLocations:
                    [NSColor colorWithCalibratedRed:0.000 green:0.686 blue:0.914 alpha:1], 0.0,
                    [NSColor colorWithCalibratedRed:0.000 green:0.486 blue:0.714 alpha:1], 1.0, nil];
    }
    else {
        gradient = [[NSGradient alloc] initWithColorsAndLocations:
                    [NSColor colorWithCalibratedRed:0.000 green:0.486 blue:0.714 alpha:1], 0.0,
                    [NSColor colorWithCalibratedRed:0.000 green:0.286 blue:0.514 alpha:1], 1.0, nil];
        
    }
    
    NSRange aVisibleRowIndexes = [self rowsInRect:theClipRect];
    NSIndexSet *aSelectedRowIndexes = [self selectedRowIndexes];
    NSMutableArray *rects = [NSMutableArray array];
    BOOL firstRect = YES;
    NSRect currentRect = NSZeroRect;
    
    for(NSInteger i = aVisibleRowIndexes.location; i < NSMaxRange(aVisibleRowIndexes); ++i) {
        if([aSelectedRowIndexes containsIndex:i]) {
            if(firstRect) {
                currentRect = [self rectOfRow:i];
                firstRect = NO;
            }
            else {
                currentRect = NSUnionRect(currentRect, [self rectOfRow:i]);
            }
        }
        else if(!firstRect) {
            [rects addObject:[NSValue valueWithRect:currentRect]];
            currentRect = NSZeroRect;
            firstRect = YES;
        }
    }
    
    if(!firstRect) {
        [rects addObject:[NSValue valueWithRect:currentRect]];
    }
    
    for(NSValue *value in rects) {
        NSBezierPath *path = [NSBezierPath bezierPathWithRect:value.rectValue];
        
        [gradient drawInBezierPath:path angle:90];
    }
}

@end

@implementation LXOutlineView

- (void)highlightSelectionInClipRect:(NSRect)theClipRect {
    NSGradient *gradient;
    
    if(self == [[self window] firstResponder] && [[self window] isMainWindow] && [[self window] isKeyWindow]) {
        gradient = [[NSGradient alloc] initWithColorsAndLocations:
                     [NSColor colorWithCalibratedRed:0.000 green:0.686 blue:0.914 alpha:1], 0.0,
                     [NSColor colorWithCalibratedRed:0.000 green:0.486 blue:0.714 alpha:1], 1.0, nil];
    }
    else {
        gradient = [[NSGradient alloc] initWithColorsAndLocations:
                    [NSColor colorWithCalibratedRed:0.000 green:0.486 blue:0.714 alpha:1], 0.0,
                    [NSColor colorWithCalibratedRed:0.000 green:0.286 blue:0.514 alpha:1], 1.0, nil];
        
    }
    
    NSRange aVisibleRowIndexes = [self rowsInRect:theClipRect];
    NSIndexSet *aSelectedRowIndexes = [self selectedRowIndexes];
    NSMutableArray *rects = [NSMutableArray array];
    BOOL firstRect = YES;
    NSRect currentRect = NSZeroRect;
    
    for(NSInteger i = aVisibleRowIndexes.location; i < NSMaxRange(aVisibleRowIndexes); ++i) {
        if([aSelectedRowIndexes containsIndex:i]) {
            if(firstRect) {
                currentRect = [self rectOfRow:i];
                firstRect = NO;
            }
            else {
                currentRect = NSUnionRect(currentRect, [self rectOfRow:i]);
            }
        }
        else if(!firstRect) {
            [rects addObject:[NSValue valueWithRect:currentRect]];
            currentRect = NSZeroRect;
            firstRect = YES;
        }
    }
    
    if(!firstRect) {
        [rects addObject:[NSValue valueWithRect:currentRect]];
    }
    
    for(NSValue *value in rects) {
        NSBezierPath *path = [NSBezierPath bezierPathWithRect:value.rectValue];
        
        [gradient drawInBezierPath:path angle:90];
    }
}

@end

@implementation LXSplitView

- (NSColor *)dividerColor {
    return [NSColor colorWithCalibratedWhite:0.18 alpha:1];
}

@end

#define LOCAL_REORDER_PASTEBOARD_TYPE @"MyCustomOutlineViewPboardType"

@protocol NSOutlineViewDeleteKeyDelegate
- (void)outlineView:(NSOutlineView *)outlineView deleteRow:(NSInteger)row;
@end

@interface NSOutlineView(DeleteKey)
@end

@implementation NSOutlineView(DeleteKey)
- (void)keyDown:(NSEvent *)event {
    
    if([[event characters] isEqualToString:@""]) return;
    
    unichar firstChar = [[event characters] characterAtIndex:0];
    
    if (!(firstChar == NSDeleteFunctionKey || firstChar == NSDeleteCharFunctionKey || firstChar == NSDeleteCharacter))
        return;
    
    if([[self delegate] respondsToSelector:@selector(outlineView:deleteRow:)])
       [(id)[self delegate] outlineView:self deleteRow:[self selectedRow]];
}

@end

@interface LXProjectWindowController()
@property (nonatomic, strong) LXClient *client;
@property (nonatomic, strong) LXServer *server;
@property (nonatomic) BOOL connecting;
@property (nonatomic) BOOL readingHeader;
@property (nonatomic) NSInteger headerReceivedBytes;
@property (nonatomic) int pendingPacketSize;
@property (nonatomic) NSInteger packetReceivedBytes;
@property (nonatomic, strong) NSMutableData *pendingData;
@property (nonatomic, strong) NSMutableData *writeBuffer;
@property (nonatomic, strong) NSArray *draggedItems;
@property (nonatomic, strong) NSMutableDictionary *cachedFileViews;
@property (nonatomic, strong) NSArray *localVariables;
@property (nonatomic, strong) LXLuaVariable *globalTable;
@end

@implementation LXProjectWindowController

- (id)initWithWindow:(NSWindow *)window {
    if(self = [super initWithWindow:window]) {
        _client = [[LXClient alloc] init];
        _client.delegate = self;
        _server = [[LXServer alloc] init];
        _server.delegate = self;
        _pendingData = [[NSMutableData alloc] init];
        _writeBuffer = [[NSMutableData alloc] init];
        _cachedFileViews = [[NSMutableDictionary alloc] init];
    }
    
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    [hostTextField reloadData];
    
    NSTableColumn* tableColumn = [[projectOutlineView tableColumns] objectAtIndex:0];
	LXTextFieldCell* cell = [[LXTextFieldCell alloc] init];
	[cell setEditable:YES];
	[tableColumn setDataCell:cell];
    
    tableColumn = [[callStackView tableColumns] objectAtIndex:0];
	cell = [[LXTextFieldCell alloc] init];
	[tableColumn setDataCell:cell];
    
    tableColumn = [[localVariablesView tableColumns] objectAtIndex:0];
	LXLuaVariableCell *variableCell = [[LXLuaVariableCell alloc] init];
	[variableCell setEditable:YES];
	[tableColumn setDataCell:variableCell];
    
    [projectOutlineView registerForDraggedTypes:[NSArray arrayWithObjects:LOCAL_REORDER_PASTEBOARD_TYPE,NSTIFFPboardType, NSFilenamesPboardType, nil]];
    
    [projectOutlineView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
    [projectOutlineView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];
    
    showLocals = YES;
}

- (void)setProject:(LXProject *)project {
    _project = project;
    _project.delegate = self;
    [projectOutlineView reloadData];
    
    self.window.title = project.name;
}

- (void)reloadLocalVariables {
    [localVariablesView reloadData];
    for(LXLuaVariable *variable in self.localVariables) {
        if(showTemporariesButton.state == NSOffState && [variable isTemporary])
            continue;
        
        [self initExpansions:variable];
    }
}

- (void)reloadGlobalVariables {
    [localVariablesView reloadData];
    for(LXLuaVariable *variable in self.globalTable.children) {
        [self initExpansions:variable];
    }
}

- (void)setLocalVariables:(NSArray *)locals {
	_localVariables = locals;
	
	if(showLocals) {
		[self reloadLocalVariables];
    }
}

- (void)setGlobalTable:(LXLuaVariable *)globalTable {
    if(globalTable != _globalTable) {
        _globalTable = globalTable;
    }
    
    if(!showLocals) {
        [self reloadGlobalVariables];
    }
}

#pragma mark -LXServerDelegate

- (void)sendData:(NSData *)data {
    int length = htonl((int)[data length]);
    [self.writeBuffer appendBytes:&length length:sizeof(length)];
    [self.writeBuffer appendData:data];
    
    if(self.writeBuffer.length > 0) {
        NSInteger bytesSent = [self.client send:self.writeBuffer];
        
        if(bytesSent > 0) {
            [self.writeBuffer replaceBytesInRange:NSMakeRange(0, bytesSent) withBytes:NULL length:0];
        }
    }
}

- (void)socketDidConnect:(LXClient *)aSocket {
    self.connecting = NO;
    self.readingHeader = true;
    self.headerReceivedBytes = 0;
    self.packetReceivedBytes = 0;
    
    char *str = "{\"type\":\"request\",\"command\":\"scripts\"}";
    NSData *data = [NSData dataWithBytes:str length:strlen(str)+1];
    
    [self sendData:data];
    
    connectionIndicator.hidden = YES;
    [connectionIndicator stopAnimation:nil];
    connectionLabel.stringValue = @"Connected";
    
    //scriptsProgressContainer.hidden = NO;
    //[scriptsProgressIndicator startAnimation:nil];
    
    [connectButton setTitle:@"Disconnect"];
    [connectButton setAction:@selector(disconnect:)];
    
    [hostTextField setStringValue:self.client.hostAddress];
    [portTextField setStringValue:[NSString stringWithFormat:@"%d", self.client.hostPort]];
    
    //[playButton setEnabled:YES];
    
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
        if([[dictionary objectForKey:@"host"] isEqualToString:self.client.hostAddress] && [[dictionary objectForKey:@"port"] unsignedShortValue] == self.client.hostPort) {
            found = YES;
            break;
        }
    }
    
    
    if(!found) {
        [mutableArray addObject:@{@"host" : self.client.hostAddress, @"port" : @(self.client.hostPort)}];
        
        if([mutableArray count] >= 5) {
            [mutableArray removeObjectsInRange:NSMakeRange(0, [mutableArray count]-5)];
        }
        
        [[NSUserDefaults standardUserDefaults] setObject:mutableArray forKey:@"cachedHosts"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        [hostTextField reloadData];
    }
}

- (void)socket:(LXClient *)socket willCloseWithError:(NSError *)error {
    if(self.connecting) {
        self.connecting = NO;
        
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

- (NSInteger)socket:(LXClient *)socket didReceiveData:(NSData *)data {
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

- (void)socketCanSend:(LXClient *)aSocket {
    if(self.writeBuffer.length > 0) {
        NSInteger bytesSent = [self.client send:self.writeBuffer];
        
        if(bytesSent > 0) {
            [self.writeBuffer replaceBytesInRange:NSMakeRange(0, bytesSent) withBytes:NULL length:0];
        }
    }
}

- (void)server:(LXServer *)server willCloseWithError:(NSError *)error {
    NSLog(@"CLOSED");
}

- (void)server:(LXServer *)server clientConnected:(LXClient *)client {
    NSLog(@"Connected!");
    
    self.client.delegate = nil;
    self.client = client;
    self.client.delegate = self;
}

- (void)processData:(NSData *)data {
    NSDictionary *dictionary = [data JSONValue];
    NSString *type = [dictionary objectForKey:@"type"];
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

#pragma mark - NSOutlineViewDataSource

- (void)initExpansions:(LXLuaVariable *)variable {
    BOOL expanded = variable.expanded;
    
    if([variable.children count] > 0) {
        [localVariablesView expandItem:variable];
        
        for(LXLuaVariable *child in variable.children) {
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

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    if(outlineView == localVariablesView) {
        if([item isKindOfClass:[LXLuaVariable class]]) {
            LXLuaVariable *var = item;
            
            if(var.type == LXLuaVariableTypeTable) {
                NSArray *children = var.children ? var.children : [self.project.tablesDictionary objectForKey:var.value];
                
                return ([children count] > 0);
            }
        }
    }
    else if(outlineView == projectOutlineView) {
        if([item isKindOfClass:[LXProjectGroup class]])
            return YES;
    }
    
    return NO;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)theColumn item:(id)item {
    return YES;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldExpandItem:(id)item {
    if(outlineView == localVariablesView) {
        if([item isKindOfClass:[LXLuaVariable class]]) {
            LXLuaVariable *var = item;
            var.expanded = YES;
        }
        
        return YES;
    }
    else if(outlineView == projectOutlineView) {
        if(item == nil || [item isKindOfClass:[LXProjectGroup class]])
            return YES;
    }
    
    return NO;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldCollapseItem:(id)item {
    if(outlineView == localVariablesView) {
        if([item isKindOfClass:[LXLuaVariable class]]) {
            LXLuaVariable *var = item;
            
            BOOL visible = YES;
            LXLuaVariable *parent = var.parent;
            
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
        
        return YES;
    }
    else if(outlineView == projectOutlineView) {
        if(item == nil || [item isKindOfClass:[LXProjectGroup class]])
            return YES;
    }
    
    return NO;
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
                    
                    for(LXLuaVariable *var in self.localVariables) {
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
        else if([item isKindOfClass:[LXLuaVariable class]]) {
            LXLuaVariable *var = item;
            
            if(var.type == LXLuaVariableTypeTable) {
                NSArray *children = var.children ? var.children : [self.project.tablesDictionary objectForKey:var.value];
                
                return [children count];
            }
        }
    }
    else if(outlineView == projectOutlineView) {
        if(item == nil)
            return [self.project.root.children count];
        
        if([item isKindOfClass:[LXProjectGroup class]]) {
            return [[item children] count];
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
                    
                    for(LXLuaVariable *var in self.localVariables) {
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
        
        if([item isKindOfClass:[LXLuaVariable class]]) {
            LXLuaVariable *var = item;
            
            if(var.type == LXLuaVariableTypeTable) {
                if(!var.children) {
                    NSArray *children = [self.project.tablesDictionary objectForKey:var.value];
                    NSArray *childrenCopy = [[NSArray alloc] initWithArray:children copyItems:YES];
                    var.children = childrenCopy;
                }
                
                return [var.children objectAtIndex:index];
            }
        }
    }
    else if(outlineView == projectOutlineView) {
        if(item == nil)
            return self.project.root.children[index];

        if([item isKindOfClass:[LXProjectGroup class]]) {
            return [item children][index];
        }
    }

    return nil;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)theColumn byItem:(id)item {
    if(outlineView == localVariablesView) {
        if([item isKindOfClass:[LXLuaVariable class]]) {
            LXLuaVariable *var = item;
            
            return var;
        }
    }
    else if(outlineView == projectOutlineView) {
        return [item name];
    }
    
    return nil;
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)theColumn byItem:(id)item {
    if(outlineView == localVariablesView) {
        LXLuaVariableCell *cell = [theColumn dataCellForRow:[outlineView rowForItem:item]];
        
        if([cell.stringValue isEqualToString:object])
            return;
        
        if([item isKindOfClass:[LXLuaVariable class]]) {
            LXLuaVariable *var = item;
            NSMutableArray *indices = [NSMutableArray array];;
            
            while(var.parent != nil) {
                [indices addObject:var.key];
                
                var = var.parent;
            }
            
            if(var.scope == LXLuaVariableScopeLocal) {
                [self.project setLocalValue:[NSString stringWithFormat:@"return %@", object] where:var.where index:var.index indices:indices];
            }
            /*else if(var.scope == LXLuaVariableScopeUpvalue) {
                NSData *data = [[NSString stringWithFormat:@"{\"type\":\"request\",\"command\":\"setupvalue\",\"indices\":[%@],\"where\":%d,\"index\":%d,\"value\":%@}", indices, (int)var.where, (int)var.index, [self toQuotedString:[NSString stringWithFormat:@"return %@", object]]] dataUsingEncoding:NSUTF8StringEncoding];
                [self sendData:data];
            }
            else if(var.scope == LXLuaVariableScopeGlobal) {
                NSData *data = [[NSString stringWithFormat:@"{\"type\":\"request\",\"command\":\"setglobal\",\"indices\":[%@],\"value\":%@}", indices, [self toQuotedString:[NSString stringWithFormat:@"return %@", object]]] dataUsingEncoding:NSUTF8StringEncoding];
                [self sendData:data];
            }*/
            
            //[localVariablesView reloadItem:item];
        }
    }
    else if(outlineView == projectOutlineView) {
        [self.project setFileName:item name:object];
    }
}

- (void)outlineViewSelectionDidChange:(NSNotification *)aNotification {
    if(aNotification.object == projectOutlineView) {
        LXProjectFileReference *item = [projectOutlineView itemAtRow:[projectOutlineView selectedRow]];
        
        if([[projectOutlineView selectedRowIndexes] count] == 1 && [item class] == [LXProjectFileReference class]) {
            LXProjectFileView *fileView = self.cachedFileViews[@((NSInteger)item.file)];
            
            if(!fileView) {
                fileView = [[LXProjectFileView alloc] initWithContentView:contentView file:item.file];
                fileView.delegate = self;
                self.cachedFileViews[@((NSInteger)item.file)] = fileView;
            }
            
            [contentView setSubviews:@[fileView]];
            [fileView resizeViews];
        }
    }
}

- (void)outlineView:(NSOutlineView *)outlineView deleteRow:(NSInteger)row {
    if(outlineView == projectOutlineView) {
        LXProjectFileReference *item = [projectOutlineView itemAtRow:row];
        
        [self.cachedFileViews removeObjectForKey:@((NSInteger)item.file)];
        [self.project removeFile:item];
        [projectOutlineView reloadData];
    }
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayOutlineCell:(NSButtonCell *)cell forTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    //[cell setImage:[[NSImage alloc] initWithSize:NSZeroSize]];
    //[cell setAlternateImage:[[NSImage alloc] initWithSize:NSZeroSize]];
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(LXTextFieldCell *)cell forTableColumn:(NSTableColumn *)tableColumn item:(LXProjectFileReference *)item {
    BOOL selected = [outlineView isRowSelected:[outlineView rowForItem:item]];
    
    [cell setSelected:selected];
    
    if(selected) {
        [cell setTextColor:[NSColor whiteColor]];
    }
    else {
        [cell setTextColor:[NSColor colorWithCalibratedWhite:0.8 alpha:1]];
    }
    
    if(outlineView == projectOutlineView) {
        LXProjectFileView *fileView = self.cachedFileViews[@((NSInteger)item.file)];
        
        [cell setModified:fileView.modified];
    
        if([item isKindOfClass:[LXProjectGroup class]]) {
            [cell setImage:[NSImage imageNamed:@"foldericon.png"]];
            [cell setFont:[NSFont boldSystemFontOfSize:12]];
            [cell setAccessoryImage:nil];
        }
        else {
            [cell setImage:[NSImage imageNamed:@"scripticon.png"]];
            [cell setFont:[NSFont systemFontOfSize:12]];

            if([item.file isCompiled]) {
                [cell setAccessoryImage:[NSImage imageNamed:@"checkicon.png"]];
            }
            else if([item.file hasErrors]) {
                [cell setAccessoryImage:[NSImage imageNamed:@"erroricon.png"]];
            }
            else {
                [cell setAccessoryImage:[NSImage imageNamed:@"warningicon.png"]];
            }
        }
    }
}

- (BOOL)outlineView:(NSOutlineView *)outlineView writeItems:(NSArray *)items toPasteboard:(NSPasteboard *)pasteboard {
    return YES;
}

- (void)outlineView:(NSOutlineView *)outlineView draggingSession:(NSDraggingSession *)session willBeginAtPoint:(NSPoint)screenPoint forItems:(NSArray *)draggedItems {
    
    self.draggedItems = draggedItems;
    
    [session.draggingPasteboard setData:[NSData data] forType:LOCAL_REORDER_PASTEBOARD_TYPE];
}

- (BOOL)treeNode:(LXProjectFileReference *)treeNode isDescendantOfNode:(LXProjectGroup *)parentNode {
    while(treeNode != nil) {
        if(treeNode == parentNode) {
            return YES;
        }
        
        treeNode = treeNode.parent;
    }
    
    return NO;
}

- (void)outlineView:(NSOutlineView *)outlineView draggingSession:(NSDraggingSession *)session endedAtPoint:(NSPoint)screenPoint operation:(NSDragOperation)operation {
    
    if(operation == NSDragOperationDelete) {
        NSMutableArray *validDraggedItems = [NSMutableArray array];
        
        for(LXProjectFileReference *file in self.draggedItems) {
            
            BOOL isValid = YES;
            
            for(LXProjectFileReference *otherFile in self.draggedItems) {
                if(file == otherFile || ![otherFile isKindOfClass:[LXProjectGroup class]])
                    continue;
                
                if([self treeNode:file isDescendantOfNode:(LXProjectGroup *)otherFile]) {
                    isValid = NO;
                    break;
                }
            }
            
            if(isValid)
                [validDraggedItems addObject:file];
        }
        
        [projectOutlineView beginUpdates];
        
        [validDraggedItems enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(LXProjectFileReference *file, NSUInteger index, BOOL *stop) {
            LXProjectGroup *parent = [file parent];
            
            NSInteger childIndex = [parent.children indexOfObject:file];
            
            [self.project removeFile:file];
            
            [projectOutlineView removeItemsAtIndexes:[NSIndexSet indexSetWithIndex:childIndex] inParent:parent == self.project.root ? nil : parent withAnimation:NSTableViewAnimationEffectFade];
        }];
        
        [projectOutlineView endUpdates];
    }
    
    self.draggedItems = nil;
}

- (NSDragOperation)outlineView:(NSOutlineView *)ov validateDrop:(id <NSDraggingInfo>)info proposedItem:(id)item proposedChildIndex:(NSInteger)childIndex {
    NSDragOperation result = NSDragOperationGeneric;
    NSPasteboard *pasteboard = [info draggingPasteboard];
    
    if([[pasteboard types] containsObject:LOCAL_REORDER_PASTEBOARD_TYPE]) {
        if(result != NSDragOperationNone) {
            info.animatesToDestination = YES;
            
            LXProjectFileReference *targetNode = item;
            
            if([targetNode class] == [LXProjectFileReference class]) {
                result = NSDragOperationNone;
            }
            else {
                for(LXProjectFileReference *draggedNode in self.draggedItems) {
                    if([draggedNode isKindOfClass:[LXProjectGroup class]] &&
                       [self treeNode:targetNode isDescendantOfNode:(LXProjectGroup *)draggedNode]) {
                        result = NSDragOperationNone;
                        break;
                    }
                }
            }
        }
    }
    else {
        if([[pasteboard types] containsObject:NSFilenamesPboardType]) {
            NSArray *files = [pasteboard propertyListForType:NSFilenamesPboardType];
            
            if([files count] != 1)
                result = NSDragOperationNone;
        }
        
        if((NSDragOperationGeneric & [info draggingSourceOperationMask]) == NSDragOperationGeneric) {
            result = NSDragOperationCopy;
        }
    }
    
    return result;
}

- (BOOL)outlineView:(NSOutlineView *)ov acceptDrop:(id <NSDraggingInfo>)info item:(id)item childIndex:(NSInteger)childIndex {
    NSPasteboard *pasteboard = [info draggingPasteboard];
    LXProjectGroup *targetNode = item ?  item : self.project.root;
    
    if(childIndex == NSOutlineViewDropOnItemIndex) {
        childIndex = 0;
    }
    
    if([[pasteboard types] containsObject:LOCAL_REORDER_PASTEBOARD_TYPE]) {
        [projectOutlineView beginUpdates];
        // We want to enumerate all things in the pasteboard. To do that, we use a generic NSPasteboardItem class
        NSArray *classes = [NSArray arrayWithObject:[NSPasteboardItem class]];
        
        __block NSInteger insertionIndex = childIndex;
        
        [self.draggedItems enumerateObjectsUsingBlock:^(id object, NSUInteger index, BOOL *stop) {
            LXProjectFileReference *draggedTreeNode = object;
            LXProjectGroup *oldParent = draggedTreeNode.parent;
            
            NSInteger oldIndex = [oldParent.children indexOfObject:draggedTreeNode];
            
            [projectOutlineView removeItemsAtIndexes:[NSIndexSet indexSetWithIndex:oldIndex] inParent:oldParent == self.project.root ? nil : oldParent withAnimation:NSTableViewAnimationEffectNone];
            
            if(oldParent == targetNode) {
                if(insertionIndex > oldIndex) {
                    insertionIndex--; // account for the remove
                }
            }
            
            [projectOutlineView insertItemsAtIndexes:[NSIndexSet indexSetWithIndex:insertionIndex] inParent:targetNode == self.project.root ? nil : targetNode withAnimation:NSTableViewAnimationEffectGap];
            
            [self.project insertFile:draggedTreeNode parent:targetNode atIndex:insertionIndex];
            
            insertionIndex++;
        }];
        
        NSInteger outlineColumnIndex = [[projectOutlineView tableColumns] indexOfObject:[projectOutlineView outlineTableColumn]];
        
        [info enumerateDraggingItemsWithOptions:0 forView:projectOutlineView classes:classes searchOptions:nil usingBlock:^(NSDraggingItem *draggingItem, NSInteger index, BOOL *stop) {
            NSTreeNode *draggedTreeNode = [self.draggedItems objectAtIndex:index];
            
            NSInteger row = [projectOutlineView rowForItem:draggedTreeNode];
            
            draggingItem.draggingFrame = [projectOutlineView frameOfCellAtColumn:outlineColumnIndex row:row];
        }];
        
        [projectOutlineView endUpdates];
    }
    else {
    
    }
    
    return YES;
}

#pragma mark - NSTableViewDataSource

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView {
    return [self.project.callStack count];
	
	return 0;
}

- (id)tableView:(NSTableView *)tableView objectValueForTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    LXLuaCallStackIndex *index = self.project.callStack[row];
    return [NSString stringWithFormat:@"%ld %@:%@: line %ld", row, index.source, index.function, index.originalLine];
}

- (void)tableView:(NSTableView *)tableView willDisplayCell:(id)cell forTableColumn:(NSTableColumn *)tableColumn row:(NSInteger)row {
    BOOL selected = [tableView isRowSelected:row];
    
    [cell setSelected:selected];
    
    if(selected) {
        [cell setTextColor:[NSColor whiteColor]];
    }
    else {
        [cell setTextColor:[NSColor colorWithCalibratedWhite:0.8 alpha:1]];
    }
}

#pragma mark - NSTableViewDelegate

- (void)setCurrentCallStackIndex:(NSInteger)idx {
    if(idx != -1) {
        LXLuaCallStackIndex *index = self.project.callStack[idx];
        
        __block LXProjectFile *file = nil;
        
        [self.project.files indexOfObjectPassingTest:^BOOL(LXProjectFile *obj, NSUInteger idx, BOOL *stop) {
            if([[obj.name stringByDeletingPathExtension] isEqualToString:[index.source stringByDeletingPathExtension]]) {
                file = obj;
                return YES;
            }
            
            return NO;
        }];
        
        if(file) {
            LXProjectFileView *fileView = self.cachedFileViews[@((NSInteger)file)];
            
            if(!fileView) {
                fileView = [[LXProjectFileView alloc] initWithContentView:contentView file:file];
                fileView.delegate = self;
                self.cachedFileViews[@((NSInteger)file)] = fileView;
            }
            
            [contentView setSubviews:@[fileView]];
            [fileView resizeViews];
            
            [fileView.textView setHighlightedLine:index.originalLine];
            
            if(index.error) {
                [fileView.textView setHighlightedLineColor:[NSColor redColor] background:[NSColor colorWithDeviceRed:1.0f green:0.8f blue:0.8f alpha:1.0f]];
            }
            else {
                [fileView.textView setHighlightedLineColor:[NSColor blueColor] background:[NSColor colorWithDeviceRed:0.8f green:0.8f blue:1.0f alpha:1.0f]];
            }
        }
        
        self.localVariables = [index.upVariables arrayByAddingObjectsFromArray:index.localVariables];
    }
}

- (BOOL)tableView:(NSTableView *)aTableView shouldEditTableColumn:(NSTableColumn *)aTableColumn row:(NSInteger)rowIndex {
	return NO;
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    NSInteger idx = [callStackView selectedRow];
    
    [self setCurrentCallStackIndex:idx];
}

#pragma mark - NSSplitViewDelegate 

- (BOOL)splitView:(NSSplitView *)splitView canCollapseSubview:(NSView *)subview {
    if(splitView == horizontalSplitView) {
        return NO;
    }
    else if(splitView == verticalSplitView) {
        return subview == debugContainerView;
    }
    
    return NO;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMinCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex {
    if(splitView == horizontalSplitView) {
        return proposedMinimumPosition + 150.0f;
    }
    else if(splitView == contentSplitView) {
        return proposedMinimumPosition + 400.0f;
    }
    else if(splitView == verticalSplitView) {
        return proposedMinimumPosition + 400.0f;
    }
    
    return proposedMinimumPosition;
}

- (CGFloat)splitView:(NSSplitView *)splitView constrainMaxCoordinate:(CGFloat)proposedMinimumPosition ofSubviewAt:(NSInteger)dividerIndex {
    if(splitView == horizontalSplitView) {
        return proposedMinimumPosition - 400.0f;
    }
    else if(splitView == contentSplitView) {
        return proposedMinimumPosition - 150.0f;
    }
    else if(splitView == verticalSplitView) {
        return proposedMinimumPosition - 200.0f;
    }

    return proposedMinimumPosition;
}

- (void)splitView:(NSSplitView *)splitView resizeSubviewsWithOldSize:(NSSize)oldSize {
    if(splitView == horizontalSplitView) {
        CGFloat dividerThickness = [splitView dividerThickness];
        NSRect frame = [splitView frame];
        
        NSView *leftView = [splitView subviews][0];
        NSView *rightView = [splitView subviews][1];
        
        CGFloat rightWidth = MAX(frame.size.width-leftView.frame.size.width-dividerThickness, 400.0f);
        CGFloat leftWidth = frame.size.width-rightWidth-dividerThickness;
        
        leftView.frame = NSMakeRect(0, 0, leftWidth, frame.size.height);
        rightView.frame = NSMakeRect(leftWidth+dividerThickness, 0, rightWidth, frame.size.height);
    }
    else if(splitView == contentSplitView) {
        CGFloat dividerThickness = [splitView dividerThickness];
        NSRect frame = [splitView frame];
        
        NSView *leftView = [splitView subviews][0];
        NSView *rightView = [splitView subviews][1];
        
        CGFloat leftWidth = MAX(frame.size.width-rightView.frame.size.width-dividerThickness, 400.0f);
        CGFloat rightWidth = frame.size.width-leftWidth-dividerThickness;
        
        leftView.frame = NSMakeRect(0, 0, leftWidth, frame.size.height);
        rightView.frame = NSMakeRect(leftWidth+dividerThickness, 0, rightWidth, frame.size.height);
    }
    else if(splitView == verticalSplitView) {
        [splitView adjustSubviews];
    }
}

- (void)splitViewDidResizeSubviews:(NSNotification *)notification {
    NSSplitView *splitView = notification.object;
    
    if(splitView == verticalSplitView) {
        NSView *bottomView = [splitView subviews][1];
        showDebugContainerButton.frameCenterRotation = bottomView.isHidden ? 180 : 0;
    }
}

#pragma mark - LXProjectDelegate

- (void)project:(LXProject *)project didLogMessage:(NSString *)message {
    NSFontManager *fontManager = [NSFontManager sharedFontManager];
    NSFont *font = [fontManager fontWithFamily:@"Menlo"
                                        traits:NSBoldFontMask
                                        weight:0
                                          size:11];
    
    NSAttributedString *attributedMessage = [[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@"%@\n", message] attributes:@{NSForegroundColorAttributeName : [NSColor colorWithCalibratedWhite:0.8 alpha:1], NSFontAttributeName : font}];
    [[consoleView textStorage] appendAttributedString:attributedMessage];
    
    NSRange range = NSMakeRange([[consoleView string] length], 0);
    [consoleView scrollRangeToVisible:range];
}

- (void)project:(LXProject *)project file:(LXProjectFile *)file didBreakAtLine:(NSInteger)line error:(BOOL)error {
    NSInteger lastSelectedRow = callStackView.selectedRow;
    
    [callStackView reloadData];
    
    if([self.project.callStack count]) {
        NSInteger selectedRow = callStackView.selectedRow;
        
        if(lastSelectedRow == 0) {
            [self setCurrentCallStackIndex:lastSelectedRow];
        }
        else if(selectedRow != 0) {
            [callStackView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
        }
    }
    
    self.globalTable = project.globalTable;
    
    BOOL hidden = [debugContainerView isHidden];
    
    if(hidden) {
        [self showHideDebugContainer:showDebugContainerButton];
    }
    
    [consoleView setEditable:YES];
    [continueButton setEnabled:YES];
    [continueButton setImage:[NSImage imageNamed:@"resume_co.png"]];
    [continueButton setAction:@selector(continueExecution:)];
    [stepOverButton setEnabled:YES];
    [stepIntoButton setEnabled:YES];
    [stepOutButton setEnabled:YES];
}

- (void)projectFinishedRunning:(LXProject *)project {
    [self clearHighlightedLines];
    
    [consoleView setEditable:NO];
    [continueButton setEnabled:NO];
    [continueButton setImage:[NSImage imageNamed:@"suspend_co.png"]];
    [stepOverButton setEnabled:NO];
    [stepIntoButton setEnabled:NO];
    [stepOutButton setEnabled:NO];
    
    [callStackView reloadData];
    self.globalTable = nil;
    self.localVariables = nil;
}

- (void)projectFinishedRunningString:(LXProject *)project {
    [consoleView setEditable:YES];
    
    NSInteger lastSelectedRow = callStackView.selectedRow;
    
    [callStackView reloadData];
    
    if([self.project.callStack count]) {
        [self setCurrentCallStackIndex:lastSelectedRow];
    }
    
    self.globalTable = project.globalTable;
}

#pragma mark - LXProjectFileViewDelegate

- (void)fileWasModified:(LXProjectFileView *)file modified:(BOOL)modifier {
    [projectOutlineView reloadItem:file.file reloadChildren:NO];
    [projectOutlineView setNeedsDisplay];
}

#pragma mark - LXConsoleTextViewDelegate

- (void)consoleView:(LXConsoleTextView *)aConsoleView didEnterString:(NSString *)string {
    [consoleView setEditable:NO clearText:NO];
    [self.project runString:string];
}

#pragma mark - actions

- (BOOL)validateMenuItem:(NSMenuItem *)menuItem {
    if([menuItem.title isEqualToString:@"Stop"])
        return [self.project isRunning];
    
    return YES;
}

- (IBAction)connect:(id)sender {
    self.connecting = YES;
    
    self.readingHeader = true;
    self.headerReceivedBytes = 0;
    self.packetReceivedBytes = 0;
    
    NSString *host = [[hostTextField stringValue] length] > 0 ? [hostTextField stringValue] : @"localhost";
    unsigned short port = [[portTextField stringValue] length]  > 0 ? [portTextField intValue] : 3632;
    
    [self.client connect:host port:port];
    
    connectionIndicator.hidden = NO;
    [connectionIndicator startAnimation:nil];
    connectionLabel.stringValue = @"Connecting...";
}

- (IBAction)disconnect:(id)sender {
    [self.client close];
    
    self.connecting = NO;
    
    self.readingHeader = true;
    self.headerReceivedBytes = 0;
    self.packetReceivedBytes = 0;
    
    connectionIndicator.hidden = YES;
    [connectionIndicator stopAnimation:nil];
    connectionLabel.stringValue = @"Disconnected";
    
    //[scriptEditObjects removeAllObjects];
    //[scriptsTableView reloadData];
    
    //[breakpointsDictionary removeAllObjects];
    //[breakpointsView reloadData];
    
    //self.callStack = nil;
    //self.localVariables = nil;
    //self.globalTable = nil;
    
    //[playButton setImage:[NSImage imageNamed:@"suspend_co.png"]];
	//[playButton setAction:@selector(pause:)];
    //[playButton setEnabled:NO];
	//[stepIntoButton setEnabled:NO];
	//[stepOverButton setEnabled:NO];
	//[stepOutButton setEnabled:NO];
    
    [connectButton setTitle:@"Connect"];
    [connectButton setAction:@selector(connect:)];
}

- (IBAction)newScript:(id)sender {
    id item = [projectOutlineView itemAtRow:[projectOutlineView selectedRow]];

    LXProjectGroup *parent = nil;
    NSInteger index = 0;
    
    if([item isKindOfClass:[LXProjectGroup class]]) {
        parent = item;
        index = [parent.children count];
    }
    else if([item isKindOfClass:[LXProjectFileReference class]]) {
        parent = [(LXProjectFileReference *)item parent];
        index = [parent.children indexOfObject:item]+1;
    }
    else {
        parent = self.project.root;
        index = [parent.children count];
    }
    
    LXProjectFileReference *file = [self.project insertFile:parent atIndex:index];
    [projectOutlineView expandItem:parent];
    [projectOutlineView reloadItem:nil reloadChildren:YES];
    [projectOutlineView editColumn:0 row:[projectOutlineView rowForItem:file] withEvent:nil select:YES];
}

- (IBAction)newGroup:(id)sender {
    id item = [projectOutlineView itemAtRow:[projectOutlineView selectedRow]];
    
    LXProjectGroup *parent = nil;
    NSInteger index = 0;

    if([item isKindOfClass:[LXProjectGroup class]]) {
        parent = item;
        index = [parent.children count];
    }
    else if([item isKindOfClass:[LXProjectFileReference class]]) {
        parent = [(LXProjectFileReference *)item parent];
        index = [parent.children indexOfObject:item]+1;
    }
    else {
        parent = self.project.root;
        index = [parent.children count];
    }
    
    LXProjectGroup *group = [self.project insertGroup:parent atIndex:index];
    [projectOutlineView expandItem:parent];
    [projectOutlineView reloadItem:nil reloadChildren:YES];
    [projectOutlineView editColumn:0 row:[projectOutlineView rowForItem:group] withEvent:nil select:YES];
}

- (IBAction)save:(id)sender {
    LXProjectFileReference *item = [projectOutlineView itemAtRow:[projectOutlineView selectedRow]];
    LXProjectFileView *fileView = self.cachedFileViews[@((NSInteger)item.file)];
    
    [fileView save];
}

- (IBAction)compile:(id)sender {
    for(LXProjectFileView *fileView in [self.cachedFileViews allValues]) {
        [fileView save];
    }
    
    [self.project compile];
    [projectOutlineView reloadData];
}

- (IBAction)clean:(id)sender {
    [self.project clean];
    [projectOutlineView reloadData];
}

- (IBAction)run:(id)sender {
    for(LXProjectFileView *fileView in [self.cachedFileViews allValues]) {
        [fileView save];
    }
    
    [projectOutlineView reloadData];
    [self clearHighlightedLines];
    [self.project run];
    
    [continueButton setEnabled:YES];
    [continueButton setAction:@selector(pauseExecution:)];
    [continueButton setImage:[NSImage imageNamed:@"suspend_co.png"]];
}

- (void)clearHighlightedLines {
    for(LXProjectFileView *fileView in [self.cachedFileViews allValues]) {
        [fileView.textView setHighlightedLine:-1];
    }
}

- (IBAction)stopExecution:(id)sender {
    [self clearHighlightedLines];
    [self.project stopExecution];
}

- (IBAction)continueExecution:(id)sender {
    [self clearHighlightedLines];
    [self.project continueExecution];
    
    [consoleView setEditable:NO];
    [continueButton setEnabled:YES];
    [continueButton setAction:@selector(pauseExecution:)];
    [continueButton setImage:[NSImage imageNamed:@"suspend_co.png"]];
    [stepOverButton setEnabled:NO];
    [stepIntoButton setEnabled:NO];
    [stepOutButton setEnabled:NO];
    
    [callStackView reloadData];
    self.globalTable = nil;
    self.localVariables = nil;
}

- (IBAction)pauseExecution:(id)sender {
    [self clearHighlightedLines];
    [self.project pauseExecution];
    
    [consoleView setEditable:NO];
    [continueButton setEnabled:NO];
    [stepOverButton setEnabled:NO];
    [stepIntoButton setEnabled:NO];
    [stepOutButton setEnabled:NO];
}

- (IBAction)stepInto:(id)sender {
    [self clearHighlightedLines];
    [self.project stepInto];
    
    [consoleView setEditable:NO];
    [continueButton setEnabled:NO];
    [stepOverButton setEnabled:NO];
    [stepIntoButton setEnabled:NO];
    [stepOutButton setEnabled:NO];
}

- (IBAction)stepOver:(id)sender {
    [self clearHighlightedLines];
    [self.project stepOver];
    
    [consoleView setEditable:NO];
    [continueButton setEnabled:NO];
    [stepOverButton setEnabled:NO];
    [stepIntoButton setEnabled:NO];
    [stepOutButton setEnabled:NO];
}

- (IBAction)stepOut:(id)sender {
    [self clearHighlightedLines];
    [self.project stepOut];
    
    [consoleView setEditable:NO];
    [continueButton setEnabled:NO];
    [stepOverButton setEnabled:NO];
    [stepIntoButton setEnabled:NO];
    [stepOutButton setEnabled:NO];
}

- (IBAction)showHideDebugContainer:(NSButton *)sender {
    NSSplitView *splitView = (NSSplitView *)[debugContainerView superview];
    NSView *topSubview = [[splitView subviews] objectAtIndex:0];
    NSView *bottomSubview = [[splitView subviews] objectAtIndex:1];
    
    BOOL hidden = [debugContainerView isHidden];
    
    if(hidden) {
        [debugContainerView setHidden:NO];
        [splitView adjustSubviews];
        
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            [context setDuration:0.3];
            [context setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
            [[topSubview animator] setFrame:NSMakeRect(topSubview.frame.origin.x, 200, topSubview.frame.size.width, splitView.frame.size.height-200)];
            [[bottomSubview animator] setFrame:NSMakeRect(bottomSubview.frame.origin.x, bottomSubview.frame.origin.y, bottomSubview.frame.size.width, 200)];
        } completionHandler:^{
            sender.frameCenterRotation = 0;
        }];
    }
    else {
        [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
            [context setDuration:0.3];
            [context setTimingFunction:[CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut]];
            [[topSubview animator] setFrame:NSMakeRect(topSubview.frame.origin.x, 1, topSubview.frame.size.width, splitView.frame.size.height-1)];
            [[bottomSubview animator] setFrame:NSMakeRect(bottomSubview.frame.origin.x, bottomSubview.frame.origin.y, bottomSubview.frame.size.width, 1)];
        } completionHandler:^{
            [debugContainerView setHidden:YES];
            sender.frameCenterRotation = 180;
            [splitView adjustSubviews];
        }];
    }
}

@end
