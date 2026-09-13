#import "TGListBackground.h"
#import "TGNewContactViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGIcons.h"

@interface TGPhoneLabelCell : UITableViewCell
@property (nonatomic, strong) UILabel *titleView;
@property (nonatomic, strong) UIImageView *checkIndicator;
- (void)setHideCheckIndicator:(BOOL)hide;
@end

@implementation TGPhoneLabelCell

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;
	self.titleView = [[UILabel alloc] initWithFrame:CGRectMake(11, 12, self.contentView.bounds.size.width - 30, 20)];
	self.titleView.contentMode = UIViewContentModeLeft;
	self.titleView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.titleView.font = [UIFont boldSystemFontOfSize:17];
	self.titleView.backgroundColor = [UIColor clearColor];
	self.titleView.textColor = [UIColor blackColor];
	self.titleView.highlightedTextColor = [UIColor whiteColor];
	[self.contentView addSubview:self.titleView];
	return self;
}

- (void)setHideCheckIndicator:(BOOL)hide {
	if (hide) {
		self.checkIndicator.hidden = YES;
		self.titleView.textColor = [UIColor blackColor];
		return;
	}
	if (!self.checkIndicator) {
		UIImage *check = [UIImage imageNamed:@"ListCheck.png"];
		if (check) {
			UIImage *checkOn = [UIImage imageNamed:@"ListCheck_Highlighted.png"];
			self.checkIndicator = [[UIImageView alloc] initWithImage:check highlightedImage:checkOn];
			self.checkIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
			self.checkIndicator.frame = CGRectMake(self.contentView.bounds.size.width - check.size.width - 9, 14,
				check.size.width, check.size.height);
			[self.contentView addSubview:self.checkIndicator];
		}
	} else {
		self.checkIndicator.hidden = NO;
	}
	self.titleView.textColor = TGNewContactColour(0x516691, 1.0f);
	if (!self.checkIndicator)
		self.accessoryType = UITableViewCellAccessoryCheckmark;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	self.titleView.frame = CGRectMake(11, 12, self.contentView.bounds.size.width - 30, 20);
	if (self.checkIndicator) {
		CGSize size = self.checkIndicator.image.size;
		self.checkIndicator.frame = CGRectMake(self.contentView.bounds.size.width - size.width - 9, 14,
			size.width, size.height);
	}
}

@end

@implementation TGPhoneLabelPickerController

- (id)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (!self)
		return nil;
	self.title = TGL(@"PhoneLabel.Title", @"Label");
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.rowHeight = 44.0f;

	UIButton *cancel = [TGIcons headerButtonWithTitle:TGL(@"Common.Cancel", @"Cancel") bold:NO
											   target:self
											   action:@selector(cancelPressed)];
	TGNewContactApplyMinimumWidth(cancel, 59.0f);
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:cancel];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	NSInteger index = self.selectedLabel ? [self.labels indexOfObject:self.selectedLabel] : NSNotFound;
	if (index != NSNotFound) {
		[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:(NSInteger)index inSection:0]
							  atScrollPosition:UITableViewScrollPositionNone
									  animated:NO];
	}
}

- (void)cancelPressed {
	if (self.onCancel)
		self.onCancel();
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return (NSInteger)self.labels.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *reuse = @"TGPhoneLabelRow";
	TGPhoneLabelCell *cell = [tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[TGPhoneLabelCell alloc] initWithReuseIdentifier:reuse];
	NSString *label = [self.labels objectAtIndex:(NSUInteger)indexPath.row];
	cell.titleView.text = label;
	cell.accessoryType = UITableViewCellAccessoryNone;
	[cell setHideCheckIndicator:![label isEqualToString:self.selectedLabel]];
	cell.backgroundColor = [UIColor clearColor];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSString *label = [self.labels objectAtIndex:(NSUInteger)indexPath.row];
	if (self.onPick)
		self.onPick(label);
}

@end

@implementation TGNewContactPhoneCell

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.labelView = [[UILabel alloc] initWithFrame:CGRectMake(4, 13, 62, 16)];
	self.labelView.textAlignment = NSTextAlignmentRight;
	self.labelView.font = [UIFont boldSystemFontOfSize:13];
	self.labelView.backgroundColor = [UIColor whiteColor];
	self.labelView.textColor = TGNewContactColour(0x5d708f, 1.0f);
	self.labelView.highlightedTextColor = [UIColor whiteColor];
	[self.contentView addSubview:self.labelView];

	UIImage *line = [UIImage imageNamed:@"GroupedCellVerticalSeparator.png"];
	if (line) {
		UIImage *lineOn = [UIImage imageNamed:@"GroupedCellVerticalSeparator_Highlighted.png"];
		self.verticalSeparator = [[UIImageView alloc] initWithImage:line highlightedImage:lineOn];
	} else {
		self.verticalSeparator = [[UIImageView alloc] initWithFrame:CGRectZero];
		self.verticalSeparator.backgroundColor = [[TGTheme shared] separatorColour];
	}
	[self.contentView addSubview:self.verticalSeparator];

	self.removeButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.removeButton.frame = CGRectMake(7, 6, 30, 30);
	self.removeButton.exclusiveTouch = YES;
	self.removeButton.adjustsImageWhenHighlighted = NO;
	self.removeButton.hidden = YES;
	UIImage *switchImage = [UIImage imageNamed:@"ListEditingSwitch.png"];
	if (switchImage)
		[self.removeButton setBackgroundImage:switchImage forState:UIControlStateNormal];
	UIView *minus = [[UIView alloc] initWithFrame:CGRectMake(8, 14, 14, 2)];
	minus.backgroundColor = [UIColor whiteColor];
	minus.userInteractionEnabled = NO;
	[self.removeButton addSubview:minus];
	[self addSubview:self.removeButton];
	return self;
}

- (void)setShowsRemoveControl:(BOOL)shows {
	self.removeButton.hidden = !shows;
}

- (void)setField:(UITextField *)field {
	if (_field == field)
		return;
	if (_field.superview == self.contentView)
		[_field removeFromSuperview];
	_field = field;
	if (field)
		[self.contentView addSubview:field];
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGRect bounds = self.contentView.bounds;
	self.labelView.frame = CGRectMake(4, 13, 62, 16);
	CGFloat lineHeight = bounds.size.height - (self.lastInGroup ? 1.0f : 0.0f);
	self.verticalSeparator.frame = CGRectMake(72, 0, 1.0f, lineHeight);
	self.field.font = [UIFont boldSystemFontOfSize:15];
	self.field.frame = CGRectMake(78, 11, bounds.size.width - 80, 20);
	self.staticValueLabel.frame = CGRectMake(78, 11, bounds.size.width - 80, 20);
	self.removeButton.frame = CGRectMake(7, 6, 30, 30);
}

@end
