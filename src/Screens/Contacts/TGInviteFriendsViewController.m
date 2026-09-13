#import "TGInviteFriendsViewController.h"
#import "TGHexColour.h"
#import "TGContactsViewControllerInternal.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import <dlfcn.h>

@interface TGMessageComposerShim : UIViewController
+ (BOOL)canSendText;
- (void)setRecipients:(NSArray *)recipients;
- (void)setBody:(NSString *)body;
- (void)setMessageComposeDelegate:(id)delegate;
@end

static Class TGMessageComposerClass(void) {
	Class cls = NSClassFromString(@"MFMessageComposeViewController");
	if (cls)
		return cls;
	dlopen("/System/Library/Frameworks/MessageUI.framework/MessageUI", RTLD_LAZY);
	return NSClassFromString(@"MFMessageComposeViewController");
}

static BOOL TGCanSendSMS(void) {
	Class cls = TGMessageComposerClass();
	if (!cls || ![cls respondsToSelector:@selector(canSendText)])
		return NO;
	NSMethodSignature *signature = [cls methodSignatureForSelector:@selector(canSendText)];
	if (!signature)
		return NO;
	NSInvocation *invocation = [NSInvocation invocationWithMethodSignature:signature];
	invocation.selector = @selector(canSendText);
	invocation.target = cls;
	[invocation invoke];
	BOOL result = NO;
	[invocation getReturnValue:&result];
	return result;
}

@implementation TGInviteFriendsViewController

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.title = TGL(@"Contacts.InviteFriends", @"Invite Friends");
	self.selected = [NSMutableSet set];
	self.tableView.rowHeight = kContactRowHeight;
	self.tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.tableView.separatorColor = [[TGTheme shared] separatorColour];
	self.inviteButton = [UIButton buttonWithType:UIButtonTypeCustom];
	[TGIcons styleHeaderButton:self.inviteButton];
	[self.inviteButton addTarget:self action:@selector(inviteTapped)
				forControlEvents:UIControlEventTouchUpInside];
	self.inviteLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	self.inviteLabel.textColor = [UIColor whiteColor];
	self.inviteLabel.textAlignment = NSTextAlignmentCenter;
	self.inviteLabel.backgroundColor = [UIColor clearColor];
	self.inviteLabel.font = [UIFont boldSystemFontOfSize:12];
	self.inviteLabel.userInteractionEnabled = NO;
	[self.inviteButton addSubview:self.inviteLabel];
	self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:self.inviteButton];
	[self updateInviteButton];
}

- (void)updateInviteButton {
	if (!self.inviteButton)
		return;
	NSString *title = self.selected.count
		? [NSString stringWithFormat:TGL(@"Contacts.InviteFriendsButtonWithCount", @"Invite (%d)"), (int)self.selected.count]
		: TGL(@"Contacts.InviteFriendsButton", @"Invite");
	self.inviteLabel.text = title;
	CGSize size = [title sizeWithFont:self.inviteLabel.font];
	self.inviteButton.frame = CGRectMake(0, 0, size.width + 16, 30);
	self.inviteLabel.frame = self.inviteButton.bounds;
	self.inviteButton.enabled = self.selected.count > 0;
	self.inviteButton.alpha = self.selected.count ? 1.0f : 0.5f;
}

- (NSString *)nameForEntry:(NSDictionary *)entry {
	NSString *first = TGContactString(entry, @"first_name");
	NSString *last = TGContactString(entry, @"last_name");
	NSString *name = [[NSString stringWithFormat:@"%@ %@", first, last]
		stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
	return name.length ? name : [NSString stringWithFormat:@"+%@", TGContactString(entry, @"phone")];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return self.entries.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *reuse = @"TGInviteEntryCell";
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle
									  reuseIdentifier:reuse];
	if (indexPath.row >= (NSInteger)self.entries.count)
		return cell;
	NSDictionary *entry = self.entries[indexPath.row];
	NSString *phone = TGContactString(entry, @"phone");
	cell.textLabel.font = [UIFont systemFontOfSize:19];
	cell.textLabel.text = [self nameForEntry:entry];
	cell.detailTextLabel.font = [UIFont systemFontOfSize:13.5f];
	cell.detailTextLabel.textColor = [[TGTheme shared] secondaryTextColour];
	cell.detailTextLabel.text = phone.length ? [NSString stringWithFormat:@"+%@", phone] : @"";
	cell.backgroundColor = [[TGTheme shared] listBackgroundColour];
	cell.accessoryType = [self.selected containsObject:phone]
		? UITableViewCellAccessoryCheckmark
		: UITableViewCellAccessoryNone;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.row >= (NSInteger)self.entries.count)
		return;
	NSString *phone = TGContactString(self.entries[indexPath.row], @"phone");
	if (!phone.length)
		return;
	if ([self.selected containsObject:phone])
		[self.selected removeObject:phone];
	else
		[self.selected addObject:phone];
	[tableView reloadRowsAtIndexPaths:@[ indexPath ]
					 withRowAnimation:UITableViewRowAnimationNone];
	[self updateInviteButton];
}

- (void)shareFallback {
	NSString *text = self.inviteText.length ? self.inviteText : @"";
	if (!text.length)
		return;
	UIActivityViewController *sheet = [[UIActivityViewController alloc]
		initWithActivityItems:@[ text ]
		applicationActivities:nil];
	[self presentViewController:sheet animated:YES completion:nil];
}

- (void)inviteTapped {
	if (!self.selected.count)
		return;
	NSMutableArray *recipients = [NSMutableArray array];
	for (NSDictionary *entry in self.entries) {
		NSString *phone = TGContactString(entry, @"phone");
		if (phone.length && [self.selected containsObject:phone])
			[recipients addObject:[NSString stringWithFormat:@"+%@", phone]];
	}
	if (!recipients.count)
		return;

	Class composerClass = TGCanSendSMS() ? TGMessageComposerClass() : nil;
	if (!composerClass) {
		[self shareFallback];
		return;
	}
	TGMessageComposerShim *composer = [[composerClass alloc] init];
	if (!composer) {
		[self shareFallback];
		return;
	}
	if ([composer respondsToSelector:@selector(setRecipients:)])
		[composer setRecipients:recipients];
	if (self.inviteText.length && [composer respondsToSelector:@selector(setBody:)])
		[composer setBody:self.inviteText];
	if ([composer respondsToSelector:@selector(setMessageComposeDelegate:)])
		[composer setMessageComposeDelegate:self];
	[self presentModalViewController:composer animated:YES];
}

- (void)messageComposeViewController:(id)controller didFinishWithResult:(int)result {
	[self dismissModalViewControllerAnimated:YES];
	[self.navigationController popViewControllerAnimated:YES];
}

@end
