/* This is free software, see file COPYING for license. */


@interface CPImportViewController : NSWindowController <NSWindowDelegate>
{
	IBOutlet NSProgressIndicator *prepareIndicator;
	IBOutlet NSTextField *prepareLabel;
	IBOutlet NSImageView *errorIcon;
	IBOutlet NSButton *closeButton;
	
	IBOutlet NSBox *topBar;
	IBOutlet NSTextField *caption;
	NSMutableArray *pages;
	IBOutlet NSBox *bottomBar;
	
	NSUInteger activeViewIndex;
}

typedef enum {
	CPImportPrepare, CPImportPrepareSuccess, CPImportPrepareFailure, CPImportRun
} CPImportStage;

@property (readonly, nonatomic) NSView *currentView;
@property (readonly, nonatomic) BOOL hasPreviousView;
@property (readonly, nonatomic) BOOL hasNextView;

/* the methods are to be called only from the main thread */
- (void)indicateImportStage:(CPImportStage)stage;
- (void)addView:(NSView *)view;

- (IBAction)nextPage:(id)sender;
- (IBAction)previousPage:(id)sender;

@end


@interface CPCaptionedScrollView : NSScrollView
{
	NSString *caption;
}
@property (copy) NSString *caption;
@end
