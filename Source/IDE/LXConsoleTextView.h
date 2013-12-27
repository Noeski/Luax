//
//  LXConsoleTextView.h
//  Luax
//
//  Created by Noah Hilt on 12/27/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class LXConsoleTextView;
@protocol LXConsoleTextViewDelegate<NSObject>
@optional
- (void)consoleView:(LXConsoleTextView *)consoleView didEnterString:(NSString *)string;
@end

@interface LXConsoleTextView : NSTextView
@property (nonatomic, weak) IBOutlet id<LXConsoleTextViewDelegate> consoleDelegate;

- (void)setEditable:(BOOL)editable clearText:(BOOL)clearText;
@end
