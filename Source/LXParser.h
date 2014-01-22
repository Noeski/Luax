//
//  LXParser.h
//  Luax
//
//  Created by Noah Hilt on 11/16/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LXParser : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *string;
@property (nonatomic, strong) NSMutableArray *tokens;

- (void)parse:(NSString *)string;
- (NSRange)replaceCharactersInRange:(NSRange)range replacementString:(NSString *)string;
@end