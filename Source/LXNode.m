//
//  LXNode.m
//  LuaX
//
//  Created by Noah Hilt on 8/11/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXNode.h"
@interface NSString (NSStringAdditions)

+ (NSString *) base64StringFromData:(NSData *)data length:(int)length;

@end

static char base64EncodingTable[64] = {
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M', 'N', 'O', 'P',
    'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z', 'a', 'b', 'c', 'd', 'e', 'f',
    'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v',
    'w', 'x', 'y', 'z', '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', '+', '/'
};

@implementation NSString (NSStringAdditions)

+ (NSString *) base64StringFromData: (NSData *)data length: (int)length {
    unsigned long ixtext, lentext;
    long ctremaining;
    unsigned char input[3], output[4];
    short i, charsonline = 0, ctcopy;
    const unsigned char *raw;
    NSMutableString *result;
    
    lentext = [data length];
    if (lentext < 1)
        return @"";
    result = [NSMutableString stringWithCapacity: lentext];
    raw = [data bytes];
    ixtext = 0;
    
    while (true) {
        ctremaining = lentext - ixtext;
        if (ctremaining <= 0)
            break;
        for (i = 0; i < 3; i++) {
            unsigned long ix = ixtext + i;
            if (ix < lentext)
                input[i] = raw[ix];
            else
                input[i] = 0;
        }
        output[0] = (input[0] & 0xFC) >> 2;
        output[1] = ((input[0] & 0x03) << 4) | ((input[1] & 0xF0) >> 4);
        output[2] = ((input[1] & 0x0F) << 2) | ((input[2] & 0xC0) >> 6);
        output[3] = input[2] & 0x3F;
        ctcopy = 4;
        switch (ctremaining) {
            case 1:
                ctcopy = 2;
                break;
            case 2:
                ctcopy = 3;
                break;
        }
        
        for (i = 0; i < ctcopy; i++)
            [result appendString: [NSString stringWithFormat: @"%c", base64EncodingTable[output[i]]]];
        
        for (i = ctcopy; i < 4; i++)
            [result appendString: @"="];
        
        ixtext += 3;
        charsonline += 4;
        
        if ((length > 0) && (charsonline >= length))
            charsonline = 0;
    }     
    return result;
}

@end

@interface NSData (NSDataAdditions)

+ (NSData *) base64DataFromString:(NSString *)string;

@end

@implementation NSData (NSDataAdditions)

+ (NSData *)base64DataFromString: (NSString *)string
{
    unsigned long ixtext, lentext;
    unsigned char ch, inbuf[4], outbuf[3];
    short i, ixinbuf;
    Boolean flignore, flendtext = false;
    const unsigned char *tempcstring;
    NSMutableData *theData;
    
    if (string == nil)
    {
        return [NSData data];
    }
    
    ixtext = 0;
    
    tempcstring = (const unsigned char *)[string UTF8String];
    
    lentext = [string length];
    
    theData = [NSMutableData dataWithCapacity: lentext];
    
    ixinbuf = 0;
    
    while (true)
    {
        if (ixtext >= lentext)
        {
            break;
        }
        
        ch = tempcstring [ixtext++];
        
        flignore = false;
        
        if ((ch >= 'A') && (ch <= 'Z'))
        {
            ch = ch - 'A';
        }
        else if ((ch >= 'a') && (ch <= 'z'))
        {
            ch = ch - 'a' + 26;
        }
        else if ((ch >= '0') && (ch <= '9'))
        {
            ch = ch - '0' + 52;
        }
        else if (ch == '+')
        {
            ch = 62;
        }
        else if (ch == '=')
        {
            flendtext = true;
        }
        else if (ch == '/')
        {
            ch = 63;
        }
        else
        {
            flignore = true;
        }
        
        if (!flignore)
        {
            short ctcharsinbuf = 3;
            Boolean flbreak = false;
            
            if (flendtext)
            {
                if (ixinbuf == 0)
                {
                    break;
                }
                
                if ((ixinbuf == 1) || (ixinbuf == 2))
                {
                    ctcharsinbuf = 1;
                }
                else
                {
                    ctcharsinbuf = 2;
                }
                
                ixinbuf = 3;
                
                flbreak = true;
            }
            
            inbuf [ixinbuf++] = ch;
            
            if (ixinbuf == 4)
            {
                ixinbuf = 0;
                
                outbuf[0] = (inbuf[0] << 2) | ((inbuf[1] & 0x30) >> 4);
                outbuf[1] = ((inbuf[1] & 0x0F) << 4) | ((inbuf[2] & 0x3C) >> 2);
                outbuf[2] = ((inbuf[2] & 0x03) << 6) | (inbuf[3] & 0x3F);
                
                for (i = 0; i < ctcharsinbuf; i++)
                {
                    [theData appendBytes: &outbuf[i] length: 1];
                }
            }
            
            if (flbreak)
            {
                break;
            }
        }
    }
    
    return theData;
}

@end

@interface LXLuaWriter()
@property (nonatomic, strong) NSMutableString *mutableString;
@end

@implementation LXLuaWriter

- (id)init {
    if(self = [super init]) {
        _mutableString = [[NSMutableString alloc] init];
    }
    
    return self;
}

- (NSString *)string {
    return _mutableString;
}

NSString *lastName;
NSInteger lastLine;
NSInteger lastColumn;
NSMutableArray *mappings;

- (NSArray *)mappings {
    return mappings;
}

- (void)write:(NSString *)generated line:(NSInteger)line column:(NSInteger)column {
    [self write:generated name:nil line:line column:column];
}

