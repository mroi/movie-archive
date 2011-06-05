/* This is free software, see file COPYING for license. */

#import "CPViewSwisher.h"


@implementation CPViewSwisher

- (id)init
{
	if ((self = [super initWithWindowNibName:@"CPImportWindow"])) {
		// initialization
	}
	return self;
}

- (void)dealloc
{
    [super dealloc];
}

- (void)windowDidLoad
{
    [super windowDidLoad];
	[self setWindowFrameAutosaveName:@"ImportWindow"];
	[self setShouldCloseDocument:YES];
}

@end
