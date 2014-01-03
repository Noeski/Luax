//
//  LXWindowController.h
//  Luax
//
//  Created by Noah Hilt on 11/24/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LXProject.h"
#import "LXProjectFileView.h"
#import "LXConsoleTextView.h"
#import "LXServer.h"
#import "LXClient.h"

@interface LXTableView : NSTableView
@end

@interface LXOutlineView : NSOutlineView
@end

@interface LXSplitView : NSSplitView
@end

@interface LXProjectWindowController : NSWindowController<LXServerDelegate, LXClientDelegate, NSComboBoxDataSource, NSComboBoxDelegate, NSOutlineViewDataSource, NSOutlineViewDelegate, NSSplitViewDelegate, LXProjectDelegate, LXProjectFileViewDelegate, LXConsoleTextViewDelegate> {
    IBOutlet NSComboBox *hostTextField;
    IBOutlet NSTextField *portTextField;
    IBOutlet NSButton *connectButton;
    IBOutlet NSView *connectionContainer;
    IBOutlet NSProgressIndicator *connectionIndicator;
    IBOutlet NSTextField *connectionLabel;
    
    IBOutlet NSOutlineView *projectOutlineView;
    IBOutlet NSView *contentView;
    IBOutlet NSButton *showDebugContainerButton;
    IBOutlet NSButton *continueButton;
    IBOutlet NSButton *stepOverButton;
    IBOutlet NSButton *stepIntoButton;
    IBOutlet NSButton *stepOutButton;
    IBOutlet LXConsoleTextView *consoleView;
    IBOutlet NSTableView *callStackView;
    IBOutlet NSOutlineView *localVariablesView;
    IBOutlet NSView *debugContainerView;
    IBOutlet NSSplitView *horizontalSplitView;
    IBOutlet NSSplitView *contentSplitView;
    IBOutlet NSSplitView *verticalSplitView;
    IBOutlet NSButton *showLocalsButton;
    IBOutlet NSButton *showTemporariesButton;

    BOOL showLocals;
}

@property (nonatomic, strong) LXProject *project;

- (IBAction)connect:(id)sender;
- (IBAction)disconnect:(id)sender;

- (IBAction)newScript:(id)sender;
- (IBAction)newGroup:(id)sender;
- (IBAction)save:(id)sender;
- (IBAction)compile:(id)sender;
- (IBAction)clean:(id)sender;
- (IBAction)run:(id)sender;
- (IBAction)stopExecution:(id)sender;
- (IBAction)continueExecution:(id)sender;
- (IBAction)pauseExecution:(id)sender;
- (IBAction)stepInto:(id)sender;
- (IBAction)stepOver:(id)sender;
- (IBAction)stepOut:(id)sender;
- (IBAction)showLocalsMenu:(id)sender;
- (IBAction)showLocals:(id)sender;
- (IBAction)showGlobals:(id)sender;
- (IBAction)showTemporaries:(id)sender;
- (IBAction)showHideDebugContainer:(id)sender;

@end
