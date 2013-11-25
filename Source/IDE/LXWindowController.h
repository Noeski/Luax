//
//  LXWindowController.h
//  Luax
//
//  Created by Noah Hilt on 11/24/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "LXServer.h"
#import "LXClient.h"

@interface LXWindowController : NSWindowController<LXServerDelegate, LXClientDelegate, NSComboBoxDataSource, NSComboBoxDelegate> {
    IBOutlet NSComboBox *hostTextField;
    IBOutlet NSTextField *portTextField;
    IBOutlet NSButton *connectButton;
    IBOutlet NSView *connectionContainer;
    IBOutlet NSProgressIndicator *connectionIndicator;
    IBOutlet NSTextField *connectionLabel;
}

- (IBAction)connect:(id)sender;
- (IBAction)disconnect:(id)sender;

@end
