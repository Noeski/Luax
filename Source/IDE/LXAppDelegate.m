//
//  LXAppDelegate.m
//  Luax
//
//  Created by Noah Hilt on 11/25/12.
//  Copyright (c) 2012 Noah Hilt. All rights reserved.
//

#import "LXAppDelegate.h"
#import "LXProjectWindowController.h"
#import "LXProject.h"
#import "LXDocumentController.h"
#import "LXProjectFileView.h"

@interface LXAppDelegate()
@property (nonatomic, strong) NSMutableArray *windows;
@end

@implementation LXAppDelegate

static __weak LXAppDelegate *instance = nil;

- (id)init {
    if(self = [super init]) {
        instance = self;
    
        _windows = [[NSMutableArray alloc] init];
        
        LXDocumentController *dc = [[LXDocumentController alloc] init];
        if(dc) {};
    }
    
    return self;
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    NSArray *recentDocumentURLs = [[LXDocumentController sharedDocumentController] recentDocumentURLs];
    
    if([recentDocumentURLs count]) {
        [self openProjectWithURL:recentDocumentURLs.firstObject];
    }
}

- (BOOL)application:(NSApplication *)sender openFile:(NSString *)filename {
    [self openProjectWithURL:[NSURL URLWithString:filename]];
    
    return YES;
}

- (void)newProject {
    LXProjectWindowController *windowController = [[LXProjectWindowController alloc] initWithWindowNibName:@"LXProjectWindowController"];
    [windowController showWindow:self];
    
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    
    [panel setCanChooseFiles:NO];
    [panel setCanChooseDirectories:YES];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanCreateDirectories:YES];
    [panel setTitle:@"New Project"];
    [panel setPrompt:@"Create"];
    panel.delegate = self;
    
    [[NSBundle mainBundle] loadNibNamed:@"LXProjectAccessoryView" owner:self topLevelObjects:nil];
    
    [panel setAccessoryView:accessoryView];
    
    [panel beginSheetModalForWindow:windowController.window completionHandler:^(NSInteger result) {
        if(result == NSFileHandlingPanelOKButton) {
            NSString *projectName = nameField.stringValue;
            NSURL *fileURL = [panel URL];
            
            windowController.project = [LXProject createNewProject:projectName path:fileURL.path error:nil];
            [self.windows addObject:windowController];
        }
        else {
            //Kind of hacky here..
            double delayInSeconds = 0.2;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
                [windowController close];
            });
        }
    }];
}

- (void)openProject {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    
    [panel setCanChooseFiles:YES];
    [panel setCanChooseDirectories:NO];
    [panel setAllowsMultipleSelection:NO];
    [panel setAllowedFileTypes:@[@"luxproj"]];
    
    [panel beginSheetModalForWindow:nil completionHandler:^(NSInteger result){
        if(result == NSFileHandlingPanelOKButton) {
            [self openProjectWithURL:[panel URL]];
        }
    }];
}

- (void)openProjectWithURL:(NSURL *)fileURL {
    LXProject *project = [LXProject loadProject:fileURL.lastPathComponent path:[fileURL.path substringWithRange:NSMakeRange(0, [fileURL.path length] - ([fileURL.lastPathComponent length]+1))] error:nil];
    
    if(!project) {
        return;
    }
    
    LXProjectWindowController *windowController = [[LXProjectWindowController alloc] initWithWindowNibName:@"LXProjectWindowController"];
    [windowController showWindow:self];
    windowController.project = project;
    [self.windows addObject:windowController];
    
    [[NSDocumentController sharedDocumentController] noteNewRecentDocumentURL:fileURL];
}

+ (LXAppDelegate *)appDelegate {
    return instance;
}

#pragma mark - NSOpenSavePanelDelegate

- (BOOL)panel:(NSOpenPanel *)sender validateURL:(NSURL *)url error:(NSError **)outError {
    NSString *projectName = nameField.stringValue;
    
    if([projectName length] == 0) {
        [[NSAlert alertWithMessageText:@"Invalid Project Name" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Please enter a valid project name."] beginSheetModalForWindow:sender modalDelegate:self didEndSelector:nil contextInfo:NULL];
        return NO;
    }
    
    return YES;
}

@end
