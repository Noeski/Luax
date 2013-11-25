//
//  ClientSocket.h
//  Console
//
//  Created by Noah Hilt on 11/25/12.
//  Copyright (c) 2012 Noah Hilt. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class LXClient;

@protocol LXClientDelegate <NSObject>
@optional
-(void)socketDidConnect:(LXClient *)socket;
-(void)socket:(LXClient *)socket willCloseWithError:(NSError *)error;
-(NSInteger)socket:(LXClient *)socket didReceiveData:(NSData *)data;
-(void)socketCanSend:(LXClient *)socket;
@end

@interface LXClient : NSObject <NSStreamDelegate> {
}

@property (nonatomic, weak) id<LXClientDelegate> delegate;
@property (nonatomic, readonly) BOOL connected;
@property (nonatomic, readonly, retain) NSString *hostAddress;
@property (nonatomic, readonly) unsigned short hostPort;
@property (nonatomic, readonly, retain) NSError *error;


- (void)initWithReadStream:(CFReadStreamRef)readStream writeStream:(CFWriteStreamRef)writeStream;
- (void)connect:(NSString *)address port:(unsigned short)port;
- (void)close;
- (NSInteger)send:(NSData *)data;

@end
