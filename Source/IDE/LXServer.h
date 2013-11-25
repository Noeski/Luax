//
//  LXServer.h
//  Luax
//
//  Created by Noah Hilt on 11/25/12.
//  Copyright (c) 2012 Noah Hilt. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "LXClient.h"

@class LXServer;

@protocol LXServerDelegate <NSObject>
@optional
- (void)serverDidStart:(LXServer *)server;
- (void)server:(LXServer *)server willCloseWithError:(NSError *)error;
- (void)server:(LXServer *)server clientConnected:(LXClient *)client;
@end

@interface LXServer : NSObject <NSStreamDelegate> {
}

@property (nonatomic, weak) id<LXServerDelegate> delegate;
@property (nonatomic, readonly) BOOL listening;
@property (nonatomic, readonly) unsigned short port;
@property (nonatomic, readonly) NSMutableSet *connections;
@property (nonatomic, readonly, retain) NSError *error;

- (void)listen:(unsigned short)port;
- (void)close;

@end
