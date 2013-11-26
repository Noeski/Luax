//
//  LXProject.m
//  Luax
//
//  Created by Noah Hilt on 11/24/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXProject.h"
#import "NSString+JSON.h"

@interface LXProjectFile()
@property (nonatomic, strong) NSString *mutableName;
@property (nonatomic, strong) NSString *mutablePath;
@end

@implementation LXProjectFile

- (id)initWithParent:(LXProjectGroup *)parent {
    if(self = [super init]) {
        _parent = parent;
        _mutableName = @"New File";
    }
    
    return self;
}

- (NSString *)name {
    return self.mutableName;
}

- (NSString *)path {
    return self.mutablePath;
}

- (NSDictionary *)save {
    return @{@"name" : self.name, @"path" : self.path};
}

- (void)load:(NSDictionary *)dictionary {
    self.mutableName = [dictionary[@"name"] copy];
    self.mutablePath = [dictionary[@"path"] copy];
}

@end

@interface LXProjectGroup()
@property (nonatomic, strong) NSMutableArray *mutableChildren;
@end

@implementation LXProjectGroup

- (id)initWithParent:(LXProjectGroup *)parent {
    if(self = [super initWithParent:parent]) {
        _mutableChildren = [[NSMutableArray alloc] init];

        self.mutableName = @"New Group";
    }
    
    return self;
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

- (void)load:(NSDictionary *)dictionary {
    [super load:dictionary];
    
    NSArray *children = dictionary[@"children"];
    
    for(NSDictionary *child in children) {
        if(child[@"children"]) {
            LXProjectGroup *group = [[LXProjectGroup alloc] initWithParent:self];
            [group load:child];
            
            [self.mutableChildren addObject:group];
        }
        else {
            LXProjectFile *file = [[LXProjectFile alloc] initWithParent:self];
            [file load:child];
            
            [self.mutableChildren addObject:file];
        }
    }
}

@end


@implementation LXProject

- (id)init {
    if(self = [super init]) {
        _root = [[LXProjectGroup alloc] initWithParent:nil];
    }
    
    return self;
}

- (void)save {
    NSMutableArray *children = [[NSMutableArray alloc] init];
    
    for(LXProjectFile *child in self.root.children) {
        [children addObject:[child save]];
    }

    NSDictionary *dictionary = @{@"name" : self.name, @"version" : @"1", @"root" : children};
    
    [[dictionary JSONRepresentation] writeToFile:[NSString stringWithFormat:@"%@/%@.luxproj", self.path, self.name] atomically:YES encoding:NSUTF8StringEncoding error:nil];
}

- (void)load:(NSDictionary *)dictionary {
    self.name = [dictionary[@"name"] copy];
    
    NSArray *children = dictionary[@"root"];
    
    for(NSDictionary *child in children) {
        if(child[@"children"]) {
            LXProjectGroup *group = [[LXProjectGroup alloc] initWithParent:self.root];
            [group load:child];
            
            [self.root.mutableChildren addObject:group];
        }
        else {
            LXProjectFile *file = [[LXProjectFile alloc] initWithParent:self.root];
            [file load:child];
            
            [self.root.mutableChildren addObject:file];
        }
    }
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
    
    LXProjectFile *file = [[LXProjectFile alloc] initWithParent:parent];
    [parent.mutableChildren insertObject:file atIndex:index];

    file.mutableName = [NSString stringWithFormat:@"Untitled%@.lux", highestIndex >= 0 ? @(highestIndex+1) : @""];
    file.mutablePath = [NSString stringWithFormat:@"%@/Source/%@", self.path, file.name];

    [[NSFileManager defaultManager] createFileAtPath:[NSString stringWithFormat:@"%@/Source/%@", self.path, file.name] contents:[NSData data] attributes:nil];
    
    [self save];
    
    return file;
}

- (void)removeFile:(LXProjectFile *)file {
    if([file class] == [LXProjectFile class]) {
        [[NSFileManager defaultManager] removeItemAtPath:[NSString stringWithFormat:@"%@/Source/%@", self.path, file.name] error:nil];
    }
    
    [file.parent.mutableChildren removeObject:file];
    
    [self save];
}

- (void)setFileName:(LXProjectFile *)file name:(NSString *)name {
    if([file class] == [LXProjectFile class]) {
        [[NSFileManager defaultManager] moveItemAtPath:[NSString stringWithFormat:@"%@/Source/%@", self.path, file.name] toPath:[NSString stringWithFormat:@"%@/Source/%@", self.path, name] error:nil];
        
        file.mutableName = name;
        file.mutablePath = [NSString stringWithFormat:@"%@/Source/%@", self.path, file.name];
    }
    else {
        file.mutableName = name;
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
    
    success = [[NSFileManager defaultManager] createDirectoryAtPath:[NSString stringWithFormat:@"%@/Output", path] withIntermediateDirectories:NO attributes:nil error:error];

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
