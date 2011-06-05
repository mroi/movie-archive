/* This is free software, see file COPYING for license. */

#include <stdlib.h>

#include "dvdread/dvd_reader.h"
#include "dvdread/ifo_read.h"

#import "CPViewSwisher.h"
#import "CPController.h"

#import "DVDImportDocument.h"


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
		assets = [[NSMutableArray alloc] init];
		views = [[CPViewSwisher alloc] init];
		work = [[NSOperationQueue alloc] init];
		if (!assets || !views || !work) {
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
				*outError = [CPController errorUnsupportedDocument:url];
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
		BOOL success = [self populateDocumentFromDVD];
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
	
	[super dealloc];
}


#pragma mark Parse DVD and Populate Document

- (BOOL)populateDocumentFromDVD
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
	if (vtsCount != ifo[0]->vts_atrt->nr_of_vtss) {
		NSLog(@"inconsistent information on number of video title sets");
		// TODO: log a warning to show during import
	}
	unsigned vtsCountMax = sizeof(ifo) / sizeof(ifo[0]) - 1;
	if (vtsCount >= vtsCountMax) {
		NSLog(@"alleged number of title sets %u is beyond maximum of %u", vtsCount, vtsCountMax);
		// TODO: log a warning to show during import
		vtsCount = vtsCountMax;
	}
	
	for (int i = 1; i <= vtsCount; i++) {
		ifo[i] = ifoOpen(dvdread, i);
		if (!ifo[i]) {
			NSLog(@"error reading VTSI %u", i);
			goto error;
		}
	}
	
	success = YES;
error:
	// TODO: present error if not successful
	return success;
}

@end
