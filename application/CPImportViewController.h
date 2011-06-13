/* This is free software, see file COPYING for license. */


@interface CPImportViewController : NSWindowController <NSWindowDelegate>
{
	IBOutlet NSProgressIndicator *prepareIndicator;
	IBOutlet NSTextField *prepareLabel;
	IBOutlet NSImageView *errorIcon;
	IBOutlet NSButton *closeButton;
	
	IBOutlet NSBox *topBar;
	IBOutlet NSTextField *caption;
	NSMutableArray *swisherViews;
	IBOutlet NSBox *bottomBar;
	
	NSUInteger activeViewIndex;
}

typedef enum {
	CPImportPrepare, CPImportPrepareSuccess, CPImportPrepareFailure, CPImportRun
} CPImportStage;

@property (readonly) NSView *currentView;
@property (readonly) BOOL hasPreviousView;
@property (readonly) BOOL hasNextView;

/* the methods are to be called only from the main thread */
- (void)indicateImportStage:(CPImportStage)stage;
- (void)addView:(NSView *)view;
@end


@interface CPCaptionedScrollView : NSScrollView
{
	NSString *caption;
}
@property (copy) NSString *caption;
@end
