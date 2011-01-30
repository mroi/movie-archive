#import "CPController.h"


@interface CPController (InternalMethods)
- (void)deviceDidMount:(NSNotification *)notification;
- (void)deviceDidUnmount:(NSNotification *)notification;
- (IBAction)newDocument:(id)sender;
@end

static BOOL isDeviceUsable(NSString *devicePath);

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
	for (NSString *devicePath in [[NSWorkspace sharedWorkspace] mountedRemovableMedia]) {
		NSDictionary *userInfo =
			[NSDictionary dictionaryWithObject:devicePath
										forKey:@"NSDevicePath"];
		NSNotification *notification =
			[NSNotification notificationWithName:@"initial device"
										  object:self
										userInfo:userInfo];
		[self deviceDidMount:notification];
	}
}

- (void)deviceDidMount:(NSNotification *)notification
{
	NSString *devicePath = [[notification userInfo] objectForKey:@"NSDevicePath"];
	
	if (isDeviceUsable(devicePath)) {
		
		if ([[deviceMenuItems allKeys] containsObject:devicePath]) {
			// already a known device; should never happen, so we better revalidate everything
			for (NSString *devicePath in deviceMenuItems) {
				if (!isDeviceUsable(devicePath)) {
					NSDictionary *userInfo =
						[NSDictionary dictionaryWithObject:devicePath
													forKey:@"NSDevicePath"];
					NSNotification *notification =
						[NSNotification notificationWithName:@"invalid device"
													  object:self
													userInfo:userInfo];
					[self deviceDidUnmount:notification];
				}
			}
		}
		
		NSString *deviceName = [devicePath lastPathComponent];
		NSMenuItem *item = [[NSMenuItem alloc] init];
		NSInteger index = [[menuItemNew menu] indexOfItem:menuItemNew] + [deviceMenuItems count];
		
		NSString *title = NSLocalizedString(@"New from “%@”…",
											@"format string for device-based 'New' menu items");
		[item setTitle:[NSString stringWithFormat:title, deviceName]];
		[item setTarget:self];
		[item setAction:@selector(newDocument:)];
		if ([deviceMenuItems count] == 0) {
			// first one gets a keyboard shortcut
			[item setKeyEquivalent:@"n"];
		} else {
			// delete all keyboard shortcuts to avoid confusion
			for (id devicePath in deviceMenuItems)
				[[deviceMenuItems objectForKey:devicePath] setKeyEquivalent:@""];
		}
		
		[menuItemNew setHidden:YES];
		[menuItemNew setKeyEquivalent:@""];
		[[menuItemNew menu] insertItem:item atIndex:index];
		[deviceMenuItems setObject:item forKey:devicePath];
	}
}

- (void)deviceDidUnmount:(NSNotification *)notification
{
	NSString *devicePath = [[notification userInfo] objectForKey:@"NSDevicePath"];
	NSMenuItem *item = [deviceMenuItems objectForKey:devicePath];
	
	if (item) {
		[deviceMenuItems removeObjectForKey:devicePath];
		[[item menu] removeItem:item];
		[item release];
		
		if ([deviceMenuItems count] == 0) {
			[menuItemNew setHidden:NO];
			[menuItemNew setKeyEquivalent:@"n"];
		} else if ([deviceMenuItems count] == 1) {
			NSMenuItem *item = [[deviceMenuItems allValues] lastObject];
			[item setKeyEquivalent:@"n"];
		}
	}
}

- (IBAction)newDocument:(id)sender
{
	// TODO: create new document
}

@end


static BOOL isDeviceUsable(NSString *devicePath)
{
	// FIXME: This is DVD-specific knowledge, but this code here should be generic.
	NSString *mediaPath = [devicePath stringByAppendingString:@"/VIDEO_TS"];
	return [[NSFileManager defaultManager] fileExistsAtPath:mediaPath];
}
