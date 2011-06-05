/* This is free software, see file COPYING for license. */

#include "dvdread/dvd_reader.h"

#import "CPController.h"


@interface DVDImportDocument : NSDocument <CPDeviceSupportQuery>
{
	NSURL *deviceURL;
	NSMutableArray *assets;
	CPViewSwisher *views;
	NSOperationQueue *work;
	dvd_reader_t *dvdread;
}
- (BOOL)populateDocumentFromDVD;
@end
