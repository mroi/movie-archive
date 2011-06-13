/* This is free software, see file COPYING for license. */

#import "DVDPrepareExtras.h"


@implementation DVDPrepareExtras

@synthesize createNewExtras;

- (id)initWithDocument:(DVDImportDocument *)document
{
	if ((self = [self init])) {
		dvdImport = document;
		
		createNewExtras = YES;

		dispatch_async(dispatch_get_main_queue(), ^{
			[NSBundle loadNibNamed:@"DVDPrepareExtras" owner:self];
		});
	}
	return self;
}

- (void)awakeFromNib
{
	[dvdImport.viewController addView:view];
	[view release];
}

@end
