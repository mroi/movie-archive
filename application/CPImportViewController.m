/* This is free software, see file COPYING for license. */

#include <objc/runtime.h>

#import <QuartzCore/CAAnimation.h>
#import <QuartzCore/CATransaction.h>

#import "CPImportViewController.h"


static const NSInteger nextButtonTag = 'next';  // 1852143732
static const NSInteger lastPageTag = 'last';    // 1818325876


#pragma mark -

@implementation CPImportViewController

- (id)init
{
	if ((self = [super initWithWindowNibName:@"CPImportWindow"])) {
		pages = [[NSMutableArray alloc] init];
	}
	return self;
}

- (void)dealloc
{
	[pages release];
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


#pragma mark Computed Properties for Bindings

@dynamic currentView;
@dynamic hasPreviousView;
@dynamic hasNextView;

- (NSView *)currentView
{
	if (activeViewIndex < [pages count])
		return [pages objectAtIndex:activeViewIndex];
	else
		return nil;
}

- (BOOL)hasPreviousView
{
	return activeViewIndex > 0;
}

- (BOOL)hasNextView
{
	return activeViewIndex < [pages count] - 1;
}

+ (NSSet *)keyPathsForValuesAffectingValueForKey:(NSString *)key
{
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	if ([key isEqualToString:@"currentView"] || [key isEqualToString:@"hasPreviousView"] || [key isEqualToString:@"hasNextView"]) {
		NSSet *affectingKeys = [NSSet setWithObject:@"activeViewIndex"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKeys];
	}
	if ([key isEqualToString:@"currentView"] || [key isEqualToString:@"hasNextView"]) {
		NSSet *affectingKeys = [NSSet setWithObject:@"pages"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKeys];
	}
	return keyPaths;
}


#pragma mark Multi-Page View Management

static NSComparisonResult sortByArrayOrder(id left, id right, void *context)
{
	NSArray *array = context;
	NSUInteger leftIndex = [array indexOfObject:left];
	NSUInteger rightIndex = [array indexOfObject:right];
	if (leftIndex == NSNotFound || rightIndex == NSNotFound)
		return NSOrderedSame;
	if (leftIndex < rightIndex)
		return NSOrderedAscending;
	else if (leftIndex > rightIndex)
		return NSOrderedDescending;
	else
		return NSOrderedSame;
}

- (void)indicateImportStage:(CPImportStage)stage
{
	if (![[NSOperationQueue currentQueue] isEqualTo:[NSOperationQueue mainQueue]])
		[NSException raise:NSInternalInconsistencyException
					format:@"%s must only be called from the main thread", sel_getName(_cmd)];
	
	switch (stage) {
		case CPImportPrepare:
			[prepareIndicator startAnimation:self];
			NSString *label = [NSString stringWithFormat:@"Preparing %@…", [[self document] fileType]];
			NSString *localizedLabel = NSLocalizedString(label, @"action labels for import view");
			[prepareLabel setStringValue:localizedLabel];
			[[prepareLabel animator] setHidden:NO];
			break;
			
		case CPImportPrepareSuccess:
			[[[self window] contentView] sortSubviewsUsingFunction:sortByArrayOrder context:pages];
			[[[pages lastObject] viewWithTag:nextButtonTag] removeFromSuperview];
			if ([pages count] > 1)
				[[[pages lastObject] viewWithTag:lastPageTag] setHidden:NO];
			
			[CATransaction begin];
			[CATransaction setCompletionBlock:^{
				[prepareIndicator stopAnimation:self];
				[[prepareIndicator animator] removeFromSuperview];
				[prepareLabel removeFromSuperview];
				[errorIcon removeFromSuperview];
				[closeButton removeFromSuperview];
			}];
			[[topBar animator] setHidden:NO];
			[[[pages objectAtIndex:0] animator] setHidden:NO];
			[[bottomBar animator] setHidden:NO];
			[CATransaction commit];
			break;
			
		case CPImportPrepareFailure:
			[prepareIndicator stopAnimation:self];
			[[prepareIndicator animator] removeFromSuperview];
			NSString *errorLabel = [NSString stringWithFormat:@"Error during %@", [[self document] fileType]];
			NSString *localizedError = NSLocalizedString(errorLabel, @"action labels for import view");
			[prepareLabel setStringValue:localizedError];
			[[errorIcon animator] setHidden:NO];
			[[closeButton animator] setHidden:NO];
			[topBar removeFromSuperview];
			[bottomBar removeFromSuperview];
			break;
			
		case CPImportRun:
			// FIXME: show log and progress bar with ETA
			break;
			
		default:
			[NSException raise:NSInvalidArgumentException
						format:@"%s called with unknown stage “%@”", sel_getName(_cmd), stage];
			break;
	}
}

- (void)addView:(NSView *)view
{
	if (![[NSOperationQueue currentQueue] isEqualTo:[NSOperationQueue mainQueue]])
		[NSException raise:NSInternalInconsistencyException
					format:@"%s must only be called from the main thread", sel_getName(_cmd)];
	
	[view setHidden:YES];
	[view setWantsLayer:YES];
	
	// TODO: use a custom animation drawing a gradient shadow on the leading edge, also animate hiding a page
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
	
	NSControl *nextButton = [view viewWithTag:nextButtonTag];
	[nextButton setTarget:self];
	[nextButton setAction:@selector(nextPage:)];
	
	[contentView addSubview:view positioned:NSWindowAbove relativeTo:prepareLabel];
	// FIXME: we want to order the views by a property we can add in IB
	[self willChangeValueForKey:@"pages"];
	[pages addObject:view];
	[self didChangeValueForKey:@"pages"];
}

- (IBAction)nextPage:(id)sender
{
	if ([self hasNextView]) {
		[self willChangeValueForKey:@"activeViewIndex"];
		activeViewIndex++;
		[[[pages objectAtIndex:activeViewIndex] animator] setHidden:NO];
		[self didChangeValueForKey:@"activeViewIndex"];
	}
}

- (IBAction)previousPage:(id)sender
{
	if ([self hasPreviousView]) {
		[self willChangeValueForKey:@"activeViewIndex"];
		[[[pages objectAtIndex:activeViewIndex] animator] setHidden:YES];
		activeViewIndex--;
		[self didChangeValueForKey:@"activeViewIndex"];
	}
}

- (void)swipeWithEvent:(NSEvent *)event
{
	// TODO: handle swipe gesture for changing views
}

@end


#pragma mark -

@implementation CPCaptionedScrollView

@synthesize caption;

- (void)dealloc
{
	[caption release];
	[super dealloc];
}

@end
