//
//  ConsoleWindowController.h
//  NewGame
//
//  Created by Noah Hilt on 3/12/12.
//  Copyright 2012 __MyCompanyName__. All rights reserved.
//

#import <Cocoa/Cocoa.h>

#import "ClientSocket.h"
#import "ServerSocket.h"
#import "ScriptDocument.h"

@interface BlockingView : NSView {
    
}
@end

@interface GradientView : NSView {
    
}

@property (nonatomic, retain) NSGradient *gradient;
@property (nonatomic, retain) NSColor *topBorderColor;
@property (nonatomic, retain) NSColor *bottomBorderColor;

@end

typedef enum {
    LuaVariableScopeNone,
    LuaVariableScopeLocal,
    LuaVariableScopeUpvalue,
    LuaVariableScopeGlobal
} LuaVariableScope;

typedef enum {
    LuaVariableTypeNil,
    LuaVariableTypeBoolean,
    LuaVariableTypeNumber,
    LuaVariableTypeVector2,
    LuaVariableTypeVector3,
    LuaVariableTypeString,
    LuaVariableTypeTable,
    LuaVariableTypeFunction,
    LuaVariableTypeUserdata,
    LuaVariableTypeThread,
    LuaVariableTypeLightuserdata
} LuaVariableType;

@interface LuaVariable : NSObject<NSCopying> {
}

@property (nonatomic) LuaVariableType type;
@property (nonatomic) LuaVariableScope scope;
@property (nonatomic) NSInteger where;
@property (nonatomic) NSInteger index;
@property (nonatomic, retain) NSString *key;
@property (nonatomic, retain) id value;
@property (nonatomic, assign) LuaVariable *parent;
@property (nonatomic, retain) NSArray *children;
@property (nonatomic) BOOL expanded;

- (BOOL)isTemporary;

@end

@interface LuaCallStackIndex : NSObject {
}

@property (nonatomic, retain) NSString *source;
@property (nonatomic, retain) NSString *function;
@property (nonatomic) BOOL error;
@property (nonatomic) int line;
@property (nonatomic) int firstLine;
@property (nonatomic) int lastLine;
@property (nonatomic, retain) NSArray *localVariables;
@property (nonatomic, retain) NSArray *upVariables;

@end

@interface ImageAndTextCell : NSTextFieldCell {
@private
	BOOL isModified;
	NSImage *image;
	NSImage *highlightImage;
}

- (void)setModified:(BOOL)modified;
- (BOOL)isModified;

- (void)setImage:(NSImage *)anImage;
- (NSImage *)image;

- (void)drawWithFrame:(NSRect)cellFrame inView:(NSView *)controlView;
- (NSSize)cellSize;

@end

@interface VariableCell : NSTextFieldCell {
@private    
    NSString *name;
    NSString *type;
    NSString *value;
    
    LuaVariable *variable;
    
    CGFloat nameWidth;
    
    NSProgressIndicator *progressView;
}

@end

@interface BreakpointCellValue : NSObject<NSCopying> {
}

@property (nonatomic, retain) NSString *scriptName;
@property (nonatomic, retain) NSString *previewString;
@property (nonatomic, retain) NSString *lineString;

@end

@interface BreakpointCell : NSTextFieldCell {
}

@property (nonatomic, retain) BreakpointCellValue *value;

@end

@interface ConsoleWindowController : NSWindowController <
ClientSocketDelegate,
ServerSocketDelegate,
ScriptDocumentDelegate,
NSWindowDelegate,
NSTableViewDataSource,
NSTableViewDelegate,
NSOutlineViewDataSource,
NSComboBoxDataSource,
NSComboBoxDelegate,
NSSplitViewDelegate> {
    ClientSocket *socket;
    ServerSocket *serverSocket;

    BOOL connecting;
	BOOL reloadingScript;
	NSInteger currentScriptIndex;
	NSMutableArray *scriptEditObjects;
	
    NSMutableDictionary *breakpointsDictionary;
    
	id eventMonitor;
    NSTableView *scriptsTableView;
	
    NSScrollView *currentScrollView;
    
    IBOutlet NSButton *showScriptsButton;
	IBOutlet NSButton *showStackButton;
	IBOutlet NSButton *showBreakpointsButton;

	IBOutlet NSView *documentView;
	IBOutlet NSOutlineView *localVariablesView;
    
    IBOutlet NSOutlineView *breakpointsView;

    IBOutlet GradientView *scriptButtonsContainer;
    IBOutlet NSImageView *buttonBackground;
    
    IBOutlet GradientView *topBarContainer;
    IBOutlet NSComboBox *hostTextField;
    IBOutlet NSTextField *portTextField;
    IBOutlet NSButton *connectButton;
    IBOutlet NSView *connectionContainer;
    IBOutlet NSProgressIndicator *connectionIndicator;
    IBOutlet NSTextField *connectionLabel;

    IBOutlet GradientView *stackContainer;
    IBOutlet GradientView *consoleContainer;
    IBOutlet NSTextView *consoleTextView;
	IBOutlet NSTextField *consoleInputField;
	IBOutlet NSTableView *callStackView;
    
    IBOutlet NSButton *showTemporariesButton;

    NSMutableAttributedString *consoleString;
    
    NSMenuItem *saveItem;
    NSMenuItem *startItem;
    NSMenuItem *reloadItem;
    NSMenuItem *unloadItem;
    
    BOOL showLocals;
    IBOutlet NSPopUpButton *switchVariablesButton;
    IBOutlet NSPopUpButton *switchStackButton;
    
    IBOutlet GradientView *stackButtonsContainer;

	IBOutlet NSButton *playButton;
	IBOutlet NSButton *stepIntoButton;
	IBOutlet NSButton *stepOutButton;
	IBOutlet NSButton *stepOverButton;
    
    IBOutlet NSSplitView *stackSplitView;
    IBOutlet NSView *stackSplitViewLeftView;
    IBOutlet NSView *stackSplitViewRightView;

    IBOutlet NSSplitView *documentSplitView;
    IBOutlet NSView *documentSplitViewTopView;
    IBOutlet NSView *documentSplitViewBottomView;
    
    IBOutlet NSSplitView *consoleSplitView;
    
    IBOutlet NSView *scriptsProgressContainer;
    IBOutlet NSProgressIndicator *scriptsProgressIndicator;
    
    IBOutlet NSView *stackProgressContainer;
    IBOutlet NSProgressIndicator *stackProgressIndicator;
}

@property (nonatomic, retain) IBOutlet NSScrollView *scriptsScrollView;
@property (nonatomic, retain) IBOutlet NSScrollView *callStackScrollView;
@property (nonatomic, retain) IBOutlet NSScrollView *breakpointScrollView;

- (IBAction)connect:(id)sender;
- (IBAction)disconnect:(id)sender;
- (IBAction)processText:(NSTextField*)sender;

- (void)saveSelectedScript;
- (void)reloadSelectedScript;
- (void)unloadSelectedScript;

- (IBAction)play:(id)sender;
- (IBAction)pause:(id)sender;
- (IBAction)stepInto:(id)sender;
- (IBAction)stepOut:(id)sender;
- (IBAction)stepOver:(id)sender;

- (IBAction)showScriptsView:(id)sender;
- (IBAction)showStackView:(id)sender;
- (IBAction)showBreakpointView:(id)sender;

- (IBAction)switchToLocals:(id)sender;
- (IBAction)switchToGlobals:(id)sender;
- (IBAction)showTemporaries:(id)sender;
- (IBAction)clearConsole:(id)sender;

- (void)documentWasModified:(ScriptDocument *)document modified:(BOOL)modified;

@end