- (void)write:(NSString *)generated name:(NSString *)name line:(NSInteger)line column:(NSInteger)column {
    if(line != lastLine ||
       column != lastColumn ||
       ![name isEqual:lastName]) {
        NSDictionary *dictionary = @{@"name" : name ? name : @"", @"original" : @{@"line" : @(line), @"column" : @(column)}, @"generated" : @{@"line" : @(self.currentLine), @"column" : @(self.currentColumn)}};
        
        
        if(!mappings)
            mappings = [[NSMutableArray alloc] init];
        
        [mappings addObject:dictionary];
        
        lastName = name;
        lastLine = line;
        lastColumn = column;
    }
    
    [self.mutableString appendString:generated];

    NSArray *lines = [generated componentsSeparatedByString:@"\n"];
    
    if([lines count] == 1) {
        self.currentColumn += [generated length];
    }
    else {
        self.currentLine += [lines count] - 1;
        self.currentColumn = [lines.lastObject length];
    }
}

- (NSString *)encoded:(NSInteger)value {
    NSInteger VLQ_BASE_SHIFT = 5;
    NSInteger VLQ_BASE = (1 << VLQ_BASE_SHIFT);
    NSInteger VLQ_BASE_MASK = (VLQ_BASE - 1);
    NSInteger VLQ_CONTINUATION_BIT = VLQ_BASE;
    
    NSString *encoded = @"";
    NSUInteger digit;
    
    NSUInteger vlq = value < 0
    ? ((-value) << 1) + 1
    : (value << 1) + 0;
    
    do {
        digit = vlq & VLQ_BASE_MASK;
        vlq = vlq >> VLQ_BASE_SHIFT;
        if (vlq > 0) {
            // There are still more digits in this value, so we must make sure the
            // continuation bit is marked.
            digit |= VLQ_CONTINUATION_BIT;
        }
        
        encoded = [encoded stringByAppendingFormat:@"%c", base64EncodingTable[digit]];
        
        //encoded += base64.encode(digit);
    } while (vlq > 0);
    
    return encoded;
}

- (NSString *)decode:(NSString *)value decodedValue:(NSInteger *)decoded {
    NSInteger VLQ_BASE_SHIFT = 5;
    NSInteger VLQ_BASE = (1 << VLQ_BASE_SHIFT);
    NSInteger VLQ_BASE_MASK = (VLQ_BASE - 1);
    NSInteger VLQ_CONTINUATION_BIT = VLQ_BASE;
    
    NSInteger i = 0;
    NSInteger strLen = [value length];
    NSInteger result = 0;
    NSInteger shift = 0;
    NSInteger continuation, digit;
    
    do {
        if(i >= strLen) {
        }
        
        digit = [value characterAtIndex:i++];
        
        if ((digit >= 'A') && (digit <= 'Z'))
        {
            digit = digit - 'A';
        }
        else if ((digit >= 'a') && (digit <= 'z'))
        {
            digit = digit - 'a' + 26;
        }
        else if ((digit >= '0') && (digit <= '9'))
        {
            digit = digit - '0' + 52;
        }
        else if (digit == '+')
        {
            digit = 62;
        }
        else if (digit == '/')
        {
            digit = 63;
        }
        
        continuation = (digit & VLQ_CONTINUATION_BIT);
        digit &= VLQ_BASE_MASK;
        result = result + (digit << shift);
        shift += VLQ_BASE_SHIFT;
    } while(continuation);
    
    BOOL isNegative = (result & 1) == 1;
    NSInteger shifted = result >> 1;
    *decoded = isNegative
    ? -shifted
    : shifted;
    
    return [value substringFromIndex:i];
}

NSMutableDictionary *allNames;
NSInteger currentNameIndex = 0;

- (NSString *)generate {
    if(!allNames)
        allNames = [[NSMutableDictionary alloc] init];
    
    NSInteger previousGeneratedColumn = 0;
    NSInteger previousGeneratedLine = 0;
    NSInteger previousOriginalColumn = 0;
    NSInteger previousOriginalLine = 0;
    NSInteger previousName = 0;

    NSString *result = @"";
    
    for(NSInteger i = 0; i < [self.mappings count]; ++i) {
        NSDictionary *mapping = self.mappings[i];
        NSInteger generatedLine = [mapping[@"generated"][@"line"] integerValue];
        NSInteger generatedColumn = [mapping[@"generated"][@"column"] integerValue];
        NSInteger originalLine = [mapping[@"original"][@"line"] integerValue];
        NSInteger originalColumn = [mapping[@"original"][@"column"] integerValue];
        NSString *name = mapping[@"name"];
        
        if(generatedLine != previousGeneratedLine) {
            previousGeneratedColumn = 0;
            while(generatedLine != previousGeneratedLine) {
                result = [result stringByAppendingString:@";"];
                previousGeneratedLine++;
            }
        }
        else {
            if(i > 0) {
                NSDictionary *lastMapping = self.mappings[i-1];
                
                if([lastMapping isEqualToDictionary:mapping])
                    continue;
                    
                result = [result stringByAppendingString:@","];
            }
        }
        
        
        result = [result stringByAppendingString:[self encoded:generatedColumn - previousGeneratedColumn]];

        previousGeneratedColumn = generatedColumn;
        
        //result += base64VLQ.encode(this._sources.indexOf(mapping.source)- previousSource);
        //previousSource = this._sources.indexOf(mapping.source);

        result = [result stringByAppendingString:[self encoded:originalLine - previousOriginalLine]];
        
        previousOriginalLine = originalLine;
        
        result = [result stringByAppendingString:[self encoded:originalColumn - previousOriginalColumn]];
        
        previousOriginalColumn = originalColumn;
        
        if([name length] > 0) {
            NSNumber *nameIndex = allNames[name];
            
            if(!nameIndex) {
                nameIndex = [NSNumber numberWithInteger:currentNameIndex++];
                allNames[name] = nameIndex;
            }
            
            result = [result stringByAppendingString:[self encoded:[nameIndex integerValue] - previousName]];
            previousName = [nameIndex integerValue];
        }
    }
    
    NSArray *newMappings = [self parseMapping:result];
    
    for(NSInteger i = 0; i < [mappings count]; ++i) {
        NSDictionary *original = mappings[i];
        NSDictionary *generated = i < [newMappings count] ? newMappings[i] : @{};
        
        NSLog(@"%@ - %@", original, generated);
        
    }
    //NSLog(@"Mappings: %@\nNew Mappings: %@", mappings, newMappings);
    return result;
}

