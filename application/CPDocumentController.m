/* This is free software, see file COPYING for license. */

#include <objc/runtime.h>

#import "CPDocumentController.h"


@interface CPDocumentController ()
- (void)deviceDidMount:(NSNotification *)notification;
- (void)deviceDidUnmount:(NSNotification *)notification;
@end


#pragma mark -

@implementation CPDocumentController

- (id)init
{
	if ((self = [super init])) {
		deviceMenuItems = [[NSMutableDictionary alloc] init];
		deviceManagementQueue = dispatch_queue_create("de.amalthea.dvd2ite.devices", NULL);
		
		NSNotificationCenter *center = [[NSWorkspace sharedWorkspace] notificationCenter];
		
		[center addObserver:self
				   selector:@selector(deviceDidMount:)
					   name:NSWorkspaceDidMountNotification
					 object:NULL];
		[center addObserver:self
				   selector:@selector(deviceDidUnmount:)
					   name:NSWorkspaceDidUnmountNotification
					 object:NULL];
	}
	return self;
}

- (void)dealloc
{
	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
	dispatch_sync(deviceManagementQueue, ^{
		[deviceMenuItems dealloc];
	});
	[super dealloc];
}


#pragma mark Management of "New" Menu Items

static BOOL isDeviceUsable(NSString *devicePath, NSDocumentController *documentController)
{
	NSURL *deviceURL = [NSURL fileURLWithPath:devicePath];
	return [documentController typeForContentsOfURL:deviceURL error:NULL] ? YES : NO;
}

static NSNotification *notificationForDevice(NSString *devicePath, NSString *name, id sender)
{
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject:devicePath
														 forKey:@"NSDevicePath"];
	NSNotification *notification = [NSNotification notificationWithName:name
																 object:sender
															   userInfo:userInfo];
	return notification;
}

static void foundInvalidDevice(NSString *invalidDevicePath, CPDocumentController *self)
{
	for (NSString *devicePath in self->deviceMenuItems)
		if (!isDeviceUsable(devicePath, self) || [devicePath isEqualToString:invalidDevicePath])
			[self deviceDidUnmount:notificationForDevice(devicePath, NSWorkspaceDidUnmountNotification, self)];
}

- (void)awakeFromNib
{
	for (NSString *devicePath in [[NSWorkspace sharedWorkspace] mountedRemovableMedia])
		[self deviceDidMount:notificationForDevice(devicePath, NSWorkspaceDidMountNotification, self)];
	// TODO: provide some feedback if there is no usable device
}

- (void)deviceDidMount:(NSNotification *)notification
{
	NSString *devicePath = [[notification userInfo] objectForKey:@"NSDevicePath"];
	
	dispatch_async(deviceManagementQueue, ^{
		if (!isDeviceUsable(devicePath, self))
			return;
		
		if ([[deviceMenuItems allKeys] containsObject:devicePath])
			// already a known device, should never happen
			foundInvalidDevice(devicePath, self);
		
		NSString *deviceName = [[[[NSFileManager alloc] init] autorelease] displayNameAtPath:devicePath];
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
			// TODO: push entries into a submenu at a threshold of 5
			dispatch_sync(dispatch_get_main_queue(), ^{
				// delete all keyboard shortcuts to avoid confusion
				for (id key in deviceMenuItems)
					[[deviceMenuItems objectForKey:key] setKeyEquivalent:@""];
			});
		}
		
		dispatch_sync(dispatch_get_main_queue(), ^{
			[menuItemNew setHidden:YES];
			[menuItemNew setKeyEquivalent:@""];
			[[menuItemNew menu] insertItem:menuItem atIndex:index];
		});
		
		[deviceMenuItems setObject:menuItem forKey:devicePath];
		
		dispatch_async(dispatch_get_main_queue(), ^{
			if ([[[NSDocumentController sharedDocumentController] documents] count] == 0)
				// no documents open, create one for convenience
				[self newDocument:menuItem];
		});
	});
}

- (void)deviceDidUnmount:(NSNotification *)notification
{
	NSString *devicePath = [[notification userInfo] objectForKey:@"NSDevicePath"];
	
	dispatch_async(deviceManagementQueue, ^{
		NSMenuItem *menuItem = [deviceMenuItems objectForKey:devicePath];
		
		if (menuItem) {
			[deviceMenuItems removeObjectForKey:devicePath];
			dispatch_sync(dispatch_get_main_queue(), ^{
				[[menuItem menu] removeItem:menuItem];
				
				if ([deviceMenuItems count] == 0) {
					// reactivate the dummy "new" menu entry
					[menuItemNew setHidden:NO];
					[menuItemNew setKeyEquivalent:@"n"];
				} else if ([deviceMenuItems count] == 1) {
					NSMenuItem *remainingMenuItem = [[deviceMenuItems allValues] lastObject];
					[remainingMenuItem setKeyEquivalent:@"n"];
				}
			});
			[menuItem release];
		}
	});
}


#pragma mark NSDocumentController

- (IBAction)newDocument:(id)sender
{
	__block NSString *devicePath;
	
	dispatch_sync(deviceManagementQueue, ^{
		// reverse lookup in NSDictionary
		devicePath = [[deviceMenuItems keysOfEntriesPassingTest:^(id key, id obj, BOOL *stop) {
			if ([obj isEqualTo:sender]) {
				*stop = YES;
				return YES;
			} else
				return NO;
		}] anyObject];
	});

	NSError *error = nil;
	NSURL *documentURL = [NSURL fileURLWithPath:devicePath];
	id document;
	
retry:
	document = [self openDocumentWithContentsOfURL:documentURL display:YES error:&error];
	if (!document) {
		if ([self presentError:error])
			goto retry;
		foundInvalidDevice(devicePath, self);
	}
}

- (NSString *)typeForContentsOfURL:(NSURL *)url error:(NSError **)outError
{
	NSString *typeName = nil;
	
	for (NSString *className in [self documentClassNames]) {
		id class = objc_getClass([className UTF8String]);
		if ([class conformsToProtocol:@protocol(CPDeviceSupportQuery)]) {
			id <CPDeviceSupportQuery> documentClass = class;
			if ([documentClass isDeviceSupported:url]) {
				typeName = [[documentClass readableTypes] lastObject];
				break;
			}
		} else
			NSLog(@"document class %@ does not implement formal protocol CPDeviceSupportQuery", className);
	}
	
	// TODO: if its not a supported device, it might be a saved import document; check NSURLTypeIdentifierKey and convert to CFBundleTypeName
	
	if (!typeName && outError)
		*outError = [CPDocumentController errorUnsupportedDocument:url];
	
	return typeName;
}

+ (NSError *)errorUnsupportedDocument:(NSURL *)documentURL
{
	NSString *displayName;
	if (![documentURL getResourceValue:&displayName forKey:NSURLLocalizedNameKey error:NULL])
		displayName = [documentURL lastPathComponent];
	NSString *descriptionFormat = NSLocalizedString(@"The document or device “%@” cannot be opened.", @"error text used when opening a document fails");
	NSString *description = [NSString stringWithFormat:descriptionFormat, displayName];
	NSDictionary *errorInfo = [NSDictionary dictionaryWithObjectsAndKeys:
							   description, NSLocalizedDescriptionKey,
							   documentURL, NSURLErrorKey, nil];
	return [NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorUnsupportedURL userInfo:errorInfo];
}


#pragma mark NSApplicationDelegate

- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender
{
	return NO;
}

- (void)applicationWillTerminate:(NSNotification *)notification
{
	[self release];
}

@end
