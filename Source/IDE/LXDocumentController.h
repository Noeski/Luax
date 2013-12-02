//
//  LXDocumentController.h
//  Luax
//
//  Created by Noah Hilt on 11/24/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface LXDocumentController : NSDocumentController<NSOpenSavePanelDelegate>
- (IBAction)newProject:(id)sender;
- (IBAction)openProject:(id)sender;
@end