- (NSArray *)parseMapping:(NSString *)string {
    NSMutableArray *newMappings = [NSMutableArray array];
    
    NSInteger generatedLine = 0;
    NSInteger previousGeneratedColumn = 0;
    NSInteger previousOriginalLine = 0;
    NSInteger previousOriginalColumn = 0;
    NSInteger previousSource = 0;
    NSInteger previousName = 0;
    NSCharacterSet *mappingSeparator = [NSCharacterSet characterSetWithCharactersInString:@",;"];
    
    //var mappingSeparator = /^[,;]/;
    
    while([string length] > 0) {
        if([string characterAtIndex:0] == ';') {
            generatedLine++;
            string = [string substringFromIndex:1];
            previousGeneratedColumn = 0;
        }
        else if([string characterAtIndex:0] == ',') {
            string = [string substringFromIndex:1];
        }
        else {
            NSMutableDictionary *mapping = [NSMutableDictionary dictionary];
            NSInteger temp;

            string = [self decode:string decodedValue:&temp];
            previousGeneratedColumn = previousGeneratedColumn + temp;

            mapping[@"generated"] = @{@"line" : @(generatedLine), @"column" : @(previousGeneratedColumn)};
            
            if([string length] > 0 && ![mappingSeparator characterIsMember:[string characterAtIndex:0]]) {
                // Original source.
                //string = [self decode:string decodedValue:&temp];
                
                //mapping.source = this._sources.at(previousSource + temp.value);
                //previousSource += temp.value;
                
                if([string length] == 0 || [mappingSeparator characterIsMember:[string characterAtIndex:0]]) {
                    //error
                }
                
                string = [self decode:string decodedValue:&temp];
                
                // Original line.
                NSInteger originalLine = previousOriginalLine + temp;
                previousOriginalLine = originalLine;
                
                if([string length] == 0 || [mappingSeparator characterIsMember:[string characterAtIndex:0]]) {
                    //error
                }
                
                string = [self decode:string decodedValue:&temp];
                
                NSInteger originalColumn = previousOriginalColumn + temp;
                previousOriginalColumn = originalColumn;
                
                mapping[@"original"] = @{@"line" : @(originalLine), @"column" : @(originalColumn)};
                
                if([string length] > 0 && ![mappingSeparator characterIsMember:[string characterAtIndex:0]]) {
                    // Original name.
                    string = [self decode:string decodedValue:&temp];
                    
                    mapping[@"name"] = @(previousName+temp);
                    
                    previousName += temp;
                }
            }
            
            [newMappings addObject:mapping];
        }
    }
    
    return newMappings;
}

@end

@implementation LXScope

- (id)initWithParent:(LXScope *)parent openScope:(BOOL)openScope {
    if(self = [super init]) {
        _type = LXScopeTypeBlock;
        _parent = parent;
        _children = [[NSMutableArray alloc] init];
        _localVariables = [[NSMutableArray alloc] init];
        
        [_parent.children addObject:self];
        
        if([self isGlobalScope] || [self isFileScope]) {
            _scopeLevel = 0;
        }
        else if(openScope) {
            _scopeLevel = parent.scopeLevel+1;
        }
        else {
            _scopeLevel = parent.scopeLevel;
        }
    }
    
    return self;
}

- (BOOL)isGlobalScope {
    return self.parent == nil;
}

- (BOOL)isFileScope {
    return [self.parent isGlobalScope];
}

- (LXVariable *)localVariable:(NSString *)name {
    for(LXVariable *variable in self.localVariables) {
        if([variable.name isEqualToString:name]) {
            return variable;
        }
    }
    
    return nil;
}

- (LXVariable *)variable:(NSString *)name {
    for(LXVariable *variable in self.localVariables) {
        if([variable.name isEqualToString:name]) {
            return variable;
        }
    }
    
    return [self.parent variable:name];
}

- (LXVariable *)createVariable:(NSString *)name type:(LXClass *)type {
    LXVariable *variable = [[LXVariable alloc] init];
    variable.name = name;
    variable.type = type;
    variable.isGlobal = [self isGlobalScope];
    
    [self.localVariables addObject:variable];
    
    return variable;
}

- (void)removeVariable:(LXVariable *)variable {
    [self.localVariables removeObject:variable];
}

- (LXScope *)scopeAtLocation:(NSInteger)location {
    if(![self isGlobalScope] &&
       ![self isFileScope] &&
       !NSLocationInRange(location, self.range)) {
        return nil;
    }
        
    for(LXScope *child in self.children) {
        LXScope *scope = [child scopeAtLocation:location];
        
        if(scope)
            return scope;
    }
    
    return self;
}

- (void)removeScope:(LXScope *)scope {
    [self.children removeObject:scope];
}

@end

@implementation LXNode
NSInteger stringScopeLevel = 0;

- (id)initWithLine:(NSInteger)line column:(NSInteger)column {
    if(self = [super init]) {
        _line = line;
        _column = column;
    }
    
    return self;
}

- (void)compile:(LXLuaWriter *)writer {
    NSLog(@"ERROR");
}

