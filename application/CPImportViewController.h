/* This is free software, see file COPYING for license. */


static NSString *CPImportPrepare = @"CPImportPrepare";
static NSString *CPImportPrepareSuccess = @"CPImportPrepareSuccess";
static NSString *CPImportPrepareFailure = @"CPImportPrepareFailure";
static NSString *CPImportRun = @"CPImportRun";


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
- (void)indicateImportStage:(NSString *)stage;  // call only from main thread
- (void)addView:(NSView *)view;
@end


@interface CPCaptionedScrollView : NSScrollView
{
	NSString *caption;
}
@property (copy) NSString *caption;
@end
