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
#import "LXServer.h"
#import "LXClient.h"

@interface LXProjectWindowController : NSWindowController<LXServerDelegate, LXClientDelegate, NSComboBoxDataSource, NSComboBoxDelegate, NSOutlineViewDataSource, NSOutlineViewDelegate, NSSplitViewDelegate, LXProjectDelegate, LXProjectFileViewDelegate> {
    IBOutlet NSComboBox *hostTextField;
    IBOutlet NSTextField *portTextField;
    IBOutlet NSButton *connectButton;
    IBOutlet NSView *connectionContainer;
    IBOutlet NSProgressIndicator *connectionIndicator;
    IBOutlet NSTextField *connectionLabel;
    
    IBOutlet NSOutlineView *projectOutlineView;
    IBOutlet NSView *contentView;
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
@end
