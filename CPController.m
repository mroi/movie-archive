#import "CPController.h"


@interface CPController (InternalMethods)
- (void)deviceDidMount:(NSNotification *)notification;
- (void)deviceDidUnmount:(NSNotification *)notification;
- (IBAction)newDocument:(id)sender;
@end

static BOOL isDeviceUsable(NSString *devicePath);
static NSNotification *notificationForDevice(NSString *devicePath, NSString *name, id object);

#pragma mark -


@implementation CPController

- (id)init
{
	[super init];
	
	deviceMenuItems = [[NSMutableDictionary alloc] init];
	
	NSNotificationCenter *center = [[NSWorkspace sharedWorkspace] notificationCenter];
	
	[center addObserver:self
			   selector:@selector(deviceDidMount:)
				   name:NSWorkspaceDidMountNotification
				 object:NULL];
	[center addObserver:self
			   selector:@selector(deviceDidUnmount:)
				   name:NSWorkspaceDidUnmountNotification
				 object:NULL];
	
	return self;
}

- (void)dealloc
{
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
	[deviceMenuItems dealloc];
	[super dealloc];
}

#pragma mark Handling of "New" Menu Items

- (void)awakeFromNib
{
	for (NSString *devicePath in [[NSWorkspace sharedWorkspace] mountedRemovableMedia])
		[self deviceDidMount:notificationForDevice(devicePath, @"initial device", self)];
}

- (void)deviceDidMount:(NSNotification *)notification
{
	NSString *devicePath = [[notification userInfo] objectForKey:@"NSDevicePath"];
	
	if (!isDeviceUsable(devicePath))
		return;
	
	if ([[deviceMenuItems allKeys] containsObject:devicePath])
		// already a known device; should never happen, so we better revalidate everything
		for (NSString *knownDevicePath in deviceMenuItems)
			if (!isDeviceUsable(knownDevicePath) ||	[knownDevicePath isEqualToString:devicePath])
				[self deviceDidUnmount:notificationForDevice(knownDevicePath,
															 @"invalid device", self)];
	
	NSString *deviceName = [devicePath lastPathComponent];
	NSMenuItem *menuItem = [[NSMenuItem alloc] init];
	NSInteger index = [[menuItemNew menu] indexOfItem:menuItemNew] + [deviceMenuItems count];
	
	NSString *title = NSLocalizedString(@"New from “%@”…",
										@"format string for device-based 'New' menu items");
	[menuItem setTitle:[NSString stringWithFormat:title, deviceName]];
	[menuItem setTarget:self];
	[menuItem setAction:@selector(newDocument:)];
	if ([deviceMenuItems count] == 0) {
		// first one gets a keyboard shortcut
		[menuItem setKeyEquivalent:@"n"];
	} else {
		// delete all keyboard shortcuts to avoid confusion
		for (id key in deviceMenuItems)
			[[deviceMenuItems objectForKey:key] setKeyEquivalent:@""];
	}
	
	[menuItemNew setHidden:YES];
	[menuItemNew setKeyEquivalent:@""];
	[[menuItemNew menu] insertItem:menuItem atIndex:index];
	[deviceMenuItems setObject:menuItem forKey:devicePath];
	
	if ([[[NSDocumentController sharedDocumentController] documents] count] == 0)
		// no documents open, create one for convenience
		[self newDocument:menuItem];
}

- (void)deviceDidUnmount:(NSNotification *)notification
{
	NSString *devicePath = [[notification userInfo] objectForKey:@"NSDevicePath"];
	NSMenuItem *menuItem = [deviceMenuItems objectForKey:devicePath];
	
	if (menuItem) {
		[deviceMenuItems removeObjectForKey:devicePath];
		[[menuItem menu] removeItem:menuItem];
		[menuItem release];
		
		if ([deviceMenuItems count] == 0) {
			// reactivate the dummy "new" menu entry
			[menuItemNew setHidden:NO];
			[menuItemNew setKeyEquivalent:@"n"];
		} else if ([deviceMenuItems count] == 1) {
			NSMenuItem *remainingMenuItem = [[deviceMenuItems allValues] lastObject];
			[remainingMenuItem setKeyEquivalent:@"n"];
		}
	}
}

- (IBAction)newDocument:(id)sender
{
	NSString *devicePath = [[deviceMenuItems keysOfEntriesPassingTest:^(id key, id obj, BOOL *stop) {
		if ([obj isEqualTo:sender]) {
			*stop = YES;
			return YES;
		} else
			return NO;
	}] anyObject];
	
	NSLog(@"would create document for device %@", devicePath);
	// TODO: create new document
}

@end


static BOOL isDeviceUsable(NSString *devicePath)
{
	// FIXME: This is DVD-specific knowledge, but this code here should be generic.
	NSString *mediaPath = [devicePath stringByAppendingString:@"/VIDEO_TS"];
	return [[NSFileManager defaultManager] fileExistsAtPath:mediaPath];
}

static NSNotification *notificationForDevice(NSString *devicePath, NSString *name, id object)
{
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject:devicePath
														 forKey:@"NSDevicePath"];
	NSNotification *notification = [NSNotification notificationWithName:name
																 object:object
															   userInfo:userInfo];
	return notification;
}
