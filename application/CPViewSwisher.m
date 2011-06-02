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
    
    // Implement this method to handle any initialization after your window controller's window has been loaded from its nib file.
}

@end
