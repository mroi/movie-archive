/* This is free software, see file COPYING for license. */

#import "CPController.h"


@interface DVDImportDocument : NSDocument <CPDeviceSupportQuery>
{
	NSURL *deviceURL;
	NSMutableArray *assets;
	CPViewSwisher *views;
	NSOperationQueue *work;
}
- (BOOL)populateDocumentFromDVD;
@end
