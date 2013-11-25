//
//  LXServer.m
//  Luax
//
//  Created by Noah Hilt on 11/25/12.
//  Copyright (c) 2012 Noah Hilt. All rights reserved.
//

#include <sys/socket.h>
#include <netinet/in.h>

#import "LXServer.h"

@interface LXServer()<NSNetServiceDelegate> {
    CFSocketRef serverSocket;
}

@end

@implementation LXServer

- (id)init {
    if(self = [super init]) {
        _connections = [[NSMutableSet alloc] init];
    }
    
    return self;
}

- (void)dealloc {    
    [self close];
}

void handleConnect(CFSocketRef s, CFSocketCallBackType callbackType, CFDataRef address, const void *data, void *info) {
    if(callbackType != kCFSocketAcceptCallBack)
        return;
    
    LXServer *server = (__bridge LXServer *)info;
    
    if([server.delegate respondsToSelector:@selector(server:clientConnected:)]) {
        CFReadStreamRef readStream;
        CFWriteStreamRef writeStream;
        
        CFSocketNativeHandle handle = *(CFSocketNativeHandle *)data;
        uint8_t name[SOCK_MAXADDRLEN];
        socklen_t namelen = sizeof(name);
        NSData *peer = nil;
        if (0 == getpeername(handle, (struct sockaddr *)name, &namelen)) {
            peer = [NSData dataWithBytes:name length:namelen];
        }
        
        CFStreamCreatePairWithSocket(NULL, handle, &readStream, &writeStream);
        
        if(readStream && writeStream) {
            LXClient *client = [[LXClient alloc] init];
            [server.connections addObject:client];
            
            [client initWithReadStream:readStream writeStream:writeStream];
        
            CFRelease(readStream);
            CFRelease(writeStream);
        
            [server.delegate server:server clientConnected:client];
        }
        else {
            close(handle);
        }
    }
}

- (void)closeWithError:(NSError *)error notify:(BOOL)notify {
    if (self.listening) {
        if (self.error == nil) {
            _error = error;
        }
        
        if (notify) {
            if ([self.delegate respondsToSelector:@selector(server:willCloseWithError:)]) {
                [self.delegate server:self willCloseWithError:error];
            }
        }
        
        for(LXClient *client in _connections) {
            [client close];
        }
        
        [_connections removeAllObjects];
        
        if(serverSocket) {
            CFSocketInvalidate(serverSocket);
            CFRelease(serverSocket);
            
            serverSocket = NULL;
        }
                
        _listening = NO;
    }
}

- (void)closeWithError:(NSError *)error {
    [self closeWithError:error notify:YES];
}

- (void)listen:(unsigned short)port {
    CFSocketContext socketContext = {0, (__bridge void *)(self), nil, nil, nil};
    serverSocket = CFSocketCreate(kCFAllocatorDefault,
                                              PF_INET,
                                              SOCK_STREAM,
                                              IPPROTO_TCP,
                                              kCFSocketAcceptCallBack, handleConnect, &socketContext);
    
    if(serverSocket == NULL) {
        [self closeWithError:[NSError errorWithDomain:@"" code:0 userInfo:nil]];
        return;
    }
    
    int yes = 1;
    setsockopt(CFSocketGetNative(serverSocket), SOL_SOCKET, SO_REUSEADDR, (void *)&yes, sizeof(yes));
    
    struct sockaddr_in sin;
    
    memset(&sin, 0, sizeof(sin));
    
    sin.sin_len = sizeof(sin);
    sin.sin_family = AF_INET; /* Address family */
    sin.sin_port = htons(port); /* Or a specific port */
    sin.sin_addr.s_addr= INADDR_ANY;
    
    CFDataRef sincfd = CFDataCreate(kCFAllocatorDefault, (UInt8 *)&sin, sizeof(sin));
    
    if(CFSocketSetAddress(serverSocket, sincfd) != kCFSocketSuccess) {
        [self closeWithError:[NSError errorWithDomain:@"" code:0 userInfo:nil]];
        
        CFRelease(sincfd);
        CFRelease(serverSocket);
        return;
    }
    
    CFRelease(sincfd);
    
    CFRunLoopSourceRef socketsource = CFSocketCreateRunLoopSource(kCFAllocatorDefault,
                                                                  serverSocket,
                                                                  0);
    
    CFRunLoopAddSource(CFRunLoopGetCurrent(),
                       socketsource,
                       kCFRunLoopDefaultMode);
    
    CFRelease(socketsource);
    
    _listening = YES;
}

- (void)close {
    [self closeWithError:nil notify:NO];
}

@end
