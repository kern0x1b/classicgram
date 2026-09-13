#import "TGClient+Contacts.h"
#import "TGPrivacyViewController.h"
#import "TGPrivacyViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGClient.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import "TGSessionsViewController.h"
#import "TGPasscodeLock.h"
#import "TGSecurityStepViewController.h"

#import "TGPrivacyContactPickerViewController.h"
#import "TGPrivacyContactPickerPresenter.h"
#import "TGPrivacyContactPickerRowBridge.h"

@interface TGPrivacyContactPickerViewController ()
@property (nonatomic, strong) NSArray *contacts;
@property (nonatomic, strong) NSMutableArray *chosen;
@property (nonatomic, copy) TGPrivacyPickerBlock completion;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, strong) TGPrivacyContactPickerPresenter *rowPresenter;
@property (nonatomic, strong) TGPrivacyContactPickerRowBridge *rowBridge;
@end

@implementation TGPrivacyContactPickerViewController

- (instancetype)initWithTitle:(NSString *)title
					 selected:(NSArray *)selected
				   completion:(TGPrivacyPickerBlock)completion {
	self = [super initWithStyle:UITableViewStylePlain];
	if (self) {
		self.title = title;
		_chosen = selected ? [selected mutableCopy] : [NSMutableArray array];
		_completion = [completion copy];
		self.rowPresenter = [[TGPrivacyContactPickerPresenter alloc] init];
		self.rowBridge = [[TGPrivacyContactPickerRowBridge alloc] initWithPresenter:self.rowPresenter];
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.tableView.rowHeight = 44;

	UIButton *button = [TGIcons headerButtonWithTitle:TGL(@"Common.Done", @"Done") bold:YES
											   target:self
											   action:@selector(done)];
	self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:button];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] contactsWithCompletion:^(NSArray *users) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.loaded = YES;
		strongSelf.contacts = [users isKindOfClass:[NSArray class]] ? users : nil;
		[strongSelf.rowPresenter updateWithContacts:strongSelf.contacts chosen:strongSelf.chosen];
		[strongSelf.tableView reloadData];
	}];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)done {
	TGPrivacyPickerBlock completion = self.completion;
	self.completion = nil;
	if (completion)
		completion([NSArray arrayWithArray:self.chosen]);
	[self.navigationController popViewControllerAnimated:YES];
}

- (NSString *)nameOf:(NSDictionary *)user {
	NSMutableString *name = [NSMutableString string];
	id first = user[@"first_name"];
	id last = user[@"last_name"];
	if ([first isKindOfClass:[NSString class]])
		[name appendString:first];
	if ([last isKindOfClass:[NSString class]] && [last length]) {
		if (name.length)
			[name appendString:@" "];
		[name appendString:last];
	}
	if (!name.length) {
		id username = user[@"username"];
		if ([username isKindOfClass:[NSString class]] && [username length])
			return username;
		return TGL(@"Contacts.UnknownName", @"Unknown");
	}
	return name;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.contacts.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if ([self.rowBridge ownsRowAtIndex:indexPath.row])
		return [self.rowBridge cellForRow:indexPath.row inTable:tableView];

	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"contact"];
	if (!cell)
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault
									  reuseIdentifier:@"contact"];
	[[TGTheme shared] styleCell:cell];
	NSDictionary *user = self.contacts[indexPath.row];
	cell.textLabel.text = [self nameOf:user];
	cell.textLabel.font = [UIFont boldSystemFontOfSize:17];
	id userId = user[@"id"];
	BOOL chosen = [self.chosen containsObject:userId];
	cell.textLabel.textColor = chosen ? [[TGTheme shared] groupedInfoColour]
									  : [[TGTheme shared] groupedTitleColour];
	cell.accessoryType = chosen
		? UITableViewCellAccessoryCheckmark
		: UITableViewCellAccessoryNone;
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if ((NSUInteger)indexPath.row >= self.contacts.count)
		return;
	id userId = self.contacts[indexPath.row][@"id"];
	if (![userId isKindOfClass:[NSNumber class]])
		return;
	if ([self.chosen containsObject:userId])
		[self.chosen removeObject:userId];
	else
		[self.chosen addObject:userId];
	[self.rowPresenter updateWithContacts:self.contacts chosen:self.chosen];
	[tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
					 withRowAnimation:UITableViewRowAnimationNone];
}

@end
