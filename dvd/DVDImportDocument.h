/* This is free software, see file COPYING for license. */

#include "dvdread/dvd_reader.h"
#include "dvdread/ifo_types.h"

#import "CPController.h"


@interface DVDImportDocument : NSDocument <CPDeviceSupportQuery>
{
	NSURL *deviceURL;
	NSMutableArray *assets;
	CPViewSwisher *views;
	NSOperationQueue *work;
	
	dvd_reader_t *dvdread;
	ifo_handle_t *ifo[100];  // VTS files are numbered with two decimal digits, so 100 is enough
}
- (BOOL)populateDocumentFromDVD;
@end
