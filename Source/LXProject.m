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

@interface LXProjectFile()
@property (nonatomic, weak) LXProject *project;
@property (nonatomic, strong) NSString *mutableName;
@property (nonatomic, strong) NSString *mutablePath;
@property (nonatomic, strong) NSString *cachedContents;
@property (nonatomic, strong) NSDate *lastModifiedDate;
@property (nonatomic, strong) NSDate *lastCompileDate;

+ (NSDateFormatter *)dateFormatter;
@end

@implementation LXProjectFile

- (id)initWithProject:(LXProject *)project {
    if(self = [super init]) {
        _project = project;
        _context = [[LXContext alloc] initWithName:nil compiler:project.compiler];
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

- (NSString *)contents {
    if(!_cachedContents) {
        _cachedContents = [NSString stringWithContentsOfFile:self.path encoding:NSUTF8StringEncoding error:nil];
    }

    return _cachedContents;
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

- (NSDictionary *)save {
    return @{@"uid" : self.uid, @"name" : self.name, @"path" : self.mutablePath, @"modified" : [[LXProjectFile dateFormatter] stringFromDate:self.lastModifiedDate], @"build" : [[LXProjectFile dateFormatter] stringFromDate:self.lastCompileDate]};
}

- (void)load:(NSDictionary *)dictionary {
    self.lastModifiedDate = [[LXProjectFile dateFormatter] dateFromString:dictionary[@"modified"]];
    self.lastCompileDate = [[LXProjectFile dateFormatter] dateFromString:dictionary[@"build"]];

    self.mutableName = [dictionary[@"name"] copy];
    self.mutablePath = [dictionary[@"path"] copy];
}

- (void)compile {
    if([self isCompiled]) {
        return;
    }
    
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
