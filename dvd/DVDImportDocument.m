/* This is free software, see file COPYING for license. */

#import "DVDImportDocument.h"

@implementation DVDImportDocument

- (id)init
{
    self = [super init];
    if (self) {
    
        // Add your subclass-specific initialization here.
        // If an error occurs here, send a [self release] message and return nil.
    
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

+ (BOOL)isURLSupported:(NSURL *)url
{
	NSString *devicePath = [[url filePathURL] path];
	NSString *mediaPath = [devicePath stringByAppendingString:@"/VIDEO_TS"];
	return [[[[NSFileManager alloc] init] autorelease] fileExistsAtPath:mediaPath];
}

- (id)initWithContentsOfURL:(NSURL *)url ofType:(NSString *)typeName error:(NSError **)outError
{
	// TODO: read the url and create the document
	return [self initWithType:typeName error:outError];
}

@end
