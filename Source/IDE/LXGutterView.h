#import <Cocoa/Cocoa.h>

@class LXDocument;

@interface LXBreakpointMarker : NSObject {
}

@property (nonatomic) BOOL visible;
@property (nonatomic) CGFloat yPos;
@property (nonatomic, readonly) NSUInteger line;
@property (nonatomic, readonly) NSImage *image;

- (id)initWithImage:(NSImage *)aImage line:(NSUInteger)aLine;

@end


@interface LXGutterView : NSTextView {	
}

@property (nonatomic, weak) LXDocument *document;
@property (nonatomic, retain) NSMutableArray *breakpointMarkers;

- (LXBreakpointMarker *)markerAtLine:(NSUInteger)line;

@end
