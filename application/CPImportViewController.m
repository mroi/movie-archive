/* This is free software, see file COPYING for license. */

#import "CPImportViewController.h"


@implementation CPImportViewController

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
