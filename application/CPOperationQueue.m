/* This is free software, see file COPYING for license. */

#import "CPOperationQueue.h"


@implementation CPOperationQueue

@end


@implementation CPOperation

- (id)init
{
	return [self initWithTarget:self selector:@selector(run) object:nil];
}

- (void)run
{
	[self doesNotRecognizeSelector:_cmd];
}

@end
