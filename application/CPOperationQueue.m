/* This is free software, see file COPYING for license. */

#import "CPOperationQueue.h"


@implementation CPOperationQueue

@end


@implementation CPOperation

- (id)init
{
	if ((self = [self initWithTarget:self selector:@selector(run) object:nil]))
		[self autorelease];  // NSInvocationOperation retains its target, which is self here
	return self;
}

- (void)run
{
	[self doesNotRecognizeSelector:_cmd];
}

@end
