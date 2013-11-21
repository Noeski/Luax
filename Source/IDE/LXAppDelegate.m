//
//  LXAppDelegate.m
//  Luax
//
//  Created by Noah Hilt on 11/25/12.
//  Copyright (c) 2012 Noah Hilt. All rights reserved.
//

#import "LXAppDelegate.h"
#import "LXDocument.h"

@implementation LXAppDelegate

__strong LXCompiler *compiler;
__strong LXDocument *document;

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    compiler = [[LXCompiler alloc] init];
    document = [[LXDocument alloc] initWithContentView:documentView name:@"Test" compiler:compiler];
    //document.delegate = self;

    NSString *path = [[NSBundle mainBundle] pathForResource:@"Main" ofType:@"lux"];    
    document.textView.string = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil];

    [self performInsertFirstDocument:document];

    [window makeKeyAndOrderFront:self];
}

- (void)performInsertFirstDocument:(LXDocument*)document {
	[documentView setSubviews:[NSArray array]];
	[documentView addSubview:document.textScrollView];
	[documentView addSubview:document.gutterScrollView];
	
	[document resizeViewsForSuperView:documentView];
	[document updateLineNumbers];
}

@end
