@interface CPController : NSObject <NSApplicationDelegate>
{
	IBOutlet NSMenuItem *menuItemNew;
	NSMutableDictionary *deviceMenuItems;
	dispatch_queue_t deviceManagementQueue;
}
@end
