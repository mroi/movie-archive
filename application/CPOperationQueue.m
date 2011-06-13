/* This is free software, see file COPYING for license. */

#import "CPOperationQueue.h"


@implementation CPOperationQueue

@end


@implementation CPOperation

- (id)init
{
	if ((self = [super init])) {
		[self setThreadPriority:0.0];  // perform import in the background
	}
	return self;
}

// TODO: derive queue priority from asset length, convert long assets (and library assets) first

@end
