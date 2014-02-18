//
//  LXLuaWriter.h
//  Luax
//
//  Created by Noah Hilt on 2/16/14.
//  Copyright (c) 2014 Noah Hilt. All rights reserved.
//

@interface LXLuaWriter : NSObject
@property (nonatomic, assign) NSString *currentSource;
@property (nonatomic, assign) NSInteger currentLine;
@property (nonatomic, assign) NSInteger currentColumn;
@property (nonatomic, assign) NSInteger indentationLevel;
@property (nonatomic, readonly) NSString *string;
@property (nonatomic, readonly) NSArray *mappings;

- (void)writeSpace;
- (void)writeNewline;
- (void)write:(NSString *)generated;
- (void)write:(NSString *)generated line:(NSInteger)line column:(NSInteger)column;
- (void)write:(NSString *)generated name:(NSString *)name line:(NSInteger)line column:(NSInteger)column;
- (NSDictionary *)generateSourceMap;
@end