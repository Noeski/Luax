//
//  LXProject.m
//  Luax
//
//  Created by Noah Hilt on 11/24/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXProject.h"
#import "NSString+JSON.h"
#import "NSNumber+Base64VLQ.h"

#include "lua.h"
#include "lualib.h"
#include "lauxlib.h"

typedef enum {
    LXDebugStateStopped,
    LXDebugStateRunning,
    LXDebugStateBreak,
    LXDebugStateError,
    LXDebugStatePause,
    LXDebugStateStepInto,
    LXDebugStateStepOver,
    LXDebugStateStepOut
} LXDebugState;

@interface LXProjectFile()
@property (nonatomic, weak) LXProject *project;
@property (nonatomic, strong) NSString *mutableName;
@property (nonatomic, strong) NSString *mutablePath;
@property (nonatomic, assign) BOOL isMain;
@property (nonatomic, strong) NSMutableDictionary *mutableBreakpoints;
@property (nonatomic, strong) NSMutableDictionary *mutableMappedBreakpoints;
@property (nonatomic, strong) NSString *cachedContents;
@property (nonatomic, strong) NSString *cachedCompiledContents;
@property (nonatomic, strong) NSArray *cachedMappings;
@property (nonatomic, strong) NSDate *lastModifiedDate;
@property (nonatomic, strong) NSDate *lastCompileDate;

+ (NSDateFormatter *)dateFormatter;
@end

@implementation LXProjectFile

- (id)initWithProject:(LXProject *)project {    
    if(self = [super init]) {
        _project = project;
        _context = [[LXContext alloc] initWithName:nil compiler:project.compiler];
        _mutableBreakpoints = [[NSMutableDictionary alloc] init];
        _mutableMappedBreakpoints = [[NSMutableDictionary alloc] init];
        _lastModifiedDate = [NSDate date];
        _lastCompileDate = [NSDate dateWithTimeIntervalSince1970:0];
    }
    
    return self;
}

- (NSString *)name {
    return self.mutableName;
}

- (void)setMutableName:(NSString *)mutableName {
    _mutableName = mutableName;
    _uid = [_mutableName MD5Hash];
}

- (NSString *)path {
    return [self.project.path stringByAppendingString:self.mutablePath];
}

- (NSDictionary *)breakpoints {
    return _mutableBreakpoints;
}

- (NSString *)contents {
    if(!_cachedContents) {
        _cachedContents = [NSString stringWithContentsOfFile:self.path encoding:NSUTF8StringEncoding error:nil];
    }

    return _cachedContents;
}

- (NSString *)compiledContents {
    if(!_cachedCompiledContents) {
        NSString *path = [self.project.path stringByAppendingFormat:@"/.build/%@.lua", [self.name stringByDeletingPathExtension]];

        _cachedCompiledContents = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];
    }
    
    return _cachedCompiledContents;
}

- (NSArray *)cachedMappings {
    if(!_cachedMappings) {
        NSString *path = [self.project.path stringByAppendingFormat:@"/.build/%@.map", [self.name stringByDeletingPathExtension]];
        NSDictionary *mapContents = [[NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil] JSONValue];
        
        if(mapContents)
            _cachedMappings = [self parseMapping:mapContents[@"mappings"]];
    }
    
    return _cachedMappings;
}

