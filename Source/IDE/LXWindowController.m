//
//  LXWindowController.m
//  Luax
//
//  Created by Noah Hilt on 11/24/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXWindowController.h"
#import "NSString+JSON.h"

@interface LXWindowController()
@property (nonatomic, strong) LXClient *client;
@property (nonatomic, strong) LXServer *server;
@property (nonatomic) BOOL connecting;
@property (nonatomic) BOOL readingHeader;
@property (nonatomic) NSInteger headerReceivedBytes;
@property (nonatomic) int pendingPacketSize;
@property (nonatomic) NSInteger packetReceivedBytes;
@property (nonatomic, strong) NSMutableData *pendingData;
@property (nonatomic, strong) NSMutableData *writeBuffer;
@end

@implementation LXWindowController

- (id)initWithWindow:(NSWindow *)window {
    if(self = [super initWithWindow:window]) {
        _client = [[LXClient alloc] init];
        _client.delegate = self;
        _server = [[LXServer alloc] init];
        _server.delegate = self;
        _pendingData = [[NSMutableData alloc] init];
        _writeBuffer = [[NSMutableData alloc] init];
    }
    
    return self;
}

- (void)windowDidLoad {
    [super windowDidLoad];
    
    [hostTextField reloadData];
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

@end
