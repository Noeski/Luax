//
//  NSNumber+Base64VLQ.m
//  Luax
//
//  Created by Noah Hilt on 11/22/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "NSNumber+Base64VLQ.h"

static char base64EncodingTable[64] = {
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P',
    'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f',
    'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v',
    'w', 'x', 'y', 'z', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '+', '/'
};

const NSInteger VLQ_BASE_SHIFT = 5;
const NSInteger VLQ_BASE = (1 << VLQ_BASE_SHIFT);
const NSInteger VLQ_BASE_MASK = (VLQ_BASE - 1);
const NSInteger VLQ_CONTINUATION_BIT = VLQ_BASE;

@implementation NSNumber(Base64VLQ)

- (NSString *)encode {
    NSInteger value = [self integerValue];
    
    NSString *encoded = @"";
    NSUInteger digit;
    
    NSUInteger vlq = value < 0 ? ((-value) << 1) + 1 : (value << 1) + 0;
    
    do {
        digit = vlq & VLQ_BASE_MASK;
        vlq = vlq >> VLQ_BASE_SHIFT;
        if(vlq > 0) {
            digit |= VLQ_CONTINUATION_BIT;
        }
        
        encoded = [encoded stringByAppendingFormat:@"%c", base64EncodingTable[digit]];
    } while (vlq > 0);
    
    return encoded;
}

@end

@implementation NSMutableString(Base64VLQ)

- (NSNumber *)decode {
    NSInteger i = 0;
    NSInteger result = 0;
    NSInteger shift = 0;
    NSInteger continuation, digit;
    
    do {
        if(i >= [self length]) {
            //Error
            break;
        }
        
        digit = [self characterAtIndex:i++];
        
        if((digit >= 'A') && (digit <= 'Z')) {
            digit = digit - 'A';
        }
        else if((digit >= 'a') && (digit <= 'z')) {
            digit = digit - 'a' + 26;
        }
        else if((digit >= '0') && (digit <= '9')) {
            digit = digit - '0' + 52;
        }
        else if(digit == '+') {
            digit = 62;
        }
        else if(digit == '/') {
            digit = 63;
        }
        
        continuation = (digit & VLQ_CONTINUATION_BIT);
        digit &= VLQ_BASE_MASK;
        result = result + (digit << shift);
        shift += VLQ_BASE_SHIFT;
    } while(continuation);
    
    [self deleteCharactersInRange:NSMakeRange(0, i)];

    BOOL isNegative = (result & 1) == 1;
    NSInteger shifted = result >> 1;
    
    result = isNegative ? -shifted : shifted;
    
    return @(result);
}

@end
