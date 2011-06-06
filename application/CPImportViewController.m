/* This is free software, see file COPYING for license. */

#import "CPImportViewController.h"


@implementation CPImportViewController

- (id)init
{
	if ((self = [super initWithWindowNibName:@"CPImportWindow"])) {
		views = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)windowDidLoad
{
    [super windowDidLoad];
	[self setWindowFrameAutosaveName:@"ImportWindow"];
	[self setShouldCloseDocument:YES];
}

- (void)dealloc
{
	[views release];
	[super dealloc];
}


#pragma mark View Swisher Management

- (void)indicateImportStage:(NSString *)stage
{
	if (![[NSOperationQueue currentQueue] isEqualTo:[NSOperationQueue mainQueue]])
		[NSException raise:NSInternalInconsistencyException
					format:@"-indicateImportStage: must only be called from the main thread"];
	
	if ([stage isEqualToString:CPImportPrepare]) {
		// FIXME: run spinning progress indicator with appropriate text below
	} else if ([stage isEqualToString:CPImportPrepareSuccess]) {
		// FIXME: stop spinning indicator, animate in the main UI
		if ([views count]) {
			// this is just a mockup to show something
			NSView *contentView = [[self window] contentView];
			NSView *firstView = [views objectAtIndex:0];
			NSRect frame = [contentView frame];
			frame.origin.x -= 1.0;
			frame.origin.y += 49.0;
			frame.size.width += 2.0;
			frame.size.height -= 92.0;
			[firstView setFrame:frame];
			[contentView addSubview:firstView];
		}
	} else if ([stage isEqualToString:CPImportPrepareFailure]) {
		// FIXME: stop spinning indicator, present error, OK button closes window
	} else if ([stage isEqualToString:CPImportRun]) {
		// FIXME: show log and progress bar with ETA
	}
}

- (void)addView:(NSView *)view
{
	@synchronized (views) {
		// FIXME: we want to order the views by a runtime property we can add to NSView in IB
		[views addObject:view];
	}
}

@end
