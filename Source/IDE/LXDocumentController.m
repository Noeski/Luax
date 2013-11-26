//
//  LXDocumentController.m
//  Luax
//
//  Created by Noah Hilt on 11/24/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXDocumentController.h"
#import "LXProject.h"

#import "LXProjectWindowController.h"

__strong LXProjectWindowController *windowController;

@implementation LXDocumentController
- (IBAction)newProject:(id)sender {
    windowController = [[LXProjectWindowController alloc] initWithWindowNibName:@"LXProjectWindowController"];
    
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
        }
        else {
            //Kind of hacky here..
            double delayInSeconds = 0.2;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delayInSeconds * NSEC_PER_SEC));
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void) {
                [windowController close];
                windowController = nil;
            });
        }
    }];
}

- (BOOL)panel:(NSOpenPanel *)sender validateURL:(NSURL *)url error:(NSError **)outError {
    NSString *projectName = nameField.stringValue;
    
    if([projectName length] == 0) {
        [[NSAlert alertWithMessageText:@"Invalid Project Name" defaultButton:@"OK" alternateButton:nil otherButton:nil informativeTextWithFormat:@"Please enter a valid project name."] beginSheetModalForWindow:sender modalDelegate:self didEndSelector:nil contextInfo:NULL];
        return NO;
    }
    
    return YES;
}

- (void)alertDidEnd:(NSAlert *)alert returnCode:(NSInteger)returnCode contextInfo:(void *)contextInfo {
}

- (IBAction)openProject:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    
    [panel setCanChooseFiles:YES];
    [panel setCanChooseDirectories:NO];
    [panel setAllowsMultipleSelection:NO];
    [panel setAllowedFileTypes:@[@"luxproj"]];
    
    [panel beginSheetModalForWindow:nil completionHandler:^(NSInteger result){
        if(result == NSFileHandlingPanelOKButton) {
            windowController = [[LXProjectWindowController alloc] initWithWindowNibName:@"LXProjectWindowController"];

            NSURL *fileURL = [panel URL];
            
            windowController.project = [LXProject loadProject:fileURL.lastPathComponent path:[fileURL.path substringWithRange:NSMakeRange(0, [fileURL.path length] - ([fileURL.lastPathComponent length]+1))] error:nil];
            [self noteNewRecentDocumentURL:fileURL];
        }
    }];
}
@end
