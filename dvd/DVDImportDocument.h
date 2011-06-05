/* This is free software, see file COPYING for license. */

#include "dvdread/dvd_reader.h"
#include "dvdread/ifo_types.h"

#import "CPController.h"
#import "CPViewSwisher.h"


NSString *CPLogNotice = @"CPLogNotice";
NSString *CPLogWarning = @"CPLogWarning";
NSString *CPLogError = @"CPLogError";


@interface DVDImportDocument : NSDocument <CPDeviceSupportQuery>
{
	NSURL *deviceURL;
	NSMutableSet *assets;
	CPViewSwisher *views;
	NSOperationQueue *work;
	NSMutableArray *log;
	
	dvd_reader_t *dvdread;
	ifo_handle_t *ifo[100];  // VTS files are numbered with two decimal digits, so 100 is enough
}
- (BOOL)populateDocumentFromDevice;
- (void)logAtLevel:(NSString *)level formattedMessage:(NSString *)format, ...;
@end
