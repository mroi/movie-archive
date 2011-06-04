/* This is free software, see file COPYING for license. */


@interface CPController : NSDocumentController <NSApplicationDelegate>
{
	// 32-bit compatibility requires these Ivars to live here instead of the internal class extension.
	IBOutlet NSMenuItem *menuItemNew;
	NSMutableDictionary *deviceMenuItems;
	dispatch_queue_t deviceManagementQueue;
}
@end


@protocol CPURLSupportQuery
+ (BOOL)isURLSupported:(NSURL *)url;
/* It would result in cleaner code, if NSDocumentController provided a way to enumerate all document types. However, it only supports enumerating all document classes. Therefore, we need a way to retrieve the type name once we have a class claiming support for a URL. */
+ (NSArray *)readableTypes;
@end
