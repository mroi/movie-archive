/* This is free software, see file COPYING for license. */

#import "DVDImportDocument.h"
#import "CPOperationQueue.h"


@interface DVDPrepareExtras : CPOperation
{
	DVDImportDocument *dvdImport;  // weak reference to avoid retain cycle
	IBOutlet NSView *view;
}
- (id)initWithDocument:(DVDImportDocument *)document;
@end
