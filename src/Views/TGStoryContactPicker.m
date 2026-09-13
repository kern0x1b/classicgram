#import "TGStoryContactPicker.h"
#import "TGIcons.h"
#import "TGLocalization.h"
#import "TGContactsService.h"
#import "TGTheme.h"
#import "TGStoryHelpers.h"

@implementation TGStoryContactPicker {
	UITableView *_tableView;
	NSArray *_contacts;
	NSMutableSet *_selected;
}

+ (void)presentFrom:(UIViewController *)host
			  title:(NSString *)title
		preselected:(NSArray *)preselected
			 picked:(void (^)(NSArray *userIds))picked {
	if (host == nil)
		return;
	TGStoryContactPicker *picker = [[TGStoryContactPicker alloc] init];
	picker.title = title.length > 0 ? title : TGL(@"Story.Privacy.CategorySelectedContacts", @"Selected Contacts");
	picker.preselected = preselected;
	picker.onPicked = picked;
	UINavigationController *navigation =
		[[UINavigationController alloc] initWithRootViewController:picker];
	[host presentViewController:navigation animated:YES completion:nil];
}

- (void)viewDidLoad {
	[super viewDidLoad];

	_selected = [[NSMutableSet alloc] init];
	for (id value in self.preselected) {
		if ([value respondsToSelector:@selector(longLongValue)])
			[_selected addObject:[NSNumber numberWithLongLong:[value longLongValue]]];
	}

	self.navigationItem.leftBarButtonItem =
		[TGIcons headerBarButtonItemWithTitle:TGL(@"Common.Cancel", @"Cancel") bold:NO
									   target:self
									   action:@selector(cancelPressed)];
	self.navigationItem.rightBarButtonItem =
		[TGIcons headerBarButtonItemWithTitle:TGL(@"Common.Done", @"Done") bold:YES
									   target:self
									   action:@selector(donePressed)];

	_tableView = [[UITableView alloc] initWithFrame:self.view.bounds style:UITableViewStylePlain];
	_tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_tableView.dataSource = self;
	_tableView.delegate = self;
	_tableView.rowHeight = 44.0f;
	_tableView.separatorColor = [[TGTheme shared] separatorColour];
	_tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	[self.view addSubview:_tableView];

	__weak TGStoryContactPicker *weakSelf = self;
	[TGContactsService contactsWithCompletion:^(NSArray *users) {
		TGStoryContactPicker *strongSelf = weakSelf;
		if (strongSelf == nil)
			return;
		strongSelf->_contacts = [users isKindOfClass:[NSArray class]] ? [users copy] : nil;
		[strongSelf->_tableView reloadData];
	}];
}

- (void)cancelPressed {
	void (^picked)(NSArray *) = self.onPicked;
	self.onPicked = nil;
	[self dismissViewControllerAnimated:YES completion:^{
		if (picked != nil)
			picked(nil);
	}];
}

- (void)donePressed {
	void (^picked)(NSArray *) = self.onPicked;
	self.onPicked = nil;
	NSArray *ids = [_selected allObjects];
	[self dismissViewControllerAnimated:YES completion:^{
		if (picked != nil)
			picked(ids);
	}];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	(void)tableView;
	(void)section;
	return (NSInteger)_contacts.count;
}

- (NSString *)nameForContact:(NSDictionary *)contact {
	NSString *first = TGStoryString(contact, @"first_name");
	NSString *last = TGStoryString(contact, @"last_name");
	if (first.length > 0 && last.length > 0)
		return [NSString stringWithFormat:@"%@ %@", first, last];
	if (first.length > 0)
		return first;
	if (last.length > 0)
		return last;
	NSString *username = TGStoryString(contact, @"username");
	return username.length > 0 ? username : TGL(@"Attachment.Contact", @"Contact");
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"contact"];
	if (cell == nil)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:@"contact"];
	NSDictionary *contact = [_contacts objectAtIndex:(NSUInteger)indexPath.row];
	cell.textLabel.text = [self nameForContact:contact];
	NSNumber *identifier = [NSNumber numberWithLongLong:TGStoryChatId(contact, @"id")];
	cell.accessoryType = [_selected containsObject:identifier]
		? UITableViewCellAccessoryCheckmark
		: UITableViewCellAccessoryNone;
	[[TGTheme shared] styleCell:cell];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.row >= (NSInteger)_contacts.count)
		return;
	NSDictionary *contact = [_contacts objectAtIndex:(NSUInteger)indexPath.row];
	NSNumber *identifier = [NSNumber numberWithLongLong:TGStoryChatId(contact, @"id")];
	if ([_selected containsObject:identifier])
		[_selected removeObject:identifier];
	else
		[_selected addObject:identifier];
	[tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
					 withRowAnimation:UITableViewRowAnimationNone];
}

@end
