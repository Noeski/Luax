//
//  main.m
//  LuaX
//
//  Created by Noah Hilt on 11/25/12.
//  Copyright (c) 2012 Noah Hilt. All rights reserved.
//

#import "LXCompiler.h"

int main(int argc, char *argv[]) {
    NSString *fileName = @"/Users/nhilt/Luax/bin/Main.lux";// [[NSBundle mainBundle] pathForResource:@"Main" ofType:@"lux"];
    NSString *source = [NSString stringWithContentsOfFile:fileName encoding:NSUTF8StringEncoding error:nil];
    LXCompiler *compiler = [[LXCompiler alloc] init];
    [compiler compile:fileName string:source];
    [compiler save];
    
    return 0;
}