- (void)setContents:(NSString *)contents {
    _cachedContents = contents;
    
    [_cachedContents writeToFile:self.path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    self.lastModifiedDate = [NSDate date];
}

- (BOOL)isCompiled {
    return [self.lastCompileDate isGreaterThan:self.lastModifiedDate];
}

- (BOOL)hasErrors {
    return [self.context.errors count];
}

- (void)addBreakpoint:(NSInteger)line {
    self.mutableBreakpoints[@(line)] = @YES;
    
    if(self.cachedMappings) {
        self.mutableMappedBreakpoints[@([self generatedLine:line-1])] = @(line);
    }
}

- (void)removeBreakpoint:(NSInteger)line {
    [self.mutableBreakpoints removeObjectForKey:@(line)];
    
    if(self.cachedMappings) {
        [self.mutableMappedBreakpoints removeObjectForKey:@([self generatedLine:line-1])];
    }
}

- (NSDictionary *)save {
    return [NSDictionary dictionaryWithObjectsAndKeys:self.uid, @"uid", self.name, @"name", self.mutablePath, @"path", [[LXProjectFile dateFormatter] stringFromDate:self.lastModifiedDate], @"modified", [[LXProjectFile dateFormatter] stringFromDate:self.lastCompileDate], @"build", self.isMain ? @(YES) : nil, @"isMain", nil];
}

- (void)load:(NSDictionary *)dictionary {
    self.lastModifiedDate = [[LXProjectFile dateFormatter] dateFromString:dictionary[@"modified"]];
    self.lastCompileDate = [[LXProjectFile dateFormatter] dateFromString:dictionary[@"build"]];

    self.mutableName = [dictionary[@"name"] copy];
    self.mutablePath = [dictionary[@"path"] copy];
    self.isMain = [dictionary[@"isMain"] boolValue];
}

- (void)compile {
    if([self isCompiled]) {
        return;
    }
    
    self.cachedCompiledContents = nil;
    self.cachedMappings = nil;
    
    [self.context compile:self.contents];
    
    if([self hasErrors]) {
        return;
    }
    
    LXLuaWriter *writer = [[LXLuaWriter alloc] init];
    writer.currentSource = self.name;
    [self.context.block compile:writer];
    
    self.cachedMappings = writer.mappings;
    
    [self.mutableMappedBreakpoints removeAllObjects];
    
    for(NSNumber *breakpoint in [self.breakpoints allKeys]) {
        self.mutableMappedBreakpoints[@([self generatedLine:[breakpoint integerValue]-1])] = breakpoint;
    }
    
    NSString *path = [self.project.path stringByAppendingFormat:@"/.build/%@.lua", [self.name stringByDeletingPathExtension]];
    [writer.string writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    NSString *mapPath = [self.project.path stringByAppendingFormat:@"/.build/%@.map", [self.name stringByDeletingPathExtension]];
    [[[self generateSourceMap:self.cachedMappings] JSONRepresentation] writeToFile:mapPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    self.lastCompileDate = [NSDate date];
}

- (void)clean {
    NSString *path = [self.project.path stringByAppendingFormat:@"/.build/%@.lua", [self.name stringByDeletingPathExtension]];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    NSString *mapPath = [self.project.path stringByAppendingFormat:@"/.build/%@.map", [self.name stringByDeletingPathExtension]];
    [[NSFileManager defaultManager] removeItemAtPath:mapPath error:nil];
    self.lastCompileDate = [NSDate dateWithTimeIntervalSince1970:0];
}

- (NSDictionary *)generateSourceMap:(NSArray *)mappings {
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
    
    NSString *mappingString = @"";
    
    for(NSInteger i = 0; i < [mappings count]; ++i) {
        NSDictionary *mapping = mappings[i];
        NSInteger generatedLine = [mapping[@"generated"][@"line"] integerValue];
        NSInteger generatedColumn = [mapping[@"generated"][@"column"] integerValue];
        NSInteger originalLine = [mapping[@"original"][@"line"] integerValue];
        NSInteger originalColumn = [mapping[@"original"][@"column"] integerValue];
        NSString *source = mapping[@"source"];
        NSString *name = mapping[@"name"];
        
        if(generatedLine != previousGeneratedLine) {
            previousGeneratedColumn = 0;
            while(generatedLine != previousGeneratedLine) {
                mappingString = [mappingString stringByAppendingString:@";"];
                previousGeneratedLine++;
            }
        }
        else {
            if(i > 0) {
                NSDictionary *lastMapping = mappings[i-1];
                
                if([lastMapping isEqualToDictionary:mapping])
                    continue;
                
                mappingString = [mappingString stringByAppendingString:@","];
            }
        }
        
        
        mappingString = [mappingString stringByAppendingString:[@(generatedColumn - previousGeneratedColumn) encode]];
        
        previousGeneratedColumn = generatedColumn;
        
        NSNumber *sourceIndex = sourcesMap[source];
        
        if(!sourceIndex) {
            sourceIndex = [NSNumber numberWithInteger:currentSourceIndex++];
            sourcesMap[source] = sourceIndex;
            
            [sourcesArray addObject:source];
        }
        
        mappingString = [mappingString stringByAppendingString:[@([sourceIndex integerValue] - previousSource) encode]];
        previousSource = [sourceIndex integerValue];
        
        mappingString = [mappingString stringByAppendingString:[@(originalLine - previousOriginalLine) encode]];
        
        previousOriginalLine = originalLine;
        
        mappingString = [mappingString stringByAppendingString:[@(originalColumn - previousOriginalColumn) encode]];
        
        previousOriginalColumn = originalColumn;
        
        if([name length] > 0) {
            NSNumber *nameIndex = namesMap[name];
            
            if(!nameIndex) {
                nameIndex = [NSNumber numberWithInteger:currentNameIndex++];
                namesMap[name] = nameIndex;
                
                [namesArray addObject:name];
                
            }
            
            mappingString = [mappingString stringByAppendingString:[@([nameIndex integerValue] - previousName) encode]];
            previousName = [nameIndex integerValue];
        }
    }
    
    return @{@"version" : @(3), @"sources" : sourcesArray, @"names" : namesArray, @"mappings" : mappingString};
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

id recursiveSearch(NSInteger low, NSInteger high, id needle, NSArray *haystack, NSInteger (^comparator)(id obj1, id obj2)) {
    NSInteger mid = floor((high - low) / 2) + low;
    NSInteger cmp = comparator(needle, haystack[mid]);
    
    if(cmp == 0) {
        return haystack[mid];
    }
    else if(cmp > 0) {
        if(high - mid > 1) {
            return recursiveSearch(mid, high, needle, haystack, comparator);
        }
        
        return haystack[mid];
    }
    else {
        if(mid - low > 1) {
            return recursiveSearch(low, mid, needle, haystack, comparator);
        }
        
        return low < 0 ? nil : haystack[low];
    }
}

- (NSInteger)originalLine:(NSInteger)line {
    NSDictionary *mapping = recursiveSearch(-1, [self.cachedMappings count], @(line), self.cachedMappings, ^(NSNumber *obj1, NSDictionary *obj2) {
        NSInteger cmp = [obj1 integerValue] - [obj2[@"generated"][@"line"] integerValue];
        
        return cmp;
    });
    
    return [mapping[@"original"][@"line"] integerValue]+1;
}

- (NSInteger)generatedLine:(NSInteger)line {
    NSDictionary *mapping = recursiveSearch(-1, [self.cachedMappings count], @(line), self.cachedMappings, ^(NSNumber *obj1, NSDictionary *obj2) {
        NSInteger cmp = [obj1 integerValue] - [obj2[@"original"][@"line"] integerValue];
        
        return cmp;
    });
    
    return [mapping[@"generated"][@"line"] integerValue]+1;
}

+ (NSDateFormatter *)dateFormatter {
    static __strong NSDateFormatter *dateFormatter = nil;
    
    if(!dateFormatter) {
        dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"];
        [dateFormatter setTimeZone:[NSTimeZone timeZoneWithAbbreviation:@"UTC"]];
    }
    
    return dateFormatter;
}

@end

@interface LXProjectFileReference()
@property (nonatomic, strong) LXProjectGroup *mutableParent;
@end

@implementation LXProjectFileReference

- (id)initWithParent:(LXProjectGroup *)parent {
    if(self = [super init]) {
        _mutableParent = parent;
    }
    
    return self;
}

- (id)initWithParent:(LXProjectGroup *)parent file:(LXProjectFile *)file {
    if(self = [super init]) {
        _mutableParent = parent;
        _file = file;
    }
    
    return self;
}

- (LXProjectGroup *)parent {
    return self.mutableParent;
}

- (NSString *)name {
    return self.file.name;
}

- (NSDictionary *)save {
    return @{@"uid" : self.file.uid, @"name" : self.name};
}

- (void)load:(NSDictionary *)dictionary project:(LXProject *)project {
    NSString *uid = dictionary[@"uid"];
    
    for(LXProjectFile *file in project.files) {
        if([file.uid isEqualToString:uid]) {
            _file = file;
            break;
        }
    }
}

@end

@interface LXProjectGroup()
@property (nonatomic, strong) NSString *mutableName;
@property (nonatomic, strong) NSMutableArray *mutableChildren;
@end

@implementation LXProjectGroup

- (id)initWithParent:(LXProjectGroup *)parent {
    if(self = [super initWithParent:parent]) {
        _mutableName = @"New Group";
        _mutableChildren = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (NSString *)name {
    return self.mutableName;
}

- (NSArray *)children {
    return self.mutableChildren;
}

- (NSDictionary *)save {
    NSMutableArray *children = [[NSMutableArray alloc] init];
    
    for(LXProjectFile *child in self.children) {
        [children addObject:[child save]];
    }
    
    return @{@"name" : self.name, @"children" : children};
}

- (void)load:(NSDictionary *)dictionary project:(LXProject *)project {
    NSArray *children = dictionary[@"children"];
    
    for(NSDictionary *child in children) {
        if(child[@"children"]) {
            LXProjectGroup *group = [[LXProjectGroup alloc] initWithParent:self];
            [group load:child project:project];
            
            [self.mutableChildren addObject:group];
        }
        else {
            LXProjectFileReference *file = [[LXProjectFileReference alloc] initWithParent:self];
            [file load:child project:project];
            
            [self.mutableChildren addObject:file];
        }
    }
}

@end


@interface LXProject() {
    NSOperationQueue *_queue;
    lua_State *_state;
    jmp_buf _jmp;
}

@property (atomic, assign) LXDebugState debugState;
@property (nonatomic, assign) NSInteger functionLevel;
@property (nonatomic, assign) NSInteger stopLevel;

@property (nonatomic, readonly) NSMutableArray *mutableFiles;
@property (nonatomic, weak) LXProjectFile *mainFile;
@end

@implementation LXProject

- (id)init {
    if(self = [super init]) {
        _queue = [[NSOperationQueue alloc] init];
        _mutableFiles = [[NSMutableArray alloc] init];
        _root = [[LXProjectGroup alloc] initWithParent:nil];
        _compiler = [[LXCompiler alloc] init];
    }
    
    return self;
}

- (NSArray *)files {
    return self.mutableFiles;
}

- (void)save {
    NSMutableArray *files = [[NSMutableArray alloc] init];
    
    for(LXProjectFile *file in self.files) {
        [files addObject:[file save]];
    }
    
    NSMutableArray *children = [[NSMutableArray alloc] init];
    
    for(LXProjectFile *child in self.root.children) {
        [children addObject:[child save]];
    }

    NSDictionary *dictionary = @{@"name" : self.name, @"version" : @"1", @"files" : files, @"root" : children};
    
    [[dictionary JSONRepresentation] writeToFile:[NSString stringWithFormat:@"%@/%@.luxproj", self.path, self.name] atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

- (void)load:(NSDictionary *)dictionary {
    self.name = [dictionary[@"name"] copy];
    
    NSArray *files = dictionary[@"files"];

    for(NSDictionary *file in files) {
        LXProjectFile *projectFile = [[LXProjectFile alloc] initWithProject:self];
        [projectFile load:file];
        [self.mutableFiles addObject:projectFile];
        
        if(projectFile.isMain) {
            if(self.mainFile) {
                //error
            }
            
            self.mainFile = projectFile;
        }
    }
    
    NSArray *children = dictionary[@"root"];
    
    for(NSDictionary *child in children) {
        if(child[@"children"]) {
            LXProjectGroup *group = [[LXProjectGroup alloc] initWithParent:self.root];
            [group load:child project:self];
            
            [self.root.mutableChildren addObject:group];
        }
        else {
            LXProjectFileReference *file = [[LXProjectFileReference alloc] initWithParent:self.root];
            [file load:child project:self];
            
            [self.root.mutableChildren addObject:file];
        }
    }
}

- (void)compile {
    for(LXProjectFile *child in self.files) {
        [child compile];
    }
    
    [self save];
}

- (void)clean {
    for(LXProjectFile *child in self.files) {
        [child clean];
    }
    
    [self save];
}

int luaError(lua_State *L) {
	NSString *error;
	
	if (lua_type(L, -1) == LUA_TSTRING)
		error = [NSString stringWithFormat:@"%s", luaL_checkstring(L, -1)];
	else if (lua_type(L, -1) == LUA_TNUMBER)
		error = [NSString stringWithFormat:@"Lua error %d", (int)luaL_checknumber(L, -1)];
	else
		error = @"<UNKNOWN LUA ERROR>";
    
	if([error hasPrefix:@"[string"]) {
        NSInteger firstQuoteIndex = [error rangeOfString:@"\""].location+1;
        NSInteger secondQuoteIndex = [error rangeOfString:@"\"" options:0 range:NSMakeRange(firstQuoteIndex, [error length]-firstQuoteIndex)].location;
        
        NSString *sourceName = [[error substringWithRange:NSMakeRange(firstQuoteIndex, secondQuoteIndex-firstQuoteIndex)] stringByDeletingPathExtension];
        
		NSInteger firstColonIndex = [error rangeOfString:@":" options:0 range:NSMakeRange(secondQuoteIndex, [error length]-secondQuoteIndex)].location+1;
		NSInteger secondColonIndex = [error rangeOfString:@":" options:0 range:NSMakeRange(firstColonIndex, [error length]-firstColonIndex)].location;
		
		NSInteger line = [[error substringWithRange:NSMakeRange(firstColonIndex, secondColonIndex-firstColonIndex)] integerValue];
		
        //NSString *errorString = [NSString stringWithFormat:@"Error: %@", error];
        
        LXProject *project = [LXProject stateMap][@((NSInteger)L)];
        LXProjectFile *sourceFile = nil;
        
        for(LXProjectFile *file in project.files) {
            if([[file.name stringByDeletingPathExtension] isEqualToString:sourceName]) {
                sourceFile = file;
                break;
            }
        }
        
        [project breakLoop:sourceFile line:[sourceFile originalLine:line-1] error:YES];
	}
	
	return 1;
}

int luaCall(lua_State *L, int nargs, int nresults) {
	int	base = lua_gettop(L) - nargs;
	lua_pushcfunction(L, luaError);
	lua_insert(L, base);
    
	int	res = lua_pcall(L, nargs, nresults, base);
    
	lua_remove(L, base);
	
	return res;
}

void breakpointHook(lua_State* L, lua_Debug* dbg) {
    LXProject *project = [LXProject stateMap][@((NSInteger)L)];

    [project checkBreakpoints:L debug:dbg];
}

void defaultHook(lua_State* L, lua_Debug* dbg) {
    LXProject *project = [LXProject stateMap][@((NSInteger)L)];

    lua_getinfo(L, "Sl", dbg);
	
	if(strcmp("C", dbg->what) == 0)
		return;
    
    NSString *sourceName = [[[NSString stringWithFormat:@"%s", dbg->source] lastPathComponent] stringByDeletingPathExtension];
    LXProjectFile *sourceFile = nil;
    
    for(LXProjectFile *file in project.files) {
        if([[file.name stringByDeletingPathExtension] isEqualToString:sourceName]) {
            sourceFile = file;
            break;
        }
    }
    
    [project breakLoop:sourceFile line:[sourceFile originalLine:dbg->currentline-1] error:NO];
}

void stepOverHook(lua_State* L, lua_Debug* dbg) {
    LXProject *project = [LXProject stateMap][@((NSInteger)L)];

    switch(dbg->event) {
		case LUA_HOOKTAILCALL:
		case LUA_HOOKCALL:
			project.functionLevel++;
			break;
			
		case LUA_HOOKRET:
			project.functionLevel--;
			break;
			
		case LUA_HOOKLINE:
            if([project checkBreakpoints:L debug:dbg])
                return;
            
			if(project.stopLevel >= project.functionLevel) {
				lua_getinfo(L, "Sl", dbg);
				
                NSString *sourceName = [[[NSString stringWithFormat:@"%s", dbg->source] lastPathComponent] stringByDeletingPathExtension];
                LXProjectFile *sourceFile = nil;
                
                for(LXProjectFile *file in project.files) {
                    if([[file.name stringByDeletingPathExtension] isEqualToString:sourceName]) {
                        sourceFile = file;
                        break;
                    }
                }
                
                [project breakLoop:sourceFile line:[sourceFile originalLine:dbg->currentline-1] error:NO];
			}
			
			break;
	}
}

void stepOutHook(lua_State* L, lua_Debug* dbg) {
    LXProject *project = [LXProject stateMap][@((NSInteger)L)];

    switch(dbg->event) {
		case LUA_HOOKTAILCALL:
		case LUA_HOOKCALL:
			project.functionLevel++;
			break;
			
		case LUA_HOOKRET:
			project.functionLevel--;
			break;
			
		case LUA_HOOKLINE:
            if([project checkBreakpoints:L debug:dbg])
                return;
            
			if(project.stopLevel > project.functionLevel) {
				lua_getinfo(L, "Sl", dbg);
				
                NSString *sourceName = [[[NSString stringWithFormat:@"%s", dbg->source] lastPathComponent] stringByDeletingPathExtension];
                LXProjectFile *sourceFile = nil;
                
                for(LXProjectFile *file in project.files) {
                    if([[file.name stringByDeletingPathExtension] isEqualToString:sourceName]) {
                        sourceFile = file;
                        break;
                    }
                }
                
                [project breakLoop:sourceFile line:[sourceFile originalLine:dbg->currentline-1] error:NO];
			}
			
			break;
	}
}

void stopHook(lua_State* L, lua_Debug* dbg) {
    LXProject *project = [LXProject stateMap][@((NSInteger)L)];

    longjmp(project->_jmp, 1);
}

- (void)run {
    [self compile];
    
    if([self isRunning]) {
        [self stopExecution];
    }
    
    [_queue addOperationWithBlock:^{
        self.debugState = LXDebugStateRunning;

        _state = luaL_newstate();
        [LXProject stateMap][@((NSInteger)_state)] = self;
        
        luaL_openlibs(_state);
        
        lua_getglobal(_state, "package");
        lua_getfield(_state, -1, "path");
        NSString *path = [NSString stringWithUTF8String:lua_tostring(_state, -1)];
        path = [path stringByAppendingFormat:@";%@/?.lua", [NSString stringWithFormat:@"%@/.build", self.path]];
        lua_pop(_state, 1);
        lua_pushstring(_state, [path UTF8String]);
        lua_setfield(_state, -2, "path" );
        lua_pop(_state, 1 );
        
        NSString *source = self.mainFile.compiledContents;
        
        int status = luaL_loadbuffer(_state, [source UTF8String], [source length], [self.mainFile.name UTF8String]);

        if(status != 0) {
            const char *error = lua_tostring(_state, -1);
            lua_pop(_state, 1);
            
            NSLog(@"%s", error);
        }
        
        lua_sethook(_state, breakpointHook, LUA_MASKLINE, 0);
        
        int top = lua_gettop(_state);
        
        for(int i = 0; i < top; ++i) {
            if(setjmp(_jmp) != 0)
                break;
            
            luaCall(_state, 0, LUA_MULTRET);
        }
        
        lua_close(_state);
        
        [[LXProject stateMap] removeObjectForKey:@((NSInteger)_state)];
        _state = NULL;
        
        self.debugState = LXDebugStateStopped;
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if([self.delegate respondsToSelector:@selector(projectFinishedRunning:)])
               [self.delegate projectFinishedRunning:self];
        });
    }];
}

- (void)stopExecution {
    [self continueExecution:LXDebugStateStopped];
    [_queue waitUntilAllOperationsAreFinished];
}

- (void)continueExecution:(LXDebugState)state {
    if(self.debugState == state)
        return;
    
    self.stopLevel = self.functionLevel;
    
    switch(state) {
        case LXDebugStateRunning:
            lua_sethook(_state, breakpointHook, LUA_MASKLINE, 0);
            break;
        case LXDebugStatePause:
            lua_sethook(_state, defaultHook, LUA_MASKLINE, 0);
            break;
        case LXDebugStateStepInto:
            lua_sethook(_state, defaultHook, LUA_MASKLINE, 0);
            break;
        case LXDebugStateStepOver:
            lua_sethook(_state, stepOverHook, LUA_MASKLINE | LUA_MASKCALL | LUA_MASKRET, 0);
            break;
        case LXDebugStateStepOut:
            lua_sethook(_state, stepOutHook, LUA_MASKLINE | LUA_MASKCALL | LUA_MASKRET, 0);
            break;
        case LXDebugStateStopped:
            lua_sethook(_state, stopHook, LUA_MASKLINE, 0);
        default:
            break;
    }
    
    self.debugState = state;
}

- (void)continueExecution {
    [self continueExecution:LXDebugStateRunning];
}

- (void)pauseExecution {
    [self continueExecution:LXDebugStatePause];
}

- (void)stepInto {
    [self continueExecution:LXDebugStateStepInto];
}

- (void)stepOver {
    [self continueExecution:LXDebugStateStepOver];
}

- (void)stepOut {
    [self continueExecution:LXDebugStateStepOut];
}

- (BOOL)isRunning {
    return self.debugState != LXDebugStateStopped;
}

- (BOOL)checkBreakpoints:(lua_State *)state debug:(lua_Debug *)debug {
    NSString *sourceName = nil;
    
    for(LXProjectFile *file in self.files) {
        NSNumber *breakpoint = file.mutableMappedBreakpoints[@(debug->currentline)];
        
        if(breakpoint) {
            if(!sourceName) {
                lua_getinfo(state, "Sl", debug);
                
                sourceName = [[[NSString stringWithFormat:@"%s", debug->source] lastPathComponent] stringByDeletingPathExtension];
            }
            
            if([[file.name stringByDeletingPathExtension] isEqualToString:sourceName]) {
                [self breakLoop:file line:[breakpoint integerValue] error:NO];
                return YES;
            }
        }
    }
    
    return NO;
}

- (void)breakLoop:(LXProjectFile *)file line:(NSInteger)line error:(BOOL)error {
    LXDebugState state = self.debugState;
    
	if(state == LXDebugStateBreak || state == LXDebugStateError)
		return;
    
    if(error) {
        self.debugState = LXDebugStateError;
    }
    else {
        self.debugState = LXDebugStateBreak;
    }
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if([self.delegate respondsToSelector:@selector(project:file:didBreakAtLine:error:)]) {
            [self.delegate project:self file:file didBreakAtLine:line error:error];
        }
    });
    
    [self updateStack];
    
    do {
        usleep(100000);
        
        state = self.debugState;
    }
    while(state == LXDebugStateBreak ||
          state == LXDebugStateError);
}

NSString *lua_toKey(lua_State* state, int stack_index) {
    if(stack_index < 0 ){
		stack_index = lua_gettop(state)+(stack_index+1);
	}
	
	switch(lua_type(state,stack_index)){
		case LUA_TNUMBER:
            return [NSString stringWithFormat:@"%f", lua_tonumber(state, stack_index)];
		case LUA_TBOOLEAN:
			return lua_toboolean(state, stack_index) ? @"true" : @"false";
		case LUA_TSTRING:
			return [NSString stringWithFormat:@"%s", lua_tostring(state, stack_index)];
		case LUA_TTABLE:
            return [NSString stringWithFormat:@"table@0x%p", lua_topointer(state, stack_index)];
		case LUA_TFUNCTION:
            return [NSString stringWithFormat:@"function@0x%p", lua_topointer(state, stack_index)];
		case LUA_TUSERDATA:
            return [NSString stringWithFormat:@"userdata@0x%p", lua_topointer(state, stack_index)];
		case LUA_TTHREAD:
            return [NSString stringWithFormat:@"thread@0x%p", lua_topointer(state, stack_index)];
		case LUA_TLIGHTUSERDATA:
            return [NSString stringWithFormat:@"lightuserdata@0x%p", lua_topointer(state, stack_index)];
		case LUA_TNIL:
		default:
			return @"NULL";
	}
}

void lua_toValue(NSMutableDictionary *valueMap, lua_State* state, int stack_index, NSMutableArray *tables, NSMutableDictionary* tablesVisited) {
	if(stack_index < 0) {
		stack_index = lua_gettop(state)+(stack_index+1);
	}
    
	switch(lua_type(state, stack_index)) {
        case LUA_TBOOLEAN: {
            valueMap[@"type"] = @"boolean";
            valueMap[@"value"] = @(lua_toboolean(state, stack_index));
            break;
		}
		case LUA_TNUMBER: {
            valueMap[@"type"] = @"number";
            valueMap[@"value"] = @(lua_tonumber(state, stack_index));
            break;
		}
        case LUA_TSTRING: {
            valueMap[@"type"] = @"string";
            valueMap[@"value"] = [NSString stringWithFormat:@"%s", lua_tostring(state, stack_index)];
            break;
		}
		case LUA_TTABLE: {
            valueMap[@"type"] = @"table";
            
			size_t ptr = (size_t)lua_topointer(state, stack_index);
            valueMap[@"value"] = @(ptr);

			if(!tablesVisited[@(ptr)]) {
				tablesVisited[@(ptr)] = @YES;
                
                NSMutableDictionary *table = [NSMutableDictionary dictionary];
                table[@"ptr"] = @(ptr);
                
                NSMutableArray *tableValues = [NSMutableArray array];
                
                lua_pushnil(state);
                
				while(lua_next(state, stack_index) != 0) {
                    NSMutableDictionary *tableValue = [NSMutableDictionary dictionary];

                    NSString *key = lua_toKey(state, -2);
                    tableValue[@"name"] = key;
                    
                    lua_toValue(tableValue, state, -1, tables, tablesVisited);
					
                    [tableValues addObject:tableValue];
                    
					lua_pop(state, 1);
				}
                
                table[@"values"] = tableValues;
                
                [tables addObject:table];
			}
            
            break;
		}
        case LUA_TFUNCTION: {
            valueMap[@"type"] = @"function";
            valueMap[@"value"] = @((size_t)lua_topointer(state, stack_index));
            break;
        }
        case LUA_TUSERDATA: {
            valueMap[@"type"] = @"userdata";
            valueMap[@"value"] = @((size_t)lua_topointer(state, stack_index));
            break;
        }
        case LUA_TTHREAD: {
            valueMap[@"type"] = @"thread";
            valueMap[@"value"] = @((size_t)lua_topointer(state, stack_index));
            break;
        }
        case LUA_TLIGHTUSERDATA: {
            valueMap[@"type"] = @"lightuserdata";
            valueMap[@"value"] = @((size_t)lua_topointer(state, stack_index));
            break;
        }
		case LUA_TNIL:
		default: {
            valueMap[@"type"] = @"nil";
            break;
		}
	}    
}

- (void)updateStack {
    NSMutableDictionary *root = [NSMutableDictionary dictionary];
    
    int callStackSize = 0;
    
    NSMutableArray *stack = [NSMutableArray array];
    NSMutableArray *tables = [NSMutableArray array];
    NSMutableDictionary *tablesVisited = [NSMutableDictionary dictionary];
    
    int stackDepth = 0;
    
    //We are inside our error handler function so skip it
    if(self.debugState == LXDebugStateError)
        stackDepth++;
    
    for(; true; ++stackDepth) {
        lua_Debug ar;
        
        bool ok = lua_getstack(_state, stackDepth, &ar);
        
        if(!ok)
            break;
        
        lua_getinfo(_state, "funSl", &ar);
        int funcidx = lua_gettop(_state);
        
        NSMutableDictionary *callValue = [NSMutableDictionary dictionary];
        
        NSString *source;
        
        if(strcmp(ar.source, "=[C]") == 0) {
            source = @"<C>";
        }
        else {
            source = [NSString stringWithFormat:@"%s", ar.source];
        }
        
        NSString *function;
        
        if(ar.name != NULL) {
            function = [NSString stringWithFormat:@"%s", ar.name];
        }
        else {
            function = @"<anon>";
        }
        
        callValue[@"source"] = source;
        callValue[@"function"] = function;
        callValue[@"line"] = @(ar.currentline);
        callValue[@"firstline"] = @(ar.linedefined);
        callValue[@"lastline"] = @(ar.lastlinedefined);

        NSMutableArray *locals = [NSMutableArray array];
        
        for(int i = 1; true; ++i) {
            const char *key = lua_getlocal(_state, &ar, i);
            if(key == NULL)
                break;
            
            NSMutableDictionary *value = [NSMutableDictionary dictionary];
            value[@"name"] = [NSString stringWithFormat:@"%s", key];
            value[@"where"] = @(stackDepth);
            value[@"index"] = @(i);
            
            lua_toValue(value, _state, lua_gettop(_state), tables, tablesVisited);
            
            [locals addObject:value];
            lua_pop(_state, 1);
        }
        
        callValue[@"locals"] = locals;
        
        NSMutableArray *upvalues = [NSMutableArray array];
        
        for(int i = 1; true; ++i) {
            const char *key = lua_getupvalue(_state, funcidx, i);
            if(key == NULL)
                break;
            
            NSMutableDictionary *value = [NSMutableDictionary dictionary];
            value[@"name"] = [NSString stringWithFormat:@"%s", key];
            value[@"where"] = @(stackDepth);
            value[@"index"] = @(i);
            
            lua_toValue(value, _state, -1, tables, tablesVisited);
            
            [upvalues addObject:value];
            lua_pop(_state, 1);
        }
        
        callValue[@"upvalues"] = upvalues;
        
        lua_pop(_state, 1);
        
        [stack addObject:callValue];
        
        callStackSize++;
    }
    
    root[@"stack"] = stack;
    
    NSMutableDictionary *globals = [NSMutableDictionary dictionary];
    globals[@"name"] = @"_G";
    
    lua_getglobal(_state, "_G");
    lua_toValue(globals, _state, -1, tables, tablesVisited);
    
    lua_pop(_state, 1);
    
    root[@"globals"] = globals;
    root[@"tables"] = tables;
}

+ (NSMutableDictionary *)stateMap {
    static NSMutableDictionary *stateMap = nil;
    
    if(!stateMap) {
        stateMap = [[NSMutableDictionary alloc] init];
    }
    
    return stateMap;
}

- (LXProjectGroup *)insertGroup:(LXProjectGroup *)parent atIndex:(NSInteger)index {
    LXProjectGroup *group = [[LXProjectGroup alloc] initWithParent:parent];
    [parent.mutableChildren insertObject:group atIndex:index];
    
    [self save];
    
    return group;
}

- (LXProjectFile *)insertFile:(LXProjectGroup *)parent atIndex:(NSInteger)index {
    NSArray *fileNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[NSString stringWithFormat:@"%@/Source", self.path] error:nil];
    NSString *fileName;
    
    NSInteger highestIndex = -1;
    
    for(fileName in fileNames) {
        fileName = [fileName stringByDeletingPathExtension];
        
        if([fileName hasPrefix:@"Untitled"]) {
            NSInteger index = [[fileName substringFromIndex:8] integerValue];
            
            if(index > highestIndex)
                highestIndex = index;
        }
    }
    
    LXProjectFile *file = [[LXProjectFile alloc] initWithProject:self];
    file.mutableName = [NSString stringWithFormat:@"Untitled%@.lux", highestIndex >= 0 ? @(highestIndex+1) : @""];
    file.mutablePath = [NSString stringWithFormat:@"/Source/%@", file.name];
    [self.mutableFiles addObject:file];
    
    [[NSFileManager defaultManager] createFileAtPath:[NSString stringWithFormat:@"%@/Source/%@", self.path, file.name] contents:[NSData data] attributes:nil];
    
    LXProjectFileReference *fileReference = [[LXProjectFileReference alloc] initWithParent:parent file:file];
    [parent.mutableChildren insertObject:fileReference atIndex:index];

    [self save];
    
    return file;
}

- (void)insertFile:(LXProjectFileReference *)file parent:(LXProjectGroup *)parent atIndex:(NSInteger)index {
    [file.parent.mutableChildren removeObject:file];
    file.mutableParent = parent;
    [file.parent.mutableChildren insertObject:file atIndex:index];
    
    [self save];
}

- (void)removeFileRecursive:(LXProjectFileReference *)file {
    if([file class] == [LXProjectFileReference class]) {
        [self.mutableFiles removeObject:file.file];
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/Source/%@", self.path, file.name] error:nil];
    }
    else {
        LXProjectGroup *group = (LXProjectGroup *)file;
        
        for(LXProjectFileReference *child in group.children) {
            [self removeFileRecursive:child];
        }
    }
}

- (void)removeFile:(LXProjectFileReference *)file {
    [self removeFileRecursive:file];
    
    [file.parent.mutableChildren removeObject:file];
    
    [self save];
}

- (void)setFileName:(LXProjectFileReference *)file name:(NSString *)name {
    if([file class] == [LXProjectFileReference class]) {
        [[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"%@/Source/%@", self.path, file.name] toPath:[NSString stringWithFormat:@"%@/Source/%@", self.path, name] error:nil];
        
        file.file.mutableName = name;
        file.file.mutablePath = [NSString stringWithFormat:@"/Source/%@", file.name];
    }
    else {
        LXProjectGroup *group = (LXProjectGroup *)file;

        group.mutableName = name;
    }
    
    [self save];
}

+ (LXProject *)createNewProject:(NSString *)name path:(NSString *)path error:(NSError **)error {
    path = [NSString stringWithFormat:@"%@/%@", path, name];
    
    BOOL success = [[NSFileManager defaultManager] createDirectoryAtPath:path withIntermediateDirectories:NO attributes:nil error:error];
    
    if(!success)
        return nil;
    
    success = [[NSFileManager defaultManager] createDirectoryAtPath:[NSString stringWithFormat:@"%@/Source", path] withIntermediateDirectories:NO attributes:nil error:error];
    
    if(!success)
        return nil;
    
    success = [[NSFileManager defaultManager] createDirectoryAtPath:[NSString stringWithFormat:@"%@/.build", path] withIntermediateDirectories:NO attributes:nil error:error];

    if(!success)
        return nil;
    
    LXProject *project = [[LXProject alloc] init];
    project.name = name;
    project.path = path;
    
    LXProjectFile *file = [[LXProjectFile alloc] initWithProject:project];
    file.mutableName = @"main.lux";
    file.mutablePath = [NSString stringWithFormat:@"/Source/%@", file.name];
    file.isMain = YES;
    project.mainFile = file;
    [project.mutableFiles addObject:file];
    
    [[NSFileManager defaultManager] createFileAtPath:[NSString stringWithFormat:@"%@/Source/%@", project.path, file.name] contents:[@"function main()\n  print('hello world')\nend\n\nmain()" dataUsingEncoding:NSUTF8StringEncoding] attributes:nil];
    
    LXProjectFileReference *fileReference = [[LXProjectFileReference alloc] initWithParent:project.root file:file];
    [project.root.mutableChildren insertObject:fileReference atIndex:0];
    
    [project save];
    
    return project;
}

+ (LXProject *)loadProject:(NSString *)name path:(NSString *)path error:(NSError **)error {
    NSString *fileName = [NSString stringWithFormat:@"%@/%@", path, name];
    NSString *contents = [NSString stringWithContentsOfFile:fileName encoding:NSUTF8StringEncoding error:error];
    
    if(!contents) {
        return nil;
    }
    
    NSDictionary *dictionary = [contents JSONValue];
    
    if(!dictionary) {
        return nil;
    }
    
    LXProject *project = [[LXProject alloc] init];
    project.path = path;
    
    [project load:dictionary];
    
    return project;
}

@end
