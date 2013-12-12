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

LXProject *project = nil;

@interface LXProjectFile()
@property (nonatomic, weak) LXProject *project;
@property (nonatomic, strong) NSString *mutableName;
@property (nonatomic, strong) NSString *mutablePath;
@property (nonatomic, assign) BOOL isMain;
@property (nonatomic, strong) NSMutableDictionary *mutableBreakpoints;
@property (nonatomic, strong) NSString *cachedContents;
@property (nonatomic, strong) NSString *cachedCompiledContents;
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
}

- (void)removeBreakpoint:(NSInteger)line {
    [self.mutableBreakpoints removeObjectForKey:@(line)];
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
    
    [self.context compile:self.contents];
    
    if([self hasErrors]) {
        return;
    }
    
    LXLuaWriter *writer = [[LXLuaWriter alloc] init];
    writer.currentSource = self.name;
    [self.context.block compile:writer];
    
    NSString *path = [self.project.path stringByAppendingFormat:@"/.build/%@.lua", [self.name stringByDeletingPathExtension]];
    [writer.string writeToFile:path atomically:YES encoding:NSUTF8StringEncoding error:nil];
    
    NSString *mapPath = [self.project.path stringByAppendingFormat:@"/.build/%@.map", [self.name stringByDeletingPathExtension]];
    [[[writer generateSourceMap] JSONRepresentation] writeToFile:mapPath atomically:YES encoding:NSUTF8StringEncoding error:nil];
    self.lastCompileDate = [NSDate date];
}

- (void)clean {
    NSString *path = [self.project.path stringByAppendingFormat:@"/.build/%@.lua", [self.name stringByDeletingPathExtension]];
    [[NSFileManager defaultManager] removeItemAtPath:path error:nil];
    NSString *mapPath = [self.project.path stringByAppendingFormat:@"/.build/%@.map", [self.name stringByDeletingPathExtension]];
    [[NSFileManager defaultManager] removeItemAtPath:mapPath error:nil];
    self.lastCompileDate = [NSDate dateWithTimeIntervalSince1970:0];
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


@interface LXProject()
@property (nonatomic, readonly) NSMutableArray *mutableFiles;
@property (nonatomic, weak) LXProjectFile *mainFile;
@end

@implementation LXProject

- (id)init {
    if(self = [super init]) {
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

void breakpointHook(lua_State* L, lua_Debug* dbg) {
    [project checkBreakpoints:L debug:dbg];
}

lua_State *state;

- (void)run {
    project = self; //
    
    [self compile];
    
    state = luaL_newstate();
    
	luaL_openlibs(state);
    
    lua_getglobal(state, "package");
    lua_getfield(state, -1, "path");
    NSString *path = [NSString stringWithUTF8String:lua_tostring(state, -1)];
    path = [path stringByAppendingFormat:@";%@/?.lua", [NSString stringWithFormat:@"%@/.build", self.path]];
    lua_pop(state, 1);
    lua_pushstring(state, [path UTF8String]);
    lua_setfield(state, -2, "path" );
    lua_pop(state, 1 );
    
    NSString *source = self.mainFile.compiledContents;
    
    int status = luaL_loadbuffer(state, [source UTF8String], [source length], [self.mainFile.name UTF8String]);

    if(status != 0) {
        const char *error = lua_tostring(state, -1);
        lua_pop(state, 1);
        
        NSLog(@"%s", error);
    }
    
    lua_sethook(state, breakpointHook, LUA_MASKLINE, 0);

    int top = lua_gettop(state);
    
    for(int i = 0; i < top; ++i) {
        lua_call(state, 0, LUA_MULTRET);
    }
    
    lua_close(state);
}


- (BOOL)checkBreakpoints:(lua_State *)state debug:(lua_Debug *)debug {
    NSString *sourceName = nil;
    
    for(LXProjectFile *file in self.files) {
        BOOL breakpoint = file.breakpoints[@(debug->currentline)];
        
        if(breakpoint) {
            if(!sourceName) {
                lua_getinfo(state, "Sl", debug);
                
                sourceName = [[[NSString stringWithFormat:@"%s", debug->source] lastPathComponent] stringByDeletingPathExtension];
            }
            
            if([[file.name stringByDeletingPathExtension] isEqualToString:sourceName]) {
                [self breakLoop:file line:debug->currentline error:NO];
                return YES;
            }
        }
    }
    
    return NO;
}

- (void)breakLoop:(LXProjectFile *)file line:(NSInteger)line error:(BOOL)error {
	//if(mDebugState == ScriptDebugger::DEBUG_BREAK || mDebugState == ScriptDebugger::DEBUG_ERROR)
	//	return;
    
	//Application::Instance()->pause();
    
    LXLuaWriter *writer = [[LXLuaWriter alloc] init];
    writer.currentSource = file.name;
    [file.context.block compile:writer];
    
    NSDictionary *mapping = [writer originalPosition:line column:0];
    
    NSLog(@"Mapping: %@", mapping);
    
    if([self.delegate respondsToSelector:@selector(project:file:didBreakAtLine:)]) {
        [self.delegate project:self file:file didBreakAtLine:line];
    }
    
    [self updateStack];
    
    do {
        @autoreleasepool {
            NSEvent *event = [NSApp nextEventMatchingMask:NSAnyEventMask
                                                untilDate:[NSDate distantFuture]
                                                   inMode:NSDefaultRunLoopMode
                                                  dequeue:YES];
            if(event) {
                [NSApp sendEvent:event];
            }
        }
    } while(YES);
        
    //Application::Instance()->resume();
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
    //if(mDebugState == DEBUG_ERROR)
    //    stackDepth++;
    
    for(; true; ++stackDepth) {
        lua_Debug ar;
        
        bool ok = lua_getstack(state, stackDepth, &ar);
        
        if(!ok)
            break;
        
        lua_getinfo(state, "funSl", &ar);
        int funcidx = lua_gettop(state);
        
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
            const char *key = lua_getlocal(state, &ar, i);
            if(key == NULL)
                break;
            
            NSMutableDictionary *value = [NSMutableDictionary dictionary];
            value[@"name"] = [NSString stringWithFormat:@"%s", key];
            value[@"where"] = @(stackDepth);
            value[@"index"] = @(i);
            
            lua_toValue(value, state, lua_gettop(state), tables, tablesVisited);
            
            [locals addObject:value];
            lua_pop(state, 1);
        }
        
        callValue[@"locals"] = locals;
        
        NSMutableArray *upvalues = [NSMutableArray array];
        
        for(int i = 1; true; ++i) {
            const char *key = lua_getupvalue(state, funcidx, i);
            if(key == NULL)
                break;
            
            NSMutableDictionary *value = [NSMutableDictionary dictionary];
            value[@"name"] = [NSString stringWithFormat:@"%s", key];
            value[@"where"] = @(stackDepth);
            value[@"index"] = @(i);
            
            lua_toValue(value, state, -1, tables, tablesVisited);
            
            [upvalues addObject:value];
            lua_pop(state, 1);
        }
        
        callValue[@"upvalues"] = upvalues;
        
        lua_pop(state, 1);
        
        [stack addObject:callValue];
        
        callStackSize++;
    }
    
    root[@"stack"] = stack;
    
    NSMutableDictionary *globals = [NSMutableDictionary dictionary];
    globals[@"name"] = @"_G";
    
    lua_getglobal(state, "_G");
    lua_toValue(globals, state, -1, tables, tablesVisited);
    
    lua_pop(state, 1);
    
    root[@"globals"] = globals;
    root[@"tables"] = tables;
    
    NSLog(@"root: %@", root);
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
