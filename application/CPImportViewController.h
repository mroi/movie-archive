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
	IBOutlet NSButton *dismissButton;
	
	IBOutlet NSBox *topBar;
	IBOutlet NSTextField *caption;
	NSMutableArray *swisherViews;
	IBOutlet NSBox *bottomBar;
}
- (void)indicateImportStage:(NSString *)stage;  // call only from main thread
- (void)addView:(NSView *)view;
@end
