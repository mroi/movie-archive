/* This is free software, see file COPYING for license. */

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
	[deviceURL release];
	[assets release];
	[views release];
	[work release];
	[super dealloc];
}


#pragma mark Parse DVD and Populate Document

- (BOOL)populateDocumentFromDVD
{
	BOOL retry = NO, success = NO;
	
	do {
		success = YES;
	} while (retry);
	
	return success;
}

@end
