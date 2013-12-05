#import <Cocoa/Cocoa.h>

@class LXProjectFileView;

@interface LXBreakpointMarker : NSObject {
}

@property (nonatomic) BOOL visible;
@property (nonatomic) CGFloat yPos;
@property (nonatomic, readonly) NSUInteger line;
@property (nonatomic, readonly) NSImage *image;

- (id)initWithImage:(NSImage *)aImage line:(NSUInteger)aLine;

@end


@interface LXGutterView : NSView {
}

@property (nonatomic, weak) LXProjectFileView *document;
@property (nonatomic, assign) NSInteger offset;
@property (nonatomic, assign) NSRange lineNumberRange;
@property (nonatomic, strong) NSArray *lineNumbers;
@property (nonatomic, strong) NSMutableArray *breakpointMarkers;

- (LXBreakpointMarker *)markerAtLine:(NSUInteger)line;

@end
