//
//  LXLuaWriter.m
//  Luax
//
//  Created by Noah Hilt on 2/16/14.
//  Copyright (c) 2014 Noah Hilt. All rights reserved.
//

#import "LXLuaWriter.h"
#import "NSNumber+Base64VLQ.h"

@interface LXLuaWriter()
@property (nonatomic, strong) NSMutableString *mutableString;
@property (nonatomic, strong) NSMutableArray *mutableMappings;
@property (nonatomic, strong) NSString *lastName;
@property (nonatomic, assign) NSInteger lastLine;
@property (nonatomic, assign) NSInteger lastColumn;
@end

@implementation LXLuaWriter

- (id)init {
    if(self = [super init]) {
        _mutableString = [[NSMutableString alloc] init];
        _mutableMappings = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (NSString *)string {
    return _mutableString;
}

- (NSArray *)mappings {
    return _mutableMappings;
}

- (void)writeSpace {
    [self write:@" "];
}

- (void)writeNewline {
    [self.mutableString appendString:@"\n"];
    
    self.currentLine++;
    self.currentColumn = 0;
    
    [self write:[@"" stringByPaddingToLength:self.indentationLevel*2 withString:@" " startingAtIndex:0]];
}

- (void)write:(NSString *)generated {
    [self.mutableString appendString:generated];
    self.currentColumn += [generated length];
    
    /*NSArray *lines = [generated componentsSeparatedByString:@"\n"];
     
     if([lines count] == 1) {
     [self.mutableString appendString:generated];
     self.currentColumn += [generated length];
     }
     else {
     NSString *line = nil;
     for(NSInteger i = 0; i < [lines count]; ++i) {
     line = lines[i];
     line = (i == 0) ? line : [line stringByPaddingToLength:[line length]+self.indentationLevel*2 withString:@" " startingAtIndex:0];
     line = (i == [lines count]-1) ? line : [line stringByAppendingString:@"\n"];
     
     [self.mutableString appendString:line];
     }
     
     self.currentLine += [lines count] - 1;
     self.currentColumn = [line length];
     }*/
}

- (void)write:(NSString *)generated line:(NSInteger)line column:(NSInteger)column {
    [self write:generated name:nil line:line column:column];
}

- (void)write:(NSString *)generated name:(NSString *)name line:(NSInteger)line column:(NSInteger)column {
    if(line != self.lastLine ||
       column != self.lastColumn ||
       ![name isEqual:self.lastName]) {
        NSDictionary *dictionary = @{@"source" : self.currentSource, @"name" : name ? name : @"", @"original" : @{@"line" : @(line), @"column" : @(column)}, @"generated" : @{@"line" : @(self.currentLine), @"column" : @(self.currentColumn)}};
        
        [self.mutableMappings addObject:dictionary];
        
        self.lastName = name;
        self.lastLine = line;
        self.lastColumn = column;
    }
    
    [self write:generated];
}

/*- (NSDictionary *)originalPosition:(NSInteger)line column:(NSInteger)column {
 NSDictionary *mapping = recursiveSearch(-1, [self.mappings count], @{@"generated" : @{@"line" : @(line), @"column" : @(column)}}, self.mappings, ^(NSDictionary *obj1, NSDictionary *obj2) {
 NSInteger cmp = [obj1[@"generated"][@"line"] integerValue] - [obj2[@"generated"][@"line"] integerValue];
 
 if(cmp > 0)
 return cmp;
 else if(cmp < 0)
 return cmp;
 
 cmp = [obj1[@"generated"][@"column"] integerValue] - [obj2[@"generated"][@"column"] integerValue];
 
 if(cmp > 0)
 return cmp;
 else if(cmp < 0)
 return cmp;
 
 return cmp;
 });
 
 return mapping;
 }
 
 - (NSDictionary *)generatedPosition:(NSInteger)line column:(NSInteger)column {
 NSInteger index = [self.mappings indexOfObject:@{@"original" : @{@"line" : @(line), @"column" : @(column)}} inSortedRange:NSMakeRange(0, [self.mappings count]) options:NSBinarySearchingFirstEqual usingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
 NSInteger cmp = [obj1[@"original"][@"line"] integerValue] - [obj2[@"original"][@"line"] integerValue];
 
 if(cmp > 0)
 return NSOrderedAscending;
 else if(cmp < 0)
 return NSOrderedDescending;
 
 cmp = [obj1[@"original"][@"column"] integerValue] - [obj2[@"original"][@"column"] integerValue];
 
 if(cmp > 0)
 return NSOrderedAscending;
 else if(cmp < 0)
 return NSOrderedDescending;
 
 return NSOrderedSame;
 }];
 
 return self.mappings[index];
 }*/

- (NSDictionary *)generateSourceMap {
    NSMutableArray *sourcesArray = [NSMutableArray array];
    NSMutableDictionary *sourcesMap = [NSMutableDictionary dictionary];
    NSInteger currentSourceIndex = 0;
    
    NSMutableArray *namesArray = [NSMutableArray array];
    NSMutableDictionary *namesMap = [NSMutableDictionary dictionary];
    NSInteger currentNameIndex = 0;
    
    NSInteger previousGeneratedColumn = 0;
    NSInteger previousGeneratedLine = 0;
    NSInteger previousOriginalColumn = 0;
    NSInteger previousOriginalLine = 0;
    NSInteger previousSource = 0;
    NSInteger previousName = 0;
    
    NSString *mappings = @"";
    
    for(NSInteger i = 0; i < [self.mappings count]; ++i) {
        NSDictionary *mapping = self.mappings[i];
        NSInteger generatedLine = [mapping[@"generated"][@"line"] integerValue];
        NSInteger generatedColumn = [mapping[@"generated"][@"column"] integerValue];
        NSInteger originalLine = [mapping[@"original"][@"line"] integerValue];
        NSInteger originalColumn = [mapping[@"original"][@"column"] integerValue];
        NSString *source = mapping[@"source"];
        NSString *name = mapping[@"name"];
        
        if(generatedLine != previousGeneratedLine) {
            previousGeneratedColumn = 0;
            while(generatedLine != previousGeneratedLine) {
                mappings = [mappings stringByAppendingString:@";"];
                previousGeneratedLine++;
            }
        }
        else {
            if(i > 0) {
                NSDictionary *lastMapping = self.mappings[i-1];
                
                if([lastMapping isEqualToDictionary:mapping])
                    continue;
                
                mappings = [mappings stringByAppendingString:@","];
            }
        }
        
        
        mappings = [mappings stringByAppendingString:[@(generatedColumn - previousGeneratedColumn) encode]];
        
        previousGeneratedColumn = generatedColumn;
        
        NSNumber *sourceIndex = sourcesMap[source];
        
        if(!sourceIndex) {
            sourceIndex = [NSNumber numberWithInteger:currentSourceIndex++];
            sourcesMap[source] = sourceIndex;
            
            [sourcesArray addObject:source];
        }
        
        mappings = [mappings stringByAppendingString:[@([sourceIndex integerValue] - previousSource) encode]];
        previousSource = [sourceIndex integerValue];
        
        mappings = [mappings stringByAppendingString:[@(originalLine - previousOriginalLine) encode]];
        
        previousOriginalLine = originalLine;
        
        mappings = [mappings stringByAppendingString:[@(originalColumn - previousOriginalColumn) encode]];
        
        previousOriginalColumn = originalColumn;
        
        if([name length] > 0) {
            NSNumber *nameIndex = namesMap[name];
            
            if(!nameIndex) {
                nameIndex = [NSNumber numberWithInteger:currentNameIndex++];
                namesMap[name] = nameIndex;
                
                [namesArray addObject:name];
                
            }
            
            mappings = [mappings stringByAppendingString:[@([nameIndex integerValue] - previousName) encode]];
            previousName = [nameIndex integerValue];
        }
    }
    
    
    return @{@"version" : @(3), @"sources" : sourcesArray, @"names" : namesArray, @"mappings" : mappings};
}

- (NSArray *)parseMapping:(NSString *)string {
    NSMutableString *mutableString = [NSMutableString stringWithString:string];
    NSMutableArray *newMappings = [NSMutableArray array];
    
    NSInteger generatedLine = 0;
    NSInteger previousGeneratedColumn = 0;
    NSInteger previousOriginalLine = 0;
    NSInteger previousOriginalColumn = 0;
    NSInteger previousSource = 0;
    NSInteger previousName = 0;
    NSCharacterSet *mappingSeparator = [NSCharacterSet characterSetWithCharactersInString:@",;"];
    
    while([mutableString length] > 0) {
        if([mutableString characterAtIndex:0] == ';') {
            generatedLine++;
            [mutableString deleteCharactersInRange:NSMakeRange(0, 1)];
            previousGeneratedColumn = 0;
        }
        else if([string characterAtIndex:0] == ',') {
            string = [string substringFromIndex:1];
        }
        else {
            NSMutableDictionary *mapping = [NSMutableDictionary dictionary];
            NSInteger temp;
            
            temp = [[mutableString decode] integerValue];
            previousGeneratedColumn = previousGeneratedColumn + temp;
            
            mapping[@"generated"] = @{@"line" : @(generatedLine), @"column" : @(previousGeneratedColumn)};
            
            if([mutableString length] > 0 && ![mappingSeparator characterIsMember:[mutableString characterAtIndex:0]]) {
                // Original source.
                temp = [[mutableString decode] integerValue];
                
                //NSInteger source = previousSource + temp;
                previousSource += temp;
                
                if([mutableString length] == 0 || [mappingSeparator characterIsMember:[mutableString characterAtIndex:0]]) {
                    //error
                }
                
                temp = [[mutableString decode] integerValue];
                
                // Original line.
                NSInteger originalLine = previousOriginalLine + temp;
                previousOriginalLine = originalLine;
                
                if([mutableString length] == 0 || [mappingSeparator characterIsMember:[mutableString characterAtIndex:0]]) {
                    //error
                }
                
                temp = [[mutableString decode] integerValue];
                
                NSInteger originalColumn = previousOriginalColumn + temp;
                previousOriginalColumn = originalColumn;
                
                mapping[@"original"] = @{@"line" : @(originalLine), @"column" : @(originalColumn)};
                
                if([mutableString length] > 0 && ![mappingSeparator characterIsMember:[mutableString characterAtIndex:0]]) {
                    // Original name.
                    temp = [[mutableString decode] integerValue];
                    
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