- (NSString *)toString {
    NSLog(@"ERROR");
    
    return @"";
}

- (void)openStringScope {
    ++stringScopeLevel;
}

- (void)closeStringScope {
    --stringScopeLevel;
}

- (NSString *)indentedString:(NSString *)input {
    NSArray *lines = [input componentsSeparatedByString:@"\n"];
    NSString *output = @"";
    
    for(NSString *line in lines) {
        output = [output stringByAppendingString:[[@"" stringByPaddingToLength:stringScopeLevel*2 withString:@" " startingAtIndex:0] stringByAppendingString:line]];
        
        if(line != lines.lastObject) {
            output = [output stringByAppendingString:@"\n"];
        }
    }
    
    return output;
}

@end

//Statements
@implementation LXNodeStatement
@end

@implementation LXNodeEmptyStatement

- (NSString *)toString {
    return @";";
}

@end

@implementation LXNodeBlock

- (NSString *)toString {
    NSString *string = @"";
    NSInteger index = 0;
    for(LXNode *statement in self.statements) {
        string = [string stringByAppendingString:[statement toString]];
        
        ++index;
        
        if(index < [self.statements count]) {
            string = [string stringByAppendingString:@"\n"];
        }
    }
    
    return string;
}

- (void)compile:(LXLuaWriter *)writer {
    NSInteger index = 0;
    for(LXNode *statement in self.statements) {
        [statement compile:writer];
        
        ++index;
        
        if(index < [self.statements count]) {
            [writer write:@"\n" line:self.line column:self.column];
        }
    }
}

@end

@implementation LXNodeIfStatement

- (NSString *)toString {
    NSString *string = [self indentedString:[NSString stringWithFormat:@"if %@ then", [self.condition toString]]];
    string = [string stringByAppendingString:@"\n"];

    if([self.body.statements count] > 0) {
        [self openStringScope];
        string = [string stringByAppendingString:[self.body toString]];
        [self closeStringScope];

        string = [string stringByAppendingString:@"\n"];
    }
    
    for(LXNode *elseIf in self.elseIfStatements) {
        string = [string stringByAppendingString:[elseIf toString]];
    }
    
    if(self.elseStatement) {
        string = [string stringByAppendingString:[self indentedString:@"else"]];
        string = [string stringByAppendingString:@"\n"];

        if([self.elseStatement.statements count] > 0) {
            [self openStringScope];
            string = [string stringByAppendingString:[self.elseStatement toString]];
            [self closeStringScope];
        
            string = [string stringByAppendingString:@"\n"];
        }
    }
    
    string = [string stringByAppendingString:[self indentedString:@"end"]];
    
    return string;
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:@"if " line:self.line column:self.column];
    [self.condition compile:writer];
    [writer write:@" then\n " line:self.line column:self.column];
    
    if([self.body.statements count] > 0) {
        [self openStringScope];
        [self.body compile:writer];
        [self closeStringScope];
        [writer write:@"\n" line:self.line column:self.column];
    }
    
    for(LXNode *elseIf in self.elseIfStatements) {
        [elseIf compile:writer];
    }
    
    if(self.elseStatement) {
        [writer write:@"else\n" line:self.line column:self.column];
        
        if([self.elseStatement.statements count] > 0) {
            [self openStringScope];
            [self.elseStatement compile:writer];
            [self closeStringScope];
            [writer write:@"\n" line:self.line column:self.column];
        }
    }
    
    [writer write:@"end" line:self.line column:self.column];
}

@end

@implementation LXNodeElseIfStatement

- (NSString *)toString {
    NSString *string = [self indentedString:[NSString stringWithFormat:@"elseif %@ then", [self.condition toString]]];
    string = [string stringByAppendingString:@"\n"];
    
    if([self.body.statements count] > 0) {
        [self openStringScope];
        string = [string stringByAppendingString:[self.body toString]];
        [self closeStringScope];
        
        string = [string stringByAppendingString:@"\n"];
    }
    
    return string;
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:@"elseif " line:self.line column:self.column];
    [self.condition compile:writer];
    [writer write:@" then\n " line:self.line column:self.column];
    
    if([self.body.statements count] > 0) {
        [self openStringScope];
        [self.body compile:writer];
        [self closeStringScope];
        [writer write:@"\n" line:self.line column:self.column];
    }
}


@end

@implementation LXNodeWhileStatement

- (NSString *)toString {
    NSString *string = [self indentedString:[NSString stringWithFormat:@"while %@ do", [self.condition toString]]];
    
    string = [string stringByAppendingString:@"\n"];

    if([self.body.statements count] > 0) {
        [self openStringScope];
        string = [string stringByAppendingString:[self.body toString]];
        [self closeStringScope];
        string = [string stringByAppendingString:@"\n"];
    }
    
    string = [string stringByAppendingString:[self indentedString:@"end"]];
    
    return string;
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:@"while " line:self.line column:self.column];
    [self.condition compile:writer];
    [writer write:@" do\n " line:self.line column:self.column];
    
    if([self.body.statements count] > 0) {
        [self openStringScope];
        [self.body compile:writer];
        [self closeStringScope];
        [writer write:@"\n" line:self.line column:self.column];
    }
    
    [writer write:@"end" line:self.line column:self.column];
}

@end

@implementation LXNodeDoStatement

- (NSString *)toString {
    NSString *string = [self indentedString:@"do"];
    string = [string stringByAppendingString:@"\n"];

    if([self.body.statements count] > 0) {
        [self openStringScope];
        string = [string stringByAppendingString:[self.body toString]];
        [self closeStringScope];
        string = [string stringByAppendingString:@"\n"];
    }
    
    string = [string stringByAppendingString:[self indentedString:@"end"]];
    
    return string;
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:@"do\n " line:self.line column:self.column];
    
    if([self.body.statements count] > 0) {
        [self openStringScope];
        [self.body compile:writer];
        [self closeStringScope];
        [writer write:@"\n" line:self.line column:self.column];
    }
    
    [writer write:@"end" line:self.line column:self.column];
}

