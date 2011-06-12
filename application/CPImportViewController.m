/* This is free software, see file COPYING for license. */

#include <objc/runtime.h>

#import <QuartzCore/CAAnimation.h>
#import <QuartzCore/CATransaction.h>

#import "CPImportViewController.h"


@implementation CPImportViewController

- (id)init
{
	if ((self = [super initWithWindowNibName:@"CPImportWindow"])) {
		swisherViews = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[swisherViews release];
	[super dealloc];
}


#pragma mark General Window Management

- (void)windowDidLoad
{
    [super windowDidLoad];
	[self setWindowFrameAutosaveName:@"ImportWindow"];
	[self setShouldCloseDocument:YES];
	
	[prepareIndicator setUsesThreadedAnimation:YES];
	
	// BUG: Wiggle the sizing of the bottom bar, otherwise the GrowBox image in the bottom right will snap into a properly pixel-aligned position at the first user-triggered resize.
	NSSize oldSize = NSSizeFromCGSize([bottomBar frame].size);
	NSSize newSize = NSMakeSize(oldSize.width - 1.0, oldSize.height);
	[bottomBar setFrameSize:newSize];
	[bottomBar setFrameSize:oldSize];
	
	if (![[self window] isMainWindow])
		[self windowDidResignMain:nil];
}

static const CGFloat alphaDefault = 1.0;
static const CGFloat alphaForInactiveBars = 0.3;
static const CGFloat alphaForInactiveText = 0.5;
static const CGFloat alphaInvisible = 0.0;

- (void)windowDidBecomeMain:(NSNotification *)notification
{
	[topBar setFillColor:[[topBar fillColor] colorWithAlphaComponent:alphaDefault]];
	[bottomBar setFillColor:[[bottomBar fillColor] colorWithAlphaComponent:alphaDefault]];
	[caption setTextColor:[[caption textColor] colorWithAlphaComponent:alphaDefault]];
	[caption setBackgroundColor:[[caption backgroundColor] colorWithAlphaComponent:alphaDefault]];
}

- (void)windowDidResignMain:(NSNotification *)notification
{
	[topBar setFillColor:[[topBar fillColor] colorWithAlphaComponent:alphaForInactiveBars]];
	[bottomBar setFillColor:[[bottomBar fillColor] colorWithAlphaComponent:alphaForInactiveBars]];
	[caption setTextColor:[[caption textColor] colorWithAlphaComponent:alphaForInactiveText]];
	[caption setBackgroundColor:[[caption backgroundColor] colorWithAlphaComponent:alphaInvisible]];
}


#pragma mark View Swisher Management

- (void)indicateImportStage:(NSString *)stage
{
	if (![[NSOperationQueue currentQueue] isEqualTo:[NSOperationQueue mainQueue]])
		[NSException raise:NSInternalInconsistencyException
					format:@"%s must only be called from the main thread", sel_getName(_cmd)];
	
	if ([stage isEqualToString:CPImportPrepare]) {
		[prepareIndicator startAnimation:self];
		NSString *typeLabel = [NSString stringWithFormat:@"Preparing %@…", [[self document] fileType]];
		NSString *localizedLabel = NSLocalizedString(typeLabel, @"action labels for import view");
		[prepareLabel setStringValue:localizedLabel];
		[[prepareLabel animator] setHidden:NO];
	} else if ([stage isEqualToString:CPImportPrepareSuccess]) {
		[CATransaction begin];
		[CATransaction setCompletionBlock:^{
			[prepareIndicator stopAnimation:self];
			[[prepareIndicator animator] removeFromSuperview];
			[prepareLabel removeFromSuperview];
			[errorIcon removeFromSuperview];
			[dismissButton removeFromSuperview];
		}];
		[[topBar animator] setHidden:NO];
		// FIXME: stagger the animations of the swisher views
		for (NSView *view in swisherViews)
			[[view animator] setHidden:NO];
		[[bottomBar animator] setHidden:NO];
		[CATransaction commit];
	} else if ([stage isEqualToString:CPImportPrepareFailure]) {
		[prepareIndicator stopAnimation:self];
		NSString *errorLabel = [NSString stringWithFormat:@"Error during %@", [[self document] fileType]];
		NSString *localizedLabel = NSLocalizedString(errorLabel, @"action labels for import view");
		[prepareLabel setStringValue:localizedLabel];
		[[errorIcon animator] setHidden:NO];
		[[dismissButton animator] setHidden:NO];
	} else if ([stage isEqualToString:CPImportRun]) {
		// FIXME: show log and progress bar with ETA
	} else {
		[NSException raise:NSInvalidArgumentException
					format:@"%s called with unknown stage “%@”", sel_getName(_cmd), stage];
	}
}

- (void)addView:(NSView *)view
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[view setHidden:YES];
		[view setWantsLayer:YES];
		
		CATransition *moveIn = [CATransition animation];
		[moveIn setType:kCATransitionMoveIn];
		[moveIn setSubtype:kCATransitionFromRight];
		// BUG: Per my understanding, the key should be NSAnimationTriggerOrderIn here, but that does not work.
		[view setAnimations:[NSDictionary dictionaryWithObject:moveIn forKey:@"hidden"]];
		
		NSView *contentView = [[self window] contentView];
		NSRect frame;
		NSRect contentFrame = [contentView frame];
		NSRect topBarFrame = [topBar frame];
		NSRect bottomBarFrame = [bottomBar frame];
		frame.origin.x = contentFrame.origin.x;
		frame.origin.y = bottomBarFrame.origin.y + bottomBarFrame.size.height;
		frame.size.width = contentFrame.size.width;
		frame.size.height = topBarFrame.origin.y - frame.origin.y;
		[view setFrame:frame];
		
		// FIXME: we want to order the views by a runtime property we can add to NSView in IB
		[contentView addSubview:view positioned:NSWindowAbove relativeTo:prepareLabel];
		[swisherViews addObject:view];
	});
}

- (void)swipeWithEvent:(NSEvent *)event
{
	// TODO: handle swipe gesture for changing views
}

@end
