#import <Cocoa/Cocoa.h>

@class LXDocument;

@interface LXAutoCompleteWindow : NSWindow {
    
}
@end

@interface LXAutoCompleteDefinition : NSObject {
    
}

@property (nonatomic, retain) NSString *key;
@property (nonatomic, retain) NSString *type;
@property (nonatomic, retain) NSString *string;
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *description;
@property (nonatomic, retain) NSArray *markers;

@end

@interface LXTextViewUndoManager : NSUndoManager {
    NSInteger numberOfOpenGroups;
}

@end

@interface LXTextView : NSTextView<NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate> {
	NSInteger lineHeight;
	NSPoint startPoint;
	NSPoint startOrigin;
	CGFloat pageGuideX;
	NSColor *pageGuideColour;
		
    NSUndoManager *undoManager;
    BOOL insideUndoGroup;
    
    NSMutableArray *errors;
    NSColor *commentsColor, *keywordsColor, *numbersColor, *stringsColor, *functionsColor, *typesColor;
    NSCharacterSet *identifierCharacterSet;
    BOOL insertAutoComplete;
    BOOL settingAutoComplete;
    BOOL settingAutoCompleteRange;
    NSRange autoCompleteRange;
    NSRange autoCompleteWordRange;
    NSString *autoCompleteString;
    
    NSMutableArray *baseAutoCompleteDefinitions;
    NSMutableArray *autoCompleteDefinitions;
    NSMutableArray *currentAutoCompleteDefinitions;
    NSMutableArray *autoCompleteMarkers;
    
	NSColor *highlightedLineBackgroundColor;
	NSColor *highlightedLineColor;
	NSInteger highlightedLine;
    
    BOOL showingAutoCompleteWindow;
    NSWindow *window;
    NSScrollView *autoCompleteScrollView;
    NSTableView *autoCompleteTableView;
    NSTextField *autoCompleteDescriptionView;
    id eventMonitor;
}

@property (nonatomic, weak) LXDocument *document;

- (id)initWithFrame:(NSRect)frame document:(LXDocument *)document;

- (void)setDefaults;

- (NSInteger)lineHeight;

- (void)setTabWidth;
- (NSString *)stringForLine:(int)line;
- (void)scrollToLine:(int)line;
- (void)setHighlightedLine:(int)line;
- (void)setHighlightedLineColor:(NSColor *)color background:(NSColor *)background;

@end
