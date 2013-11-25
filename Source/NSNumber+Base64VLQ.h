//
//  NSNumber+Base64VLQ.h
//  Luax
//
//  Created by Noah Hilt on 11/22/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface NSNumber(Base64VLQ)
- (NSString *)encode;
@end

@interface NSMutableString(Base64VLQ)
- (NSNumber *)decode;
@end
