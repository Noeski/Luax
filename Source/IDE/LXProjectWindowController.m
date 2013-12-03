//
//  LXWindowController.m
//  Luax
//
//  Created by Noah Hilt on 11/24/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXProjectWindowController.h"
#import "LXImageTextFieldCell.h"
#import "NSString+JSON.h"

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
	LXImageTextFieldCell* cell = [[LXImageTextFieldCell alloc] init];
	[cell setEditable:YES];
	[tableColumn setDataCell:cell];
    
    [projectOutlineView registerForDraggedTypes:[NSArray arrayWithObjects:LOCAL_REORDER_PASTEBOARD_TYPE,NSTIFFPboardType, NSFilenamesPboardType, nil]];
    
    [projectOutlineView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:YES];
    [projectOutlineView setDraggingSourceOperationMask:NSDragOperationEvery forLocal:NO];
}

- (void)setProject:(LXProject *)project {
    _project = project;
    [projectOutlineView reloadData];
    
    self.window.title = project.name;
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

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    if([item isKindOfClass:[LXProjectGroup class]])
        return YES;
    
    return NO;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)theColumn item:(id)item {
    return YES;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldExpandItem:(id)item {
    if(item == nil || [item isKindOfClass:[LXProjectGroup class]])
        return YES;
    
    return NO;
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldCollapseItem:(id)item {
    if(item == nil || [item isKindOfClass:[LXProjectGroup class]])
        return YES;
    
    return NO;
}

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    if(item == nil)
        return [self.project.root.children count];
    
    if([item isKindOfClass:[LXProjectGroup class]]) {
        return [[item children] count];
    }
    
    return 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item {
    if(item == nil)
        return self.project.root.children[index];
    
    if([item isKindOfClass:[LXProjectGroup class]]) {
        return [item children][index];
    }

    return nil;
}

- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)theColumn byItem:(id)item {
    return [item name];
}

- (void)outlineView:(NSOutlineView *)outlineView setObjectValue:(id)object forTableColumn:(NSTableColumn *)theColumn byItem:(id)item {
    [self.project setFileName:item name:object];
}

- (void)outlineViewSelectionDidChange:(NSNotification *)aNotification {
    LXProjectFileReference *item = [projectOutlineView itemAtRow:[projectOutlineView selectedRow]];
    
    if([[projectOutlineView selectedRowIndexes] count] == 1 && [item class] == [LXProjectFileReference class]) {
        LXProjectFileView *fileView = self.cachedFileViews[@((NSInteger)item.file)];
        
        if(!fileView) {
            fileView = [[LXProjectFileView alloc] initWithContentView:contentView file:item];
            fileView.delegate = self;
            self.cachedFileViews[@((NSInteger)item.file)] = fileView;
        }
        
        [contentView setSubviews:@[fileView]];
        [fileView resizeViews];
    }
}

- (void)outlineView:(NSOutlineView *)outlineView deleteRow:(NSInteger)row {
    LXProjectFileReference *item = [projectOutlineView itemAtRow:row];
    
    [self.cachedFileViews removeObjectForKey:@((NSInteger)item.file)];
    [self.project removeFile:item];
    [projectOutlineView reloadData];
}

- (void)outlineView:(NSOutlineView *)outlineView willDisplayCell:(LXImageTextFieldCell *)cell forTableColumn:(NSTableColumn *)tableColumn item:(LXProjectFileReference *)item {
    LXProjectFileView *fileView = self.cachedFileViews[@((NSInteger)item.file)];
    
    [cell setModified:fileView.modified];
    
    if([item isKindOfClass:[LXProjectGroup class]]) {
        [cell setImage:[NSImage imageNamed:@"foldericon.png"]];
        [cell setAccessoryImage:nil];
    }
    else {
        [cell setImage:[NSImage imageNamed:@"scripticon.png"]];
        
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

#pragma mark - LXProjectFileViewDelegate

- (void)fileWasModified:(LXProjectFileView *)file modified:(BOOL)modifier {
    [projectOutlineView reloadItem:file.file reloadChildren:NO];
}

#pragma mark - actions

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

@end
