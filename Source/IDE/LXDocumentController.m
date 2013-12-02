//
//  LXDocumentController.m
//  Luax
//
//  Created by Noah Hilt on 11/24/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXDocumentController.h"
#import "LXAppDelegate.h"

@implementation LXDocumentController

- (IBAction)newProject:(id)sender {
    [[LXAppDelegate appDelegate] newProject];
}

- (IBAction)openProject:(id)sender {
    [[LXAppDelegate appDelegate] openProject];
}

@end