@end

@implementation LXNodeNumericForStatement

- (NSString *)toString {
    NSString *string;
    
    if(self.stepExpression) {
        string = [NSString stringWithFormat:@"for %@=%@,%@,%@ do", self.variable.name, [self.startExpression toString], [self.endExpression toString], [self.stepExpression toString]];
    }
    else {
        string = [NSString stringWithFormat:@"for %@=%@,%@ do", self.variable.name, [self.startExpression toString], [self.endExpression toString]];
    }
    
    string = [string stringByAppendingString:@"\n"];

    if([self.body.statements count] > 0) {
        [self openStringScope];
        string = [string stringByAppendingString:[self.body toString]];
        [self closeStringScope];
        string = [string stringByAppendingString:@"\n"];
    }
    
    string = [string stringByAppendingString:@"end"];
    
    return [self indentedString:string];
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:@"for " line:self.line column:self.column];
    [writer write:self.variable.name name:self.variable.name line:self.line column:self.column];
    [writer write:@"=" line:self.line column:self.column];
    [self.startExpression compile:writer];
    [writer write:@"," line:self.line column:self.column];
    [self.endExpression compile:writer];
    
    if(self.stepExpression) {
        [writer write:@"," line:self.line column:self.column];
        [self.stepExpression compile:writer];
    }
    
    [writer write:@" do\n" line:self.line column:self.column];

    if([self.body.statements count] > 0) {
        [self openStringScope];
        [self.body compile:writer];
        [self closeStringScope];
        [writer write:@"\n" line:self.line column:self.column];
    }
    
    [writer write:@"end" line:self.line column:self.column];
}

@end

@implementation LXNodeGenericForStatement

- (NSString *)toString {
    NSString *variableString = @"";
    NSString *generatorString = @"";

    for(NSInteger i = 0; i < [self.variableList count]; ++i) {
        LXVariable *variable = self.variableList[i];
        
        variableString = [variableString stringByAppendingFormat:@"%@", variable.name];
        
        if(i < [self.variableList count]-1) {
            variableString = [variableString stringByAppendingString:@","];
        }
    }
    
    for(NSInteger i = 0; i < [self.generators count]; ++i) {
        LXNodeExpression *generator = self.generators[i];
        
        generatorString = [generatorString stringByAppendingFormat:@"%@", [generator toString]];
        
        if(i < [self.generators count]-1) {
            generatorString = [generatorString stringByAppendingString:@","];
        }
    }
    
    NSString *string = [NSString stringWithFormat:@"for %@ in %@ do\n", variableString, generatorString];

    if([self.body.statements count] > 0) {
        [self openStringScope];
        string = [string stringByAppendingString:[self.body toString]];
        [self closeStringScope];
        string = [string stringByAppendingString:@"\n"];
    }
    
    string = [string stringByAppendingString:@"end"];
    
    return [self indentedString:string];
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:@"for " line:self.line column:self.column];
    
    for(NSInteger i = 0; i < [self.variableList count]; ++i) {
        LXVariable *variable = self.variableList[i];
        
        [writer write:variable.name name:variable.name line:self.line column:self.column];
        
        if(i < [self.variableList count]-1) {
            [writer write:@"," line:self.line column:self.column];
        }
    }
    
    for(NSInteger i = 0; i < [self.generators count]; ++i) {
        LXNodeExpression *generator = self.generators[i];
        
        [generator compile:writer];
        
        if(i < [self.generators count]-1) {
            [writer write:@"," line:self.line column:self.column];
        }
    }
    
    [writer write:@" do\n" line:self.line column:self.column];
    
    if([self.body.statements count] > 0) {
        [self openStringScope];
        [self.body compile:writer];
        [self closeStringScope];
        [writer write:@"\n" line:self.line column:self.column];
    }
    
    [writer write:@"end" line:self.line column:self.column];
}

@end

@implementation LXNodeRepeatStatement

- (NSString *)toString {
    NSString *string = @"repeat";
    string = [string stringByAppendingString:@"\n"];

    if([self.body.statements count] > 0) {
        [self openStringScope];
        string = [string stringByAppendingString:[self.body toString]];
        [self closeStringScope];
        string = [string stringByAppendingString:@"\n"];
    }
    string = [string stringByAppendingString:@"until %@"], [self.condition toString];
    return [self indentedString:string];
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:@"repeat\n" line:self.line column:self.column];
    
    if([self.body.statements count] > 0) {
        [self openStringScope];
        [self.body compile:writer];
        [self closeStringScope];
        
        [writer write:@"\n " line:self.line column:self.column];
    }
    
    [writer write:@"until " line:self.line column:self.column];
    [self.condition compile:writer];
}

@end

@implementation LXNodeFunctionStatement

- (NSString *)toString {
    NSString *string = [self indentedString:self.isLocal ? @"local " : @""];
    
    return [string stringByAppendingString:[self.expression toString]];
}

- (void)compile:(LXLuaWriter *)writer {
    if(self.isLocal)
        [writer write:@"local " line:self.line column:self.column];
    
    [self.expression compile:writer];
}

@end

@implementation LXNodeClassStatement

