/* This is free software, see file COPYING for license. */

#import "DVDPrepareExtras.h"


@implementation DVDPrepareExtras

- (id)initWithViewController:(CPImportViewController *)views
{
	if ((self = [self init])) {
		viewController = [views retain];
		[NSBundle loadNibNamed:@"DVDPrepareExtras" owner:self];
	}
	return self;
}

- (void)awakeFromNib
{
	[viewController addView:view];
}

- (void)dealloc
{
	[viewController release];
	[super dealloc];
}

@end
