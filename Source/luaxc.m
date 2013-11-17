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
    
    NSString *fileName = [NSString stringWithCString:argv[1] encoding:NSUTF8StringEncoding];
    //NSString *fileName = [[NSBundle mainBundle] pathForResource:@"Main" ofType:@"lux"];
    NSString *source = [NSString stringWithContentsOfFile:fileName encoding:NSUTF8StringEncoding error:nil];
    LXCompiler *compiler = [[LXCompiler alloc] init];
    [compiler compile:fileName string:source];
    
    return 0;
}