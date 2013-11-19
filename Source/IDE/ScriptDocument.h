#import <Cocoa/Cocoa.h>
//#import "ScriptTextView.h"
//#import "GutterTextView.h"
//#import "SyntaxColoring.h"

@protocol ScriptDocumentDelegate <NSObject>
@optional
- (void)documentWasModified:(ScriptDocument *)document modified:(BOOL)modifier;
- (void)documentDidAddBreakpoint:(ScriptDocument *)document line:(NSUInteger)line;
- (void)documentDidRemoveBreakpoint:(ScriptDocument *)document line:(NSUInteger)line;
@end

@interface ScriptDocument : NSObject {
	ScriptTextView *textView;
	NSScrollView *textScrollView;
	GutterTextView *gutterTextView;
	NSScrollView *gutterScrollView;
		
	NSPoint zeroPoint;
	
	NSLayoutManager *layoutManager;
	NSRect visibleRect;
	NSRange visibleRange;
	NSString *textString;
	NSString *searchString;
	
	NSInteger firstVisibleLineNumber;
	
	NSInteger index;
	NSInteger lineNumber;
	
	NSInteger indexNonWrap;
	NSInteger maxRangeVisibleRange;
	NSInteger numberOfGlyphsInTextString;
	BOOL oneMoreTime;
	unichar lastGlyph;
	
	NSRange range;
	
	NSInteger currentLineHeight;
		
	SyntaxColoring *syntaxColoring;	
}

@property (nonatomic, assign) id<ScriptDocumentDelegate> delegate;
@property (nonatomic, retain) NSString *scriptName;
@property (nonatomic, readonly) ScriptTextView *textView; 
@property (nonatomic, readonly) NSScrollView *textScrollView; 
@property (nonatomic, readonly) NSScrollView *gutterScrollView; 
@property (nonatomic, readonly) SyntaxColoring *syntaxColoring; 
@property (nonatomic) BOOL wasModified; 

- (id)initWithContentView:(NSView*)contentView;
- (void)resizeViewsForSuperView:(NSView*)view;

- (void)updateLineNumbers:(BOOL)recolour;
- (void)updateLineNumbersForClipView:(NSClipView *)clipView recolour:(BOOL)recolour;

- (NSUInteger)lineNumberForLocation:(NSPoint)point;

- (void)addBreakpoint:(NSUInteger)line;
- (void)removeBreakpoint:(NSUInteger)line;

@end
