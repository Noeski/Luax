//
//  LXParser.m
//  Luax
//
//  Created by Noah Hilt on 11/16/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXParser.h"
#import "LXToken.h"

@interface LXParser() {
    NSInteger currentPosition;
    NSInteger currentLine;
    NSInteger currentColumn;
    NSMutableArray *errors;
}

@end

@implementation LXParser

- (id)init {
    if(self = [super init]) {
        _tokens = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (void)parse:(NSString *)string {
    self.string = string;
    
    currentPosition = 0;
    currentLine = 0;
    currentColumn = 0;
    _numberOfLines = 0;

    [_tokens removeAllObjects];
    
    LXToken *token = [self scanNextToken];
    
    while(token.type != LX_TK_EOS) {
        [self.tokens addObject:token];
        
        token = [self scanNextToken];
    }
    
    _numberOfLines = currentLine;
}

BOOL NSRangesTouch2(NSRange range, NSRange otherRange){
    NSUInteger min, loc, max1 = NSMaxRange(range), max2= NSMaxRange(otherRange);
    
    min = (max1 < max2) ? max1 : max2;
    loc = (range.location > otherRange.location) ? range.location : otherRange.location;
    
    return min >= loc;
}

- (NSRange)replaceCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSInteger diff = string.length - range.length;

    NSInteger startIndex = 0;
    NSInteger endIndex = 0;
    
    NSRange replacementRange;

    LXToken *previousToken;
    
    BOOL found = NO;
    
    for(LXToken *token in self.tokens) {
        if(token.range.location > NSMaxRange(range)) {
            break;
        }
        
        if(NSRangesTouch2(range, token.range)) {
            replacementRange.location = NSMaxRange(previousToken.range);
            replacementRange.length = MAX((range.location - replacementRange.location)  + string.length, NSMaxRange(token.range) - replacementRange.location);

            currentPosition = NSMaxRange(previousToken.range);
            currentLine = previousToken.endLine;
            currentColumn = previousToken.endColumn;
            
            found = YES;
            
            break;
        }
        
        ++startIndex;
        
        previousToken = token;
    }
    
    if(!found) {
        replacementRange.location = range.location;
        replacementRange.length = (range.location - replacementRange.location) + string.length;
        
        currentPosition = range.location;
        currentLine = previousToken.startLine;
        currentColumn = previousToken.column;
        
        for(NSInteger i = previousToken.range.location; i < NSMaxRange(previousToken.range); ++i) {
            char ch = [self.string characterAtIndex:i];
            
            if(ch == '\n' || ch == '\r') {
                ++currentLine;
                currentColumn = 0;
            }
            else {
                ++currentColumn;
            }
        }
    }
    
    self.string = [self.string stringByReplacingCharactersInRange:range withString:string];

    NSMutableArray *newTokens = [[NSMutableArray alloc] init];
    
    LXToken *token = [self scanNextToken];
    
    while(token.type != LX_TK_EOS) {
        [newTokens addObject:token];
        
        if(currentPosition >= NSMaxRange(replacementRange))
            break;
        
        token = [self scanNextToken];
    }
    
    replacementRange.length = currentPosition - replacementRange.location;
    
    for(endIndex = startIndex; endIndex < [self.tokens count]; ++endIndex) {
        LXToken *token = self.tokens[endIndex];
        
        NSInteger location = token.range.location + diff;
        
        if(location >= (NSInteger)NSMaxRange(replacementRange))
            break;
    }
    
    [self.tokens removeObjectsInRange:NSMakeRange(startIndex, endIndex-startIndex)];
    
    for(NSInteger i = 0; i < [newTokens count]; ++i) {
        [self.tokens insertObject:newTokens[i] atIndex:startIndex+i];
    }
    
    for(NSInteger i = startIndex+[newTokens count]; i < [self.tokens count]; ++i) {
        LXToken *token = self.tokens[i];
        
        token.range = NSMakeRange(token.range.location+diff, token.range.length);
    }
    
    return replacementRange;
}

- (char)current {
    if(currentPosition >= [self.string length])
        return '\0';
    
    return [self.string characterAtIndex:currentPosition];
}

- (BOOL)isDigit:(char)ch {
    return ch >= '0' && ch <= '9';
}

- (BOOL)isAlphaNumeric:(char)ch {
    return ch == '_' || (ch >= 'a' && ch <= 'z') || (ch >= 'A' && ch <= 'Z') || [self isDigit:ch];
}

- (void)next {
    if(currentPosition < [self.string length]) {
        currentPosition++;
        currentColumn++;
    }
}

- (BOOL)checkNext:(NSString *)set {
    if([self current] == '\0' ||
       [set rangeOfString:[NSString stringWithFormat:@"%c", [self current]]].location == NSNotFound)
        return NO;
    
    [self next];
    return YES;
}

- (BOOL)currentIsNewLine {
    char ch = [self current];
    
    return ch == '\n' || ch == '\r';
}

- (void)increaseLineNumber {
    char old = [self current];
    
    [self next];
    
    if([self currentIsNewLine] && old != [self current])
        [self next];
    
    currentLine++;
    currentColumn = 0;
}

- (NSInteger)skipSeparator {
    NSInteger count = 0;
    char s = [self current];
    
    [self next];
    
    while([self current] == '=') {
        [self next];
        ++count;
    }
    
    return [self current] == s ? count : (-count) - 1;
}

- (void)readLongString:(NSInteger)separator {
    [self next];
    
    if([self currentIsNewLine])
    [self increaseLineNumber];
    
    BOOL loop = YES;
    while(loop) {
        switch([self current]) {
            case '\0':
            loop = NO;
            break;
            case ']': {
                if([self skipSeparator] == separator) {
                    [self next];
                    loop = NO;
                }
                break;
            }
            case '\n':
            case '\r': {
                [self increaseLineNumber];
                break;
            }
            default: {
                [self next];
            }
        }
    }
}

- (void)readHex {
    for(int i = 0; i < 2; ++i) {
        [self next];
        //Check if actually hex?
    }
}

- (void)readDecimalEscape {
    for(int i = 0; i < 3 && [self isDigit:[self current]]; ++i) {
        [self next];
    }
}

- (void)readString:(char)delimiter {
    [self next];
    
    BOOL loop = YES;
    while(loop && [self current] != delimiter) {
        switch([self current]) {
            case '\0':
            case '\n':
            case '\r':
            loop = NO;
            break;
            case '\\': {
                [self next];
                switch([self current]) {
                    case 'a': goto read_save;
                    case 'b': goto read_save;
                    case 'f': goto read_save;
                    case 'n': goto read_save;
                    case 'r': goto read_save;
                    case 't': goto read_save;
                    case 'v': goto read_save;
                    case 'x': [self readHex]; goto read_save;
                    case '\n': case '\r':
                    [self increaseLineNumber]; goto no_save;
                    case '\\': case '\"': case '\'':
                    goto read_save;
                    case '\0': goto no_save;  /* will raise an error next loop */
                    case 'z': {  /* zap following span of spaces */
                        [self next];  /* skip the 'z' */
                        while([self current] == ' ') {
                            if([self currentIsNewLine]) [self increaseLineNumber];
                            else [self next];
                        }
                        goto no_save;
                    }
                    default: {
                        if(![self isDigit:[self current]]) {
                            goto no_save;
                        }
                        
                        [self readDecimalEscape];
                        goto no_save;
                    }
                }
            read_save: [self next];
            no_save: break;
            }
            default:
            [self next];
        }
    }
    
    [self next];
}

- (void)readNumeral {
    do {
        [self next];
        if([self checkNext:@"EePp"])
        [self checkNext:@"+-"];
    } while([self isDigit:[self current]] || [self current] == '.');
}

- (LXToken *)tokenWithType:(LXTokenType)type position:(NSInteger)startPosition line:(NSInteger)startLine column:(NSInteger)column {
    LXToken *token = [[LXToken alloc] init];
    
    token.type = type;
    token.range = NSMakeRange(startPosition, currentPosition-startPosition);
    token.startLine = startLine;
    token.endLine = currentLine;
    token.column = column;
    token.endColumn = currentColumn;
    
    return token;
}

- (LXToken *)scanNextToken {
    for(;;) {
        NSInteger startPosition = currentPosition;
        NSInteger startLine = currentLine;
        NSInteger startColumn = currentColumn;
        
        switch([self current]) {
            case '\n': case '\r': {  /* line breaks */
                [self increaseLineNumber];
                break;
            }
            case ' ': case '\f': case '\t': case '\v': {  /* spaces */
                [self next];
                break;
            }
            case '-': {  /* '-', '-=' or '--' (comment) */
                [self next];
                if([self current] == '=') { [self next]; return [self tokenWithType:LX_TK_MINUS_EQ position:startPosition line:startLine column:startColumn]; }
                else if([self current] != '-')
                    return [self tokenWithType:'-' position:startPosition line:startLine column:startColumn];
                
                /* else is a comment */
                [self next];
                if([self current] == '[') {  /* long comment? */
                    NSInteger sep = [self skipSeparator];
                    
                    if(sep >= 0) {
                        [self readLongString:sep];
                        return [self tokenWithType:LX_TK_LONGCOMMENT position:startPosition line:startLine column:startColumn];
                        break;
                    }
                }
                /* else short comment */
                while(![self currentIsNewLine] && [self current] != '\0')
                [self next];  /* skip until end of line (or end of file) */
                
                return [self tokenWithType:LX_TK_COMMENT position:startPosition line:startLine column:startColumn];
                break;
            }
            case '[': {  /* long string or simply '[' */
                NSInteger sep = [self skipSeparator];
                if(sep >= 0) {
                    [self readLongString:sep];
                    return [self tokenWithType:LX_TK_STRING position:startPosition line:startLine column:startColumn];
                }
                else if (sep == -1) return [self tokenWithType:'[' position:startPosition line:startLine column:startColumn];
                else return [self tokenWithType:LX_TK_ERROR position:startPosition line:startLine column:startColumn];
            }
            case '=': {
                [self next];
                if([self current] != '=') return [self tokenWithType:'=' position:startPosition line:startLine column:startColumn];
                else { [self next]; return [self tokenWithType:LX_TK_EQ position:startPosition line:startLine column:startColumn]; }
            }
            case '+': {
                [self next];
                if([self current] != '=') return [self tokenWithType:'+' position:startPosition line:startLine column:startColumn];
                else { [self next]; return [self tokenWithType:LX_TK_PLUS_EQ position:startPosition line:startLine column:startColumn]; }
            }
            case '*': {
                [self next];
                if([self current] != '=') return [self tokenWithType:'*' position:startPosition line:startLine column:startColumn];
                else { [self next]; return [self tokenWithType:LX_TK_MULT_EQ position:startPosition line:startLine column:startColumn]; }
            }
            case '/': {
                [self next];
                if([self current] != '=') return [self tokenWithType:'/' position:startPosition line:startLine column:startColumn];
                else { [self next]; return [self tokenWithType:LX_TK_DIV_EQ position:startPosition line:startLine column:startColumn]; }
            }
            case '^': {
                [self next];
                if([self current] != '=') return [self tokenWithType:'^' position:startPosition line:startLine column:startColumn];
                else { [self next]; return [self tokenWithType:LX_TK_POW_EQ position:startPosition line:startLine column:startColumn]; }
            }
            case '%': {
                [self next];
                if([self current] != '=') return [self tokenWithType:'%' position:startPosition line:startLine column:startColumn];
                else { [self next]; return [self tokenWithType:LX_TK_MOD_EQ position:startPosition line:startLine column:startColumn]; }
            }
            case '<': {
                [self next];
                if([self current] != '=') return [self tokenWithType:'<' position:startPosition line:startLine column:startColumn];
                else { [self next]; return [self tokenWithType:LX_TK_LE position:startPosition line:startLine column:startColumn]; }
            }
            case '>': {
                [self next];
                if([self current] != '=') return [self tokenWithType:'>' position:startPosition line:startLine column:startColumn];
                else { [self next]; return [self tokenWithType:LX_TK_GE position:startPosition line:startLine column:startColumn]; }
            }
            case '~': {
                [self next];
                if([self current] != '=') return [self tokenWithType:'~' position:startPosition line:startLine column:startColumn];
                else { [self next]; return [self tokenWithType:LX_TK_NE position:startPosition line:startLine column:startColumn]; }
            }
            case ':': {
                [self next];
                if([self current] != ':') return [self tokenWithType:':' position:startPosition line:startLine column:startColumn];
                else { [self next]; return [self tokenWithType:LX_TK_DBCOLON position:startPosition line:startLine column:startColumn]; }
            }
            case '"': case '\'': {  /* short literal strings */
                [self readString:[self current]];
                return [self tokenWithType:LX_TK_STRING position:startPosition line:startLine column:startColumn];
            }
            case '.': {  /* '.', '..', '...', or number */
                [self next];
                if([self checkNext:@"."]) {
                    if([self checkNext:@"."])
                        return [self tokenWithType:LX_TK_DOTS position:startPosition line:startLine column:startColumn];   /* '...' */
                    else {
                        if([self current] != '=')
                            return [self tokenWithType:LX_TK_CONCAT position:startPosition line:startLine column:startColumn];   /* '..' */
                        else {
                            [self next];
                            return [self tokenWithType:LX_TK_CONCAT_EQ position:startPosition line:startLine column:startColumn]; 
                        }
                    }
                }
                else if(![self isDigit:[self current]]) return [self tokenWithType:'.' position:startPosition line:startLine column:startColumn];
                /* else go through */
            }
            case '0': case '1': case '2': case '3': case '4':
            case '5': case '6': case '7': case '8': case '9': {
                [self readNumeral];
                return [self tokenWithType:LX_TK_NUMBER position:startPosition line:startLine column:startColumn];
            }
            case '\0': {
                return [self tokenWithType:LX_TK_EOS position:startPosition line:startLine column:startColumn];
            }
            default: {
                if([self isAlphaNumeric:[self current]]) {  /* identifier or reserved word? */
                    do {
                        [self next];
                    } while([self isAlphaNumeric:[self current]]);
                    
                    static __strong NSArray *reservedWords = nil;
                    
                    if(!reservedWords) {
                        reservedWords = @[
                                           @"and", @"break", @"do", @"else", @"elseif",
                                           @"end", @"false", @"for", @"function", @"goto", @"if",
                                           @"in", @"local", @"global", @"nil", @"not", @"or", @"repeat",
                                           @"return", @"then", @"true", @"until", @"while",
                                           @"var", @"Bool", @"Number", @"String", @"Table", @"Function",
                                           @"class", @"extends", @"static"
                                           ];
                    }
                    
                    NSUInteger index = [reservedWords indexOfObject:[self.string substringWithRange:NSMakeRange(startPosition, currentPosition-startPosition)]];
                    
                    if(index != NSNotFound) {
                        return [self tokenWithType:FIRST_RESERVED+(int)index position:startPosition line:startLine column:startColumn];
                    }
                    else {
                        return [self tokenWithType:LX_TK_NAME position:startPosition line:startLine column:startColumn];
                    }
                }
                else {  /* single-char tokens (+ - / ...) */
                    char c = [self current];
                    [self next];
                    return [self tokenWithType:c position:startPosition line:startLine column:startColumn];
                }
            }
        }
    }
    
    return nil;
}

@end
