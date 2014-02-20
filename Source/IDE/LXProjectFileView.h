#import <Cocoa/Cocoa.h>

#import "LXProject.h"
#import "LXTextView.h"

@class LXProjectFileView;
@protocol LXProjectFileViewDelegate<NSObject>
@optional
- (void)fileWasModified:(LXProjectFileView *)file modified:(BOOL)modifier;
@end

@interface LXProjectFileView : NSView<NSTextViewDelegate> {
}

@property (nonatomic, weak) id<LXProjectFileViewDelegate> delegate;
@property (nonatomic, readonly) LXProjectFile *file;
@property (nonatomic, readonly) LXTextView *textView;
@property (nonatomic, readonly) NSScrollView *textScrollView;
@property (nonatomic, readonly) BOOL modified;

- (id)initWithContentView:(NSView *)contentView file:(LXProjectFile *)file;

- (void)save;

- (NSUInteger)lineNumberForLocation:(NSPoint)point;

- (void)addBreakpoint:(NSUInteger)line;
- (void)removeBreakpoint:(NSUInteger)line;

@end
