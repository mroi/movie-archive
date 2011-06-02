/* This is free software, see file COPYING for license. */

#import "DVDImportDocument.h"


@implementation DVDImportDocument

+ (BOOL)isURLSupported:(NSURL *)url
{
	NSString *devicePath = [[url filePathURL] path];
	NSString *mediaPath = [devicePath stringByAppendingString:@"/VIDEO_TS"];
	return [[[[NSFileManager alloc] init] autorelease] fileExistsAtPath:mediaPath];
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

- (NSString *)windowNibName
{
    return @"DVDImportWindow";
}

- (void)windowControllerDidLoadNib:(NSWindowController *) aController
{
    [super windowControllerDidLoadNib:aController];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
}

@end
