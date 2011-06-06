/* This is free software, see file COPYING for license. */

#include "dvdread/dvd_reader.h"
#include "dvdread/ifo_types.h"

#import "CPDocumentController.h"
#import "CPImportViewController.h"
#import "CPOperationQueue.h"


static NSString *CPLogNotice = @"CPLogNotice";
static NSString *CPLogWarning = @"CPLogWarning";
static NSString *CPLogError = @"CPLogError";


// TODO: we may want to factor out a generic, DVD-independent part in CPImportDocument
@interface DVDImportDocument : NSDocument <CPDeviceSupportQuery>
{
	NSURL *deviceURL;
	NSMutableSet *assets;
	CPOperation *prepareOperation;
	CPOperation *finalizeOperation;
	
	CPImportViewController *viewController;
	CPOperationQueue *workQueue;
	NSMutableArray *log;
	
	dvd_reader_t *dvdread;
	ifo_handle_t *ifo[100];  // VTS files are numbered with two decimal digits, so 100 is enough
}
- (BOOL)populateDocumentFromDevice;
- (void)logAtLevel:(NSString *)level formattedMessage:(NSString *)format, ...;
@end
