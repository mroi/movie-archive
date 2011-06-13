/* This is free software, see file COPYING for license. */

#include <stdlib.h>
#include <stdarg.h>
#include <objc/runtime.h>

#include "dvdread/dvd_reader.h"
#include "dvdread/ifo_read.h"

#import "DVDPrepareExtras.h"

#import "DVDImportDocument.h"


static NSString *CPLogLevelKey = @"CPLogLevelKey";
static NSString *CPLogMessageKey = @"CPLogMessageKey";


@implementation DVDImportDocument

@synthesize viewController;

#pragma mark NSDocument Life Cycle

+ (BOOL)isDeviceSupported:(NSURL *)url
{
	NSError *error = nil;
	NSFileManager *fileManager = [[[NSFileManager alloc] init] autorelease];
	NSURL *videoTSFolder = [url URLByAppendingPathComponent:@"VIDEO_TS"];
	NSArray *dvdFiles = [fileManager contentsOfDirectoryAtURL:videoTSFolder
								   includingPropertiesForKeys:[NSArray array]
													  options:0
														error:&error];
	return [dvdFiles count] > 0;
}

+ (BOOL)canConcurrentlyReadDocumentsOfType:(NSString *)typeName
{
	return YES;
}

- (id)init
{
	if ((self = [super init])) {
		assets = [[NSMutableSet alloc] init];
		workQueue = [[CPOperationQueue alloc] init];
		log = [[NSMutableArray alloc] init];
		if (!assets || !workQueue || !log) {
			[self release];
			return nil;
		}
		[workQueue setMaxConcurrentOperationCount:1];  // the encoding itself is parallel
		[workQueue setName:@"de.amalthea.dvd2ite.dvdImport"];
	}
	return self;
}

- (id)initWithContentsOfURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
	if ((self = [self initWithType:typeName error:outError])) {
		if (![url checkResourceIsReachableAndReturnError:outError]) {
			[self release];
			return nil;
		}
		[self setFileURL:url];
		
		if ([[self class] isDeviceSupported:url])
			deviceURL = [url retain];
		
		// TODO: if the URL designates a saved import document, obtain the device URL from it
		
		if (!deviceURL) {
			if (outError)
				*outError = [CPDocumentController errorUnsupportedDocument:url];
			[self release];
			return nil;
		}
	}
	return self;
}

- (void)makeWindowControllers
{
	viewController = [[CPImportViewController alloc] init];
	if (!viewController) [self close];
	[self addWindowController:viewController];
	[viewController synchronizeWindowTitleWithDocumentName];
	
	/* document setup complete, start reading in the DVD */
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		dispatch_async(dispatch_get_main_queue(), ^{
			[viewController indicateImportStage:CPImportPrepare];
		});
		BOOL success = [self populateDocumentFromDevice];
		dispatch_async(dispatch_get_main_queue(), ^{
			if (success)
				[viewController indicateImportStage:CPImportPrepareSuccess];
			else
				[viewController indicateImportStage:CPImportPrepareFailure];
		});
	});
}

- (void)dealloc
{
	for (int i = 0; i < sizeof(ifo) / sizeof(ifo[0]); i++)
		ifoClose(ifo[i]);
	DVDClose(dvdread);
	
	[deviceURL release];
	[assets release];
	[prepareOperation release];
	[viewController release];
	[workQueue release];
	[log release];
	
	[super dealloc];
}


#pragma mark Parse DVD and Populate Document

- (BOOL)populateDocumentFromDevice
{
	BOOL success = NO;
	
	/* open dvdread context and parse in all IFOs */
	
	if (dvdread)
		[NSException raise:NSInternalInconsistencyException
					format:@"%s can only be called once per document", sel_getName(_cmd)];
	
	@synchronized (NSApp) {
		setenv("DVDCSS_CACHE", "off", 0);
		NSFileManager *fileManager = [[[NSFileManager alloc] init] autorelease];
		NSString *savedCurrentDir = [fileManager currentDirectoryPath];
		NSString *newCurrentDir = [[[NSBundle mainBundle] executablePath] stringByDeletingLastPathComponent];
		[fileManager changeCurrentDirectoryPath:newCurrentDir];
		dvdread = DVDOpen([[[deviceURL filePathURL] path] fileSystemRepresentation]);
		[fileManager changeCurrentDirectoryPath:savedCurrentDir];
		if (!dvdread) {
			NSLog(@"error opening the DVD for reading");
			goto error;
		}
	}
	
	ifo[0] = ifoOpen(dvdread, 0);
	if (!ifo[0]) {
		NSLog(@"error reading VMGI");
		goto error;
	}
	unsigned vtsCount = ifo[0]->vmgi_mat->vmg_nr_of_title_sets;
	if (vtsCount != ifo[0]->vts_atrt->nr_of_vtss)
		[self logAtLevel:CPLogWarning formattedMessage:@"inconsistent number of video title sets: %1$u and %2$u", ifo[0]->vmgi_mat->vmg_nr_of_title_sets, ifo[0]->vts_atrt->nr_of_vtss];
	unsigned vtsCountMax = sizeof(ifo) / sizeof(ifo[0]) - 1;
	if (vtsCount >= vtsCountMax) {
		[self logAtLevel:CPLogWarning formattedMessage:@"alleged number of title sets (%1$u) is beyond the allowed maximum of %2$u", vtsCount, vtsCountMax];
		vtsCount = vtsCountMax;
	}
	
	for (int vts = 1; vts <= vtsCount; vts++) {
		ifo[vts] = ifoOpen(dvdread, vts);
		if (!ifo[vts]) {
			NSLog(@"error reading VTSI %u", vts);
			goto error;
		}
	}
	
	[self logAtLevel:CPLogNotice formattedMessage:@"all IFOs successfully parsed"];
	
	/* add prepare and finish operation */
	prepareOperation = [[DVDPrepareExtras alloc] initWithDocument:self];
	
	success = YES;
error:
	return success;
}

- (void)logAtLevel:(CPLogLevel)level formattedMessage:(NSString *)format, ...;
{
	va_list argList;
	va_start(argList, format);
	
	NSString *localizedFormat = NSLocalizedString(format, @"DVD import log messages");
	NSString *message = [[[NSString alloc] initWithFormat:format arguments:argList] autorelease];
	NSString *localizedMessage = [[[NSString alloc] initWithFormat:localizedFormat arguments:argList] autorelease];
	
	va_end(argList);
	
	@synchronized (log) {
		[log addObject:[NSDictionary dictionaryWithObjectsAndKeys:
						CPLogLevelKey, [NSNumber numberWithInt:level],
						CPLogMessageKey, localizedMessage,
						nil]];
	}
	NSLog(@"%@", message);
}

@end
