//
//  ClientSocket.m
//  Console
//
//  Created by Noah Hilt on 11/25/12.
//  Copyright (c) 2012 Noah Hilt. All rights reserved.
//

#import "LXClient.h"

@interface LXClient()

@property (nonatomic) NSInteger inputBufferCapacity;
@property (nonatomic) NSInteger outputBufferCapacity;
@property (nonatomic, retain) NSMutableData *inputBuffer;
@property (nonatomic, retain) NSMutableData *outputBuffer;
@property (nonatomic, retain) NSInputStream *inputStream;
@property (nonatomic, retain) NSOutputStream *outputStream;
@property (nonatomic) BOOL inputStreamConnected;
@property (nonatomic) BOOL outputStreamConnected;
@property (nonatomic) BOOL canWrite;

- (void)willCloseWithError:(NSError *)error;
- (void)closeWithError:(NSError *)error notify:(BOOL)notify;
- (void)closeWithError:(NSError *)error;

- (void)processInput;
- (void)processOutput;

@end

@implementation LXClient

- (void)dealloc {    
    [self close];
}

- (void)initWithReadStream:(CFReadStreamRef)readStream writeStream:(CFWriteStreamRef)writeStream {    
    if (self.inputBufferCapacity == 0) {
        self.inputBufferCapacity = 16 * 1024;
    }
    
    if (self.outputBufferCapacity == 0) {
        self.outputBufferCapacity = 16 * 1024;
    }
    
    self.canWrite = NO;
    
    self.inputBuffer = [NSMutableData dataWithCapacity:self.inputBufferCapacity];
    self.outputBuffer = [NSMutableData dataWithCapacity:self.outputBufferCapacity];
        
    self.inputStream = (__bridge NSInputStream *)readStream;
    self.outputStream = (__bridge NSOutputStream *)writeStream;
    
    [self.inputStream setDelegate:self];
    [self.outputStream setDelegate:self];
    [self.inputStream setProperty:(id)kCFBooleanTrue forKey:(NSString *)kCFStreamPropertyShouldCloseNativeSocket];
    [self.outputStream setProperty:(id)kCFBooleanTrue forKey:(NSString *)kCFStreamPropertyShouldCloseNativeSocket];
    [self.inputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    [self.outputStream scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
    
    [self.inputStream open];
    [self.outputStream open];
    
    _connected = YES;
    
    _hostAddress = @"localhost";
    _hostPort = 3632;
}

- (void)connect:(NSString *)address port:(unsigned short)port {
    [self close];
    
    _hostAddress = address;
    _hostPort = port;
    
    CFReadStreamRef readStream;
    CFWriteStreamRef writeStream;
    
    CFStreamCreatePairWithSocketToHost(NULL, (__bridge CFStringRef)address, port, &readStream, &writeStream);
    [self initWithReadStream:readStream writeStream:writeStream];

    CFRelease(readStream);
    CFRelease(writeStream);    
}

- (void)close {
    [self closeWithError:nil notify:NO];
}

- (void)willCloseWithError:(NSError *)error {
    if ([self.delegate respondsToSelector:@selector(socket:willCloseWithError:)]) {
        [self.delegate socket:self willCloseWithError:error];
    }
}

- (void)closeWithError:(NSError *)error notify:(BOOL)notify {
    if (self.connected) {
        if (self.error == nil) {
            _error = error;
        }        
        
        if (notify) {
            __strong LXClient *strongSelf = self;
            
            [self willCloseWithError:error];
            
            strongSelf = nil;
        }
        
        [self.inputStream setDelegate:nil];
        [self.outputStream setDelegate:nil];
        
        [self.inputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        [self.outputStream removeFromRunLoop:[NSRunLoop currentRunLoop] forMode:NSDefaultRunLoopMode];
        
        [self.inputStream close];
        [self.outputStream close];
        
        self.inputStream = nil;
        self.outputStream = nil;
        
        self.inputStreamConnected = NO;
        self.outputStreamConnected = NO;
        self.canWrite = NO;
        _connected = NO;
    }
}

- (void)closeWithError:(NSError *)error {
    [self closeWithError:error notify:YES];
}

- (NSInteger)send:(NSData *)data {
    NSInteger availableBytes = self.outputBufferCapacity - [self.outputBuffer length];
    
    if(availableBytes <= 0)
        return 0;
    
    NSInteger bytesSent = MIN([data length], availableBytes);
    
    [self.outputBuffer appendBytes:[data bytes] length:bytesSent];
    [self processOutput];

    return bytesSent;
}

- (void)processInput {
    NSInteger bytesRead;
    NSUInteger bufferLength;

    bufferLength = [self.inputBuffer length];
    
    if (bufferLength == self.inputBufferCapacity) {
        [self closeWithError:nil];
    } else {
        [self.inputBuffer setLength:self.inputBufferCapacity];

        bytesRead = [self.inputStream read:((uint8_t *) [self.inputBuffer mutableBytes]) + bufferLength maxLength:self.inputBufferCapacity - bufferLength];
        
        if (bytesRead == 0) {
            [self closeWithError:nil];
        } else if (bytesRead < 0) {
            [self closeWithError:[self.inputStream streamError]];
        } else {
            [self.inputBuffer setLength:bufferLength + bytesRead];
            
            NSInteger offset = 0;
            NSInteger bytesParsed = 0;
            NSInteger inputBufferLength = bufferLength + bytesRead;
            NSData *dataToParse = self.inputBuffer;
            
            do {
                if([self.delegate respondsToSelector:@selector(socket:didReceiveData:)]) {
                    bytesParsed = [self.delegate socket:self didReceiveData:dataToParse];
                }
                
                if (!self.connected) {
                    break;
                }
                    
                if (bytesParsed == 0) {
                    if ([dataToParse length] == self.outputBufferCapacity) {
                        [self closeWithError:nil];
                    }
                    
                    break;
                }
                
                offset += bytesParsed;
                
                if (offset == inputBufferLength) {
                    break;
                }
                
                dataToParse = [self.inputBuffer subdataWithRange:NSMakeRange(offset, inputBufferLength - offset)];
            } while(YES);
            
            
            if (offset != 0) {
                [self.inputBuffer replaceBytesInRange:NSMakeRange(0, offset) withBytes:NULL length:0];
            }
        }
    }
}

- (void)processOutput {
    NSInteger bytesWritten;

    if (self.canWrite) {
        if ([self.outputBuffer length] != 0 ) {
            bytesWritten = [self.outputStream write:[self.outputBuffer bytes] maxLength:[self.outputBuffer length]];

            if (bytesWritten <= 0) {
                [self closeWithError:[self.outputStream streamError]];
            }
            else {
                [self.outputBuffer replaceBytesInRange:NSMakeRange(0, bytesWritten) withBytes:NULL length:0];
                
                self.canWrite = NO;
            }
        }
    }
}

- (void)stream:(NSStream *)aStream handleEvent:(NSStreamEvent)eventCode {
    switch (eventCode) {
        case NSStreamEventOpenCompleted: {
            if(aStream == self.inputStream)
                self.inputStreamConnected = YES;
            else if(aStream == self.outputStream)
                self.outputStreamConnected = YES;
            
            if(self.inputStreamConnected &&
               self.outputStreamConnected &&
               [self.delegate respondsToSelector:@selector(socketDidConnect:)]) {
                    [self.delegate socketDidConnect:self];
                }
        } break;
            
        case NSStreamEventHasBytesAvailable: {
            [self processInput];
            
        } break;
            
        case NSStreamEventHasSpaceAvailable: {
            self.canWrite = YES;

            if([self.outputBuffer length] == 0) {
                if([self.delegate respondsToSelector:@selector(socketCanSend:)]) {
                    [self.delegate socketCanSend:self];
                }
            }
            else {
                [self processOutput];
            }
        } break;
            
        case NSStreamEventEndEncountered: {
            [self closeWithError:nil];
            
        } break;
            
        default:
        case NSStreamEventErrorOccurred: {
            [self closeWithError:[aStream streamError]];
            
        } break;
    }
}

@end
