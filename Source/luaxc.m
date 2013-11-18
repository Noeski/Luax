//
//  luaxc.m
//  Luax
//
//  Created by Noah Hilt on 11/16/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXCompiler.h"

int main(int argc, char *argv[]) {
    if(argc < 2)
        return 1;
    
    LXCompiler *compiler = [[LXCompiler alloc] init];
    
    for(int i = 1; i < argc; ++i) {
        NSString *fileName = [NSString stringWithCString:argv[i] encoding:NSUTF8StringEncoding];
        NSString *source = [NSString stringWithContentsOfFile:fileName encoding:NSUTF8StringEncoding error:nil];
        
        [compiler compile:fileName string:source];
    }

    [compiler save];
    
    return 0;
}