- (NSString *)toString {
    NSString *string = nil;
    
    if(self.superclass) {
        string = [NSString stringWithFormat:@"%@ = %@ or setmetatable({}, {__call = function(class, ...)\n  local obj = setmetatable({class = \"%@\", super = %@}, {__index = class})\n  obj:init(...)\n  return obj\nend})\n", self.name, self.name, self.name, self.superclass];
        string = [string stringByAppendingFormat:@"for k, v in pairs(%@) do\n  %@[k] = v\nend\n", self.superclass, self.name];
        string = [string stringByAppendingFormat:@"function %@:init(...)\n  %@.init(self, ...)\n", self.name, self.superclass];
    }
    else {
        string = [NSString stringWithFormat:@"%@ = %@ or setmetatable({}, {__call = function(class, ...)\n  local obj = setmetatable({class = \"%@\"}, {__index = class})\n  obj:init(...)\n  return obj\nend})\n", self.name, self.name, self.name];
        string = [string stringByAppendingFormat:@"function %@:init(...)\n", self.name];
    }
    
    for(LXNodeDeclarationStatement *declaration in self.variableDeclarations) {
        for(NSInteger i = 0; i < [declaration.variables count]; ++i) {
            LXVariable *variable = declaration.variables[i];

            LXNode *init = i < [declaration.initializers count] ? declaration.initializers[i] : variable.type.defaultExpression;
            
            string = [string stringByAppendingFormat:@"  self.%@ = %@\n", variable.name, [init toString]];
        }
    }
    
    string = [string stringByAppendingString:@"end"];

    for(LXNode *function in self.functions) {
        string = [string stringByAppendingString:@"\n"];
        string = [string stringByAppendingString:[function toString]];
    }

    return [self indentedString:string];
}

- (void)compile:(LXLuaWriter *)writer {
    if(self.superclass) {
        [writer write:[NSString stringWithFormat:@"%@ = %@ or setmetatable({}, {__call = function(class, ...)\n  local obj = setmetatable({class = \"%@\", super = %@}, {__index = class})\n  obj:init(...)\n  return obj\nend})\n", self.name, self.name, self.name, self.superclass] name:self.name line:self.line column:self.column];
        [writer write:[NSString stringWithFormat:@"for k, v in pairs(%@) do\n  %@[k] = v\nend\n", self.superclass, self.name] line:self.line column:self.column];
        [writer write:[NSString stringWithFormat:@"function %@:init(...)\n  %@.init(self, ...)\n", self.superclass, self.name] line:self.line column:self.column];
    }
    else {
        [writer write:[NSString stringWithFormat:@"%@ = %@ or setmetatable({}, {__call = function(class, ...)\n  local obj = setmetatable({class = \"%@\"}, {__index = class})\n  obj:init(...)\n  return obj\nend})\n", self.name, self.name, self.name] name:self.name line:self.line column:self.column];
        [writer write:[NSString stringWithFormat:@"function %@:init(...)\n", self.name] line:self.line column:self.column];
    }
    
    for(LXNodeDeclarationStatement *declaration in self.variableDeclarations) {
        for(NSInteger i = 0; i < [declaration.variables count]; ++i) {
            LXVariable *variable = declaration.variables[i];
            
            LXNode *init = i < [declaration.initializers count] ? declaration.initializers[i] : variable.type.defaultExpression;
            
            [writer write:[NSString stringWithFormat:@"  self.%@=", variable.name] line:self.line column:self.column];
            [init compile:writer];
            [writer write:@"\n" line:self.line column:self.column];
        }
    }
    
    [writer write:[NSString stringWithFormat:@"end"] line:self.line column:self.column];
    
    for(LXNode *function in self.functions) {
        [writer write:@"\n" line:self.line column:self.column];
        [function compile:writer];
    }
}

@end

@implementation LXNodeLabelStatement

- (NSString *)toString {
    NSString *string = [NSString stringWithFormat:[self indentedString:@"::%@::"], self.label];
    
    return string;
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:@"::" line:self.line column:self.column];
    [writer write:[NSString stringWithFormat:@"%@", self.label] line:self.line column:self.column];
    [writer write:@"::" line:self.line column:self.column];
}

@end

@implementation LXNodeReturnStatement

- (NSString *)toString {
    NSString *string = [self indentedString:@"return "];
    
    NSInteger index = 0;
    for(LXNode *argument in self.arguments) {
        string = [string stringByAppendingString:[argument toString]];
        
        ++index;
        
        if(index < [self.arguments count]) {
            string = [string stringByAppendingString:@","];
        }
    }
    
    return string;
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:@"return " line:self.line column:self.column];
    
    NSInteger index = 0;
    for(LXNode *argument in self.arguments) {
        [argument compile:writer];
        
        ++index;
        
        if(index < [self.arguments count]) {
            [writer write:@"," line:self.line column:self.column];
        }
    }
}

@end

@implementation LXNodeBreakStatement

- (NSString *)toString {
    return [self indentedString:@"break"];
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:@"break" line:self.line column:self.column];
}

@end

@implementation LXNodeGotoStatement

- (NSString *)toString {
    NSString *string = [NSString stringWithFormat:[self indentedString:@"goto %@"], self.label];
    
    return string;
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:@"goto " line:self.line column:self.column];
    [writer write:self.label line:self.line column:self.column];
}

@end

@implementation LXNodeAssignmentStatement

- (NSString *)toString {
    unichar op = [self.op characterAtIndex:0];
    
    NSString *string = @"";
    NSString *initString = @"";
    
    for(NSInteger i = 0; i < [self.variables count]; ++i) {
        LXNodeExpression *variableExpression = self.variables[i];
        LXNode *init = i < [self.initializers count] ? self.initializers[i] : [[LXNodeNilExpression alloc] init];
        
        string = [string stringByAppendingString:[variableExpression toString]];
        
        if(op != '=') {
            initString = [initString stringByAppendingFormat:@"%@ %@ %@", [variableExpression toString], [self.op substringToIndex:[self.op length]-1], [init toString]];
        }
        else {
            initString = [initString stringByAppendingString:[init toString]];
        }
        
        if(i < [self.variables count]-1) {
            string = [string stringByAppendingString:@", "];
            initString = [initString stringByAppendingString:@", "];
        }
    }
    
    return [self indentedString:[string stringByAppendingFormat:@" = %@", initString]];
}

