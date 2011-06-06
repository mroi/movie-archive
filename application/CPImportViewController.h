/* This is free software, see file COPYING for license. */


static NSString *CPImportPrepare = @"CPImportPrepare";
static NSString *CPImportPrepareSuccess = @"CPImportPrepareSuccess";
static NSString *CPImportPrepareFailure = @"CPImportPrepareFailure";
static NSString *CPImportRun = @"CPImportRun";


@interface CPImportViewController : NSWindowController
{
	NSMutableArray *views;
}
- (void)indicateImportStage:(NSString *)stage;
- (void)addView:(NSView *)view;
@end
