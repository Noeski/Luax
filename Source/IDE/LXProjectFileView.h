#import <Cocoa/Cocoa.h>

#import "LXProject.h"
#import "LXTextView.h"
#import "LXGutterView.h"

@class LXProjectFileView;
@protocol LXProjectFileViewDelegate<NSObject>
@optional
- (void)fileWasModified:(LXProjectFileView *)file modified:(BOOL)modifier;
- (void)fileDidAddBreakpoint:(LXProjectFileView *)file line:(NSUInteger)line;
- (void)fileDidRemoveBreakpoint:(LXProjectFileView *)file line:(NSUInteger)line;
@end

@interface LXProjectFileView : NSView<NSTextViewDelegate> {
	LXGutterView *_gutterTextView;
}

@property (nonatomic, weak) id<LXProjectFileViewDelegate> delegate;
@property (nonatomic, readonly) LXProjectFileReference *file;
@property (nonatomic, readonly) LXTextView *textView;
@property (nonatomic, readonly) NSScrollView *textScrollView;
@property (nonatomic, readonly) NSScrollView *gutterScrollView;
@property (nonatomic, readonly) BOOL modified;

- (id)initWithContentView:(NSView *)contentView file:(LXProjectFileReference *)file;

- (void)save;
- (void)resizeViews;
- (void)updateLineNumbers;
- (void)updateLineNumbersForClipView:(NSClipView *)clipView;

- (NSUInteger)lineNumberForLocation:(NSPoint)point;

- (void)addBreakpoint:(NSUInteger)line;
- (void)removeBreakpoint:(NSUInteger)line;

@end