- (void)compile:(LXLuaWriter *)writer {
    unichar op = [self.op characterAtIndex:0];
    
    for(NSInteger i = 0; i < [self.variables count]; ++i) {
        LXNodeExpression *variableExpression = self.variables[i];
        
        [variableExpression compile:writer];
        
        if(i < [self.variables count]-1) {
            [writer write:@"," line:self.line column:self.column];
        }
    }
    
    [writer write:@"=" line:self.line column:self.column];
    
    for(NSInteger i = 0; i < [self.variables count]; ++i) {
        LXNodeExpression *variableExpression = self.variables[i];
        LXNode *init = i < [self.initializers count] ? self.initializers[i] : [[LXNodeNilExpression alloc] init];
        
        if(op != '=') {
            [variableExpression compile:writer];
            [writer write:[self.op substringToIndex:[self.op length]-1] line:self.line column:self.column];
            [init compile:writer];
        }
        else {
            [init compile:writer];
        }
        
        if(i < [self.variables count]-1) {
            [writer write:@"," line:self.line column:self.column];
        }
    }
}

@end

@implementation LXNodeDeclarationStatement

- (NSString *)toString {
    NSString *string = self.isLocal ? @"local " : @"";
    NSString *initString = @"";
    
    for(NSInteger i = 0; i < [self.variables count]; ++i) {
        LXVariable *variable = self.variables[i];
        LXNode *init = i < [self.initializers count] ? self.initializers[i] : variable.type.defaultExpression;
        
        string = [string stringByAppendingString:variable.name];
        initString = [initString stringByAppendingString:[init toString]];
        
        if(i < [self.variables count]-1) {
            string = [string stringByAppendingString:@", "];
            initString = [initString stringByAppendingString:@", "];
        }
    }
    
    return [self indentedString:[string stringByAppendingFormat:@" = %@", initString]];
}

- (void)compile:(LXLuaWriter *)writer {
    if(self.isLocal)
        [writer write:@"local " line:self.line column:self.column];
    
    for(NSInteger i = 0; i < [self.variables count]; ++i) {
        LXNode *variable = self.variables[i];
        
        [variable compile:writer];

        if(i < [self.variables count]-1) {
            [writer write:@"," line:self.line column:self.column];
        }
    }
    
    [writer write:@"=" line:self.line column:self.column];

    for(NSInteger i = 0; i < [self.variables count]; ++i) {
        //LXVariable *variable = self.variables[i];
        //LXNode *init = i < [self.initializers count] ? self.initializers[i] : variable.type.defaultExpression;
        LXNode *init = i < [self.initializers count] ? self.initializers[i] : nil;
        
        [init compile:writer];
        
        if(i < [self.variables count]-1) {
            [writer write:@"," line:self.line column:self.column];
        }
    }
}

@end

@implementation LXNodeExpressionStatement

- (NSString *)toString {
    return [self indentedString:[self.expression toString]];
}

- (void)compile:(LXLuaWriter *)writer {
    [self.expression compile:writer];
}

@end

//Expressions
@implementation LXNodeExpression
@end

@implementation LXNodeVariableExpression

- (NSString *)toString {
    return self.scriptVariable.isMember ? [NSString stringWithFormat:@"self.%@", self.variable] : self.variable;
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:self.scriptVariable.isMember ? [NSString stringWithFormat:@"self.%@", self.variable] : self.variable name:self.scriptVariable.isMember ? @"" : self.variable line:self.line column:self.column];
}

@end

@implementation LXNodeUnaryOpExpression

- (NSString *)toString {
    return [NSString stringWithFormat:@"%@%@", self.op, [self.rhs toString]];
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:self.op line:self.line column:self.column];
    [self.rhs compile:writer];
}

@end

@implementation LXNodeBinaryOpExpression

- (NSString *)toString {
    return [NSString stringWithFormat:@"%@%@%@", [self.lhs toString], self.op, [self.rhs toString]];
}

- (void)compile:(LXLuaWriter *)writer {
    [self.lhs compile:writer];
    [writer write:self.op line:self.line column:self.column];
    [self.rhs compile:writer];
}

@end

@implementation LXNodeNumberExpression

- (NSString *)toString {
    return [NSString stringWithFormat:@"%@", self.value];
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:[NSString stringWithFormat:@"%@", self.value] line:self.line column:self.column];
}

@end

@implementation LXNodeStringExpression

- (NSString *)toString {
    return [NSString stringWithFormat:@"%@", self.value];
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:self.value line:self.line column:self.column];
}

@end

@implementation LXNodeBoolExpression

- (NSString *)toString {
    return [NSString stringWithFormat:@"%@", self.value ? @"true" : @"false"];
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:self.value ? @"true" : @"false" line:self.line column:self.column];
}

@end

@implementation LXNodeNilExpression

- (NSString *)toString {
    return @"nil";
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:@"nil" line:self.line column:self.column];
}

@end

@implementation LXNodeVarArgExpression

- (NSString *)toString {
    return @"...";
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:@"..." line:self.line column:self.column];
}

@end

@implementation LXKeyValuePair
@end

@implementation LXNodeTableConstructorExpression

