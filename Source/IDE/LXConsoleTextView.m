//
//  LXConsoleTextView.m
//  Luax
//
//  Created by Noah Hilt on 12/27/13.
//  Copyright (c) 2013 Noah Hilt. All rights reserved.
//

#import "LXConsoleTextView.h"

@interface LXConsoleTextView() {
    NSInteger editLocation;
}
@end

@implementation LXConsoleTextView

- (void)setEditable:(BOOL)editable {
    [self setEditable:editable clearText:YES];
}

- (void)setEditable:(BOOL)editable clearText:(BOOL)clearText {
    if(editable != [self isEditable]) {
        if(editable) {
            [self replaceCharactersInRange:NSMakeRange([self.string length], 0) withString:@": "];
            [self.layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:[NSColor colorWithCalibratedRed:0.38 green:0.549 blue:0.969 alpha:1] forCharacterRange:NSMakeRange([self.string length]-2, 2)];

            editLocation = [self.string length];
        }
        else {
            if(clearText) {
                NSInteger location = MAX(0, editLocation-2);
                
                [self replaceCharactersInRange:NSMakeRange(location, [self.string length] - location) withString:@""];
            }
        }
    }
    
    [super setEditable:editable];
}

- (NSRange)selectionRangeForProposedRange:(NSRange)proposedSelRange granularity:(NSSelectionGranularity)granularity {
    if([self isEditable]) {
        if(proposedSelRange.length == 0) {
            if(proposedSelRange.location < editLocation)
                return NSMakeRange([self.string length], 0);
        }
    }
    
    return [super selectionRangeForProposedRange:proposedSelRange granularity:granularity];
}

- (BOOL)shouldChangeTextInRange:(NSRange)affectedCharRange replacementString:(NSString *)replacementString {
    if([self isEditable]) {
        if(affectedCharRange.location >= editLocation) {
            [self replaceCharactersInRange:affectedCharRange withString:replacementString];
            [self.layoutManager addTemporaryAttribute:NSForegroundColorAttributeName value:[NSColor colorWithCalibratedRed:0.95 green:0.9 blue:0.7 alpha:1] forCharacterRange:NSMakeRange(affectedCharRange.location, replacementString.length)];
        }
        
        return NO;
    }
    else {
        return [super shouldChangeTextInRange:affectedCharRange replacementString:replacementString];
    }
}

- (void)keyDown:(NSEvent *)theEvent {
    if([self isEditable] && [theEvent keyCode] == 36) {
        if([self.consoleDelegate respondsToSelector:@selector(consoleView:didEnterString:)]) {
            [self.consoleDelegate consoleView:self didEnterString:[self.string substringFromIndex:editLocation]];
        }
        
        [self replaceCharactersInRange:NSMakeRange([self.string length], 0) withString:@"\n"];
    }
    else {
        [super keyDown:theEvent];
    }
}

@end
