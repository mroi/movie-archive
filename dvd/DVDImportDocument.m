/* This is free software, see file COPYING for license. */

#include <stdlib.h>
#include <stdarg.h>

#include "dvdread/dvd_reader.h"
#include "dvdread/ifo_read.h"

#import "DVDImportDocument.h"


NSString *CPLogLevel = @"CPLogLevel";
NSString *CPLogMessage = @"CPLogMessage";


@implementation DVDImportDocument

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

- (id)init
{
	if ((self = [super init])) {
		assets = [[NSMutableSet alloc] init];
		views = [[CPImportViewController alloc] init];
		work = [[NSOperationQueue alloc] init];
		log = [[NSMutableArray alloc] init];
		if (!assets || !views || !work || !log) {
			[self release];
			return nil;
		}
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
	[self addWindowController:views];
	[views synchronizeWindowTitleWithDocumentName];
	
	/* document setup complete, start reading in the DVD */
	// FIXME: run spinning progress indicator with appropriate text
	dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
		BOOL success = [self populateDocumentFromDevice];
		dispatch_async(dispatch_get_main_queue(), ^{
			if (success)
				; // FIXME: done reading, stop spinning indicator and animate in the main UI
			else
				[self close];
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
	[views release];
	[work release];
	[log release];
	
	[super dealloc];
}


#pragma mark Parse DVD and Populate Document

- (BOOL)populateDocumentFromDevice
{
	BOOL success = NO;
	
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
	
	ifo[0] = ifoOpen(dvdread, 0);
	if (!ifo[0]) {
		NSLog(@"error reading VMGI");
		goto error;
	}
	unsigned vtsCount = ifo[0]->vmgi_mat->vmg_nr_of_title_sets;
	if (vtsCount != ifo[0]->vts_atrt->nr_of_vtss)
		[self logAtLevel:CPLogWarning formattedMessage:@"inconsistent number of video title sets: %u and %u", ifo[0]->vmgi_mat->vmg_nr_of_title_sets, ifo[0]->vts_atrt->nr_of_vtss];
	unsigned vtsCountMax = sizeof(ifo) / sizeof(ifo[0]) - 1;
	if (vtsCount >= vtsCountMax) {
		[self logAtLevel:CPLogWarning formattedMessage:@"alleged number of title sets %u is beyond maximum of %u", vtsCount, vtsCountMax];
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
	
	success = YES;
error:
	// TODO: present error if not successful
	return success;
}

- (void)logAtLevel:(NSString *)level formattedMessage:(NSString *)format, ...;
{
	va_list argList;
	va_start(argList, format);
	
	NSString *localizedFormat = NSLocalizedString(format, @"DVD import logging message");
	NSString *message = [[[NSString alloc] initWithFormat:format arguments:argList] autorelease];
	NSString *localizedMessage = [[[NSString alloc] initWithFormat:localizedFormat arguments:argList] autorelease];
	
	va_end(argList);
	
	@synchronized (log) {
		[log addObject:[NSDictionary dictionaryWithObjectsAndKeys:
						CPLogLevel, level,
						CPLogMessage, localizedMessage,
						nil]];
	}
	NSLog(@"%@: %@", level, message);
}

@end
