#import <Cocoa/Cocoa.h>

#import "LXCompiler.h"
#import "LXTextView.h"
#import "LXGutterView.h"

@class LXDocument;
@protocol LXDocumentDelegate<NSObject>
@optional
- (void)documentWasModified:(LXDocument *)document modified:(BOOL)modifier;
- (void)documentDidAddBreakpoint:(LXDocument *)document line:(NSUInteger)line;
- (void)documentDidRemoveBreakpoint:(LXDocument *)document line:(NSUInteger)line;
@end

@interface LXDocument : NSObject<NSTextViewDelegate> {
	LXGutterView *_gutterTextView;
}

@property (nonatomic, weak) id<LXDocumentDelegate> delegate;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) LXContext *context;
@property (nonatomic, readonly) LXTextView *textView;
@property (nonatomic, readonly) NSScrollView *textScrollView; 
@property (nonatomic, readonly) NSScrollView *gutterScrollView; 
@property (nonatomic) BOOL wasModified;

- (id)initWithContentView:(NSView *)contentView name:(NSString *)name compiler:(LXCompiler *)compiler;

- (void)setString:(NSString *)string;
- (void)resizeViewsForSuperView:(NSView*)view;

- (void)updateLineNumbers;
- (void)updateLineNumbersForClipView:(NSClipView *)clipView;

- (NSUInteger)lineNumberForLocation:(NSPoint)point;

- (void)addBreakpoint:(NSUInteger)line;
- (void)removeBreakpoint:(NSUInteger)line;

@end
