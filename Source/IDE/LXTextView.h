#import <Cocoa/Cocoa.h>

@class LXProjectFile;

@interface LXAutoCompleteWindow : NSWindow {
    
}
@end

@interface LXAutoCompleteDefinition : NSObject {
    
}

@property (nonatomic, retain) NSString *key;
@property (nonatomic, retain) NSString *type;
@property (nonatomic, retain) NSString *string;
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *summary;
@property (nonatomic, retain) NSArray *markers;

@end

@interface LXTextViewUndoManager : NSUndoManager {
    NSInteger numberOfOpenGroups;
}

@end

@interface LXTextView : NSTextView<NSWindowDelegate, NSTableViewDataSource, NSTableViewDelegate> {
	NSInteger lineHeight;

    NSUndoManager *undoManager;
    NSFont *font;
    BOOL insideUndoGroup;
    
    NSColor *textColor, *commentsColor, *keywordsColor, *numbersColor, *stringsColor, *functionsColor, *typesColor;
    NSCharacterSet *identifierCharacterSet;
    BOOL insertAutoComplete;
    BOOL settingAutoComplete;
    BOOL settingAutoCompleteRange;
    NSRange autoCompleteRange;
    NSRange autoCompleteWordRange;
    NSString *autoCompleteString;
    
    NSMutableArray *autoCompleteDefinitions;
    NSMutableArray *currentAutoCompleteDefinitions;
    NSMutableArray *autoCompleteMarkers;
    
	NSColor *highlightedLineBackgroundColor;
	NSColor *highlightedLineColor;
	NSInteger highlightedLine;
    
    BOOL showingAutoCompleteWindow;
    NSWindow *autoCompleteWindow;
    NSScrollView *autoCompleteScrollView;
    NSTableView *autoCompleteTableView;
    NSTextField *autoCompleteDescriptionView;
    id eventMonitor;
    
    BOOL showingErrorWindow;
    NSWindow *errorWindow;
    NSTextField *errorLabel;
}

@property (nonatomic, weak) LXProjectFile *file;

- (id)initWithFrame:(NSRect)frame file:(LXProjectFile *)file;

- (void)setDefaults;

- (NSInteger)lineHeight;

- (void)setTabWidth;
- (NSString *)stringForLine:(NSInteger)line;
- (void)scrollToLine:(NSInteger)line;
- (void)setHighlightedLine:(NSInteger)line;
- (void)setHighlightedLineColor:(NSColor *)color background:(NSColor *)background;

@end
