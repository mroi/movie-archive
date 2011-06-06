/* This is free software, see file COPYING for license. */

#import "CPImportViewController.h"
#import "CPOperationQueue.h"


@interface DVDPrepareExtras : CPOperation
{
	IBOutlet NSView *view;
	CPImportViewController *viewController;
}
- (id)initWithViewController:(CPImportViewController *)views;
@end