- (NSString *)toString {
    NSString *string = @"{";
    
    for(NSInteger i = 0; i < [self.keyValuePairs count]; ++i) {
        LXKeyValuePair *kvp = self.keyValuePairs[i];
        
        if(kvp.key) {
            if(kvp.isBoxed)
                string = [string stringByAppendingFormat:@"[%@]=%@", [kvp.key toString], [kvp.value toString]];
            else
                string = [string stringByAppendingFormat:@"%@=%@", [kvp.key toString], [kvp.value toString]];
        }
        else {
            string = [string stringByAppendingFormat:@"%@", [kvp.value toString]];
        }
        
        if(i < [self.keyValuePairs count]-1) {
            string = [string stringByAppendingString:@", "];
        }
    }
    
    string = [string stringByAppendingString:@"}"];
    
    return string;
}

- (void)compile:(LXLuaWriter *)writer {
    [writer write:@"{" line:self.line column:self.column];
    
    for(NSInteger i = 0; i < [self.keyValuePairs count]; ++i) {
        LXKeyValuePair *kvp = self.keyValuePairs[i];
        
        if(kvp.key) {
            if(kvp.isBoxed)
                [writer write:@"[" line:self.line column:self.column];
        
            [kvp.key compile:writer];
            
            if(kvp.isBoxed)
                [writer write:@"]" line:self.line column:self.column];
            
            [writer write:@"=" line:self.line column:self.column];
            [kvp.value compile:writer];
        }
        else {
            [kvp.value compile:writer];
        }
        
        if(i < [self.keyValuePairs count]-1) {
            [writer write:@"," line:self.line column:self.column];
        }
    }
    
    [writer write:@"}" line:self.line column:self.column];
}


@end

@implementation LXNodeMemberExpression

- (NSString *)toString {
    return [NSString stringWithFormat:@"%@%@%@", [self.base toString], self.useColon ? @":" : @".", self.value];
}

- (void)compile:(LXLuaWriter *)writer {
    [self.base compile:writer];
    [writer write:[NSString stringWithFormat:@"%@%@", self.useColon ? @":" : @".", self.value] line:self.line column:self.column];
}

@end

@implementation LXNodeIndexExpression

- (NSString *)toString {
    return [NSString stringWithFormat:@"%@[%@]", [self.base toString], [self.index toString]];
}

- (void)compile:(LXLuaWriter *)writer {
    [self.base compile:writer];
    [writer write:@"[" line:self.line column:self.column];
    [self.index compile:writer];
    [writer write:@"]" line:self.line column:self.column];
}

@end

@implementation LXNodeCallExpression

- (NSString *)toString {
    NSString *string = [NSString stringWithFormat:@"%@(", [self.base toString]];
    
    NSInteger index = 0;
    for(LXNode *variable in self.arguments) {
        string = [string stringByAppendingString:[variable toString]];
        
        ++index;
        
        if(index < [self.arguments count]) {
            string = [string stringByAppendingString:@","];
        }
    }
    
    string = [string stringByAppendingString:@")"];

    return string;
}

- (void)compile:(LXLuaWriter *)writer {
    [self.base compile:writer];
    [writer write:@"(" line:self.line column:self.column];
    
    NSInteger index = 0;
    for(LXNode *variable in self.arguments) {
        [variable compile:writer];
        
        ++index;
        
        if(index < [self.arguments count]) {
            [writer write:@"," line:self.line column:self.column];
        }
    }
    
    [writer write:@")" line:self.line column:self.column];
}

@end

@implementation LXNodeStringCallExpression

- (NSString *)toString {
    return [NSString stringWithFormat:@"%@ %@", [self.base toString], self.value];
}

- (void)compile:(LXLuaWriter *)writer {
    [self.base compile:writer];
    
    [writer write:self.value line:self.line column:self.column];
}

@end

@implementation LXNodeTableCallExpression

- (NSString *)toString {
    return [NSString stringWithFormat:@"%@ %@", [self.base toString], [self.table toString]];
}

- (void)compile:(LXLuaWriter *)writer {
    [self.base compile:writer];
    [self.table compile:writer];
}

@end

@implementation LXNodeFunctionExpression

- (NSString *)toString {
    NSString *string = @"";
    
    if(self.name) {
        string = [string stringByAppendingFormat:@"function %@(", [self.name toString]];
    }
    else {
        string = [string stringByAppendingString:@"function("];
    }
    
    NSInteger index = 0;
    for(LXVariable *argument in self.arguments) {
        string = [string stringByAppendingString:argument.name];
        
        ++index;
        
        if(index < [self.arguments count]) {
            string = [string stringByAppendingString:@","];
        }
    }
    
    string = [string stringByAppendingString:@")\n"];
    
    [self openStringScope];
    string = [string stringByAppendingString:[self.body toString]];
    [self closeStringScope];
    
    if([self.body.statements count] > 0) {
        string = [string stringByAppendingString:@"\n"];
    }
    
    string = [string stringByAppendingString:[self indentedString:@"end"]];
    
    return string;
}

- (void)compile:(LXLuaWriter *)writer {
    if(self.name) {
        [writer write:@"function " line:self.line column:self.column];
        [self.name compile:writer];
        [writer write:@"(" line:self.line column:self.column];
    }
    else {
        [writer write:@"function(" line:self.line column:self.column];
    }
    
    NSInteger index = 0;
    for(LXVariable *argument in self.arguments) {
        [writer write:argument.name name:argument.name line:self.line column:self.column];
        
        ++index;
        
        if(index < [self.arguments count]) {
            [writer write:@"," line:self.line column:self.column];
        }
    }
    
    [writer write:@")\n" line:self.line column:self.column];
    
    [self openStringScope];
    [self.body compile:writer];
    [self closeStringScope];
    
    if([self.body.statements count] > 0) {
        [writer write:@"\n" line:self.line column:self.column];
    }
    
    [writer write:@"end" line:self.line column:self.column];
}

@end