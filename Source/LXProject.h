//
//  LXProject.h
//  Luax
//
//  Created by Noah Hilt on 11/24/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface LXProject : NSObject
@property (nonatomic, strong) NSString *name;
@property (nonatomic, strong) NSString *path;

- (void)save;
- (void)load:(NSDictionary *)dictionary;

+ (LXProject *)createNewProject:(NSString *)name path:(NSString *)path error:(NSError **)error;
+ (LXProject *)loadProject:(NSString *)name path:(NSString *)path error:(NSError **)error;

@end
