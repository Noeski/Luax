//
//  LXDocumentController.m
//  Luax
//
//  Created by Noah Hilt on 11/24/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXDocumentController.h"
#import "LXProject.h"

@implementation LXDocumentController
- (IBAction)newProject:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    
    // Configure your panel the way you want it
    [panel setCanChooseFiles:NO];
    [panel setCanChooseDirectories:YES];
    [panel setAllowsMultipleSelection:NO];
    [panel setCanCreateDirectories:YES];
    [panel setTitle:@"New Project"];
    [panel setPrompt:@"Create"];
    panel.delegate = self;
    
    [[NSBundle mainBundle] loadNibNamed:@"LXProjectAccessoryView" owner:self topLevelObjects:nil];
        
    [panel setAccessoryView:accessoryView];
    
    //[panel beginWithCompletionHandler:^(NSInteger result) {
    [panel beginSheetModalForWindow:nil completionHandler:^(NSInteger result) {
        if(result == NSFileHandlingPanelOKButton) {
            NSString *projectName = nameField.stringValue;
            NSURL *fileURL = [panel URL];
                
            [LXProject createNewProject:projectName path:fileURL.path error:nil];
        }
    }];
}

/*- (BOOL)panel:(id)sender shouldEnableURL:(NSURL *)url {
    NSLog(@"shouldEnableURL");
    return NO;
}*/

- (BOOL)panel:(NSOpenPanel *)sender validateURL:(NSURL *)url error:(NSError **)outError {
    NSString *projectName = nameField.stringValue;
    
    if([projectName length] == 0) {
        [[NSAlert alertWithMessageText:@"COCK" defaultButton:@"OK" alternateButton:@"CANCEL" otherButton:nil informativeTextWithFormat:@""] beginSheetModalForWindow:sender completionHandler:^(NSModalResponse response) {
            [sender close];
        }];
        
        return NO;
    }
    
    NSLog(@"validateURL");
    return YES;
}

- (IBAction)openProject:(id)sender {
    NSOpenPanel *panel = [NSOpenPanel openPanel];
    
    // Configure your panel the way you want it
    [panel setCanChooseFiles:YES];
    [panel setCanChooseDirectories:NO];
    [panel setAllowsMultipleSelection:NO];
    [panel setAllowedFileTypes:@[@"luxproj"]];
    
    [panel beginWithCompletionHandler:^(NSInteger result){
        if(result == NSFileHandlingPanelOKButton) {
            NSURL *fileURL = [panel URL];
            
            [LXProject loadProject:fileURL.lastPathComponent path:[fileURL.path substringWithRange:NSMakeRange(0, [fileURL.path length] - ([fileURL.lastPathComponent length]+1))] error:nil];
        }
    }];
}
@end
