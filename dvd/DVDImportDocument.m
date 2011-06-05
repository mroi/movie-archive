/* This is free software, see file COPYING for license. */

#import "CPViewSwisher.h"

#import "DVDImportDocument.h"


@implementation DVDImportDocument

+ (BOOL)isURLSupported:(NSURL *)url
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
        // subclass-specific initialization goes here
    }
    return self;
}

- (id)initWithContentsOfURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
	if ((self = [self initWithType:typeName error:outError])) {
		[self setFileURL:url];
		// TODO: read the url and init the document
	}
	return self;
}

- (void)makeWindowControllers
{
	CPViewSwisher *viewSwisher = [[[CPViewSwisher alloc] init] autorelease];
	if (viewSwisher) {
		[self addWindowController:viewSwisher];
		[viewSwisher synchronizeWindowTitleWithDocumentName];
	}
}

@end
