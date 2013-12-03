//
//  LXAppDelegate.h
//  Luax
//
//  Created by Noah Hilt on 11/25/12.
//  Copyright (c) 2012 Noah Hilt. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface LXAppDelegate : NSResponder <NSApplicationDelegate, NSOpenSavePanelDelegate> {
    IBOutlet NSView *accessoryView;
    IBOutlet NSTextField *nameField;
}

- (void)newProject;
- (void)openProject;
- (void)openProjectWithURL:(NSURL *)fileURL;

+ (LXAppDelegate *)appDelegate;
@end
