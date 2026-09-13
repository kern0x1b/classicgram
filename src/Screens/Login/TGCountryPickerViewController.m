#import "TGTextFieldStyle.h"
#import "TGCountryPickerViewController.h"
#import "TGIcons.h"
#import "TGStringTruncation.h"
#import "TGClient+Account.h"
#import "TGLocalization.h"
#import "TGLoginService.h"
#import "TGTheme.h"
#import "TGHexColour.h"

static NSString *TGFlagEmojiForCountryCode(NSString *code) {
	if (code.length != 2)
		return @"🏳️";
	unichar first = [code.uppercaseString characterAtIndex:0];
	unichar second = [code.uppercaseString characterAtIndex:1];
	if (first < 'A' || first > 'Z' || second < 'A' || second > 'Z')
		return @"🏳️";
	UTF32Char regionalFirst = 0x1F1E6 + (first - 'A');
	UTF32Char regionalSecond = 0x1F1E6 + (second - 'A');
	return [NSString stringWithFormat:@"%@%@",
		[[NSString alloc] initWithBytes:&regionalFirst length:4 encoding:NSUTF32LittleEndianStringEncoding],
		[[NSString alloc] initWithBytes:&regionalSecond length:4 encoding:NSUTF32LittleEndianStringEncoding]];
}

static NSComparisonResult TGCountryNameCompare(NSString *a, NSString *b) {
	return [a compare:b options:NSDiacriticInsensitiveSearch | NSWidthInsensitiveSearch | NSForcedOrderingSearch];
}

static NSString *TGCountrySearchFold(NSString *string) {
	NSMutableString *folded = [[NSMutableString alloc] initWithString:string];
	CFStringTransform((__bridge CFMutableStringRef)folded, NULL, kCFStringTransformToLatin, false);
	CFStringTransform((__bridge CFMutableStringRef)folded, NULL, kCFStringTransformStripCombiningMarks, false);
	return folded;
}

static NSArray *TGPhoneCountries(void) {
	static NSArray *list = nil;
	static dispatch_once_t onceToken;
	dispatch_once(&onceToken, ^{
		NSString *path = [[NSBundle mainBundle] pathForResource:@"PhoneCountries" ofType:@"txt"];
		NSString *text = path.length ? [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:NULL] : nil;
		NSArray *lines = [text componentsSeparatedByCharactersInSet:[NSCharacterSet newlineCharacterSet]];
		NSMutableArray *countries = [NSMutableArray arrayWithCapacity:lines.count];
		for (NSString *line in lines) {
			NSArray *parts = [line componentsSeparatedByString:@";"];
			if (parts.count < 3)
				continue;
			NSString *dial = parts[0];
			NSString *iso = [parts[1] uppercaseString];
			NSString *name = parts[2];
			if (!dial.length || !name.length)
				continue;
			[countries addObject:@[ name, TGFlagEmojiForCountryCode(iso), [@"+" stringByAppendingString:dial], iso, name ]];
		}
		list = countries;
	});
	return list;
}

@interface TGCountryPickerRowCell : UITableViewCell

@property (nonatomic, strong) UILabel *countryTitleLabel;
@property (nonatomic, strong) UILabel *countryCodeLabel;
@property (nonatomic, assign) BOOL useIndex;

@end

@implementation TGCountryPickerRowCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	UIColor *background = [UIColor whiteColor];
	UIColor *titleColour = [UIColor blackColor];
	UIColor *codeColour = TGColourFromHex(0x516691);

	_countryTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_countryTitleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_countryTitleLabel.font = [UIFont boldSystemFontOfSize:17];
	_countryTitleLabel.backgroundColor = background;
	_countryTitleLabel.textColor = titleColour;
	_countryTitleLabel.highlightedTextColor = [UIColor whiteColor];
	[self.contentView addSubview:_countryTitleLabel];

	_countryCodeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
	_countryCodeLabel.textAlignment = NSTextAlignmentRight;
	_countryCodeLabel.contentMode = UIViewContentModeRight;
	_countryCodeLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	_countryCodeLabel.font = [UIFont boldSystemFontOfSize:17];
	_countryCodeLabel.backgroundColor = background;
	_countryCodeLabel.textColor = codeColour;
	_countryCodeLabel.highlightedTextColor = [UIColor whiteColor];
	[self.contentView addSubview:_countryCodeLabel];

	return self;
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGFloat contentWidth = self.contentView.frame.size.width;
	CGFloat cellWidth = self.frame.size.width;
	_countryTitleLabel.frame = _useIndex ? CGRectMake(9, 12, contentWidth - 54 - 5, 20)
										 : CGRectMake(9, 12, contentWidth - 54 - 15, 20);
	_countryCodeLabel.frame = _useIndex ? CGRectMake(cellWidth - 49 - 32, 12, 50, 20)
										: CGRectMake(cellWidth - 50 - 9, 12, 50, 20);
}

@end

@interface TGCountryPickerViewController () <UISearchBarDelegate> {
	BOOL _searchFieldStyled;
	BOOL _searchActive;
}
@property (nonatomic, strong) NSArray *countries;
@property (nonatomic, strong) NSArray *filtered;
@property (nonatomic, strong) NSArray *sections;
@property (nonatomic, strong) NSArray *sectionTitles;
@property (nonatomic, strong) UISearchBar *searchBar;
@end

@implementation TGCountryPickerViewController

- (id)init {
	self = [super initWithStyle:UITableViewStylePlain];
	if (!self)
		return nil;
	self.title = TGL(@"Login.SelectCountry.Title", @"Country");
	return self;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return interfaceOrientation == UIInterfaceOrientationPortrait;
}

- (BOOL)shouldAutorotate {
	return NO;
}

- (UIInterfaceOrientationMask)supportedInterfaceOrientations {
	return UIInterfaceOrientationMaskPortrait;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];

	self.tableView.backgroundColor = [[TGTheme shared] listBackgroundColour];
	self.tableView.rowHeight = 44;
	self.tableView.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];

	[self installCancelButton];

	UIView *overscroll = [[UIView alloc] initWithFrame:
			CGRectMake(0, -500, self.tableView.bounds.size.width, 500)];
	overscroll.backgroundColor = TGColourFromHex(0xe4e9f0);
	overscroll.opaque = YES;
	overscroll.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.tableView addSubview:overscroll];

	self.searchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(0, 0, self.view.bounds.size.width, 44)];
	self.searchBar.delegate = self;
	self.searchBar.placeholder = TGL(@"Common.Search", @"Search");
	if ([self.searchBar respondsToSelector:@selector(setBackgroundImage:)]) {
		UIImage *background = [UIImage imageNamed:@"SearchBarBackground.png"];
		if (background)
			[self.searchBar setBackgroundImage:background];
	}
	self.tableView.tableHeaderView = self.searchBar;
	[self hideStripe:self.searchBar];

	self.countries = TGPhoneCountries();
	[self rebuildSections];

	__weak typeof(self) weakSelf = self;
	[[TGClient shared] countriesWithCompletion:^(NSArray *known) {
		NSMutableArray *countries = [NSMutableArray array];
		for (NSDictionary *c in known) {
			if (![c isKindOfClass:NSDictionary.class])
				continue;
			NSString *iso = [c[@"code"] isKindOfClass:NSString.class] ? c[@"code"] : @"";
			if ([iso isEqualToString:@"FT"])
				continue;
			NSString *name = c[@"name"];
			if (![name isKindOfClass:NSString.class] || !name.length) {
				name = iso.length ? [[NSLocale currentLocale] displayNameForKey:NSLocaleCountryCode value:iso] : nil;
				if (!name.length)
					continue;
			}
			NSString *flag = c[@"flag"];
			if (![flag isKindOfClass:NSString.class] || !flag.length)
				flag = TGFlagEmojiForCountryCode(iso);
			NSString *englishName = c[@"englishName"];
			if (![englishName isKindOfClass:NSString.class] || !englishName.length)
				englishName = name;
			NSArray *codes = c[@"callingCodes"];
			if (![codes isKindOfClass:NSArray.class] || !codes.count)
				continue;
			for (id code in codes) {
				if (![code isKindOfClass:NSString.class] || ![(NSString *)code length])
					continue;
				[countries addObject:@[ name, flag, [@"+" stringByAppendingString:code], iso, englishName ]];
			}
		}
		if (countries.count < TGPhoneCountries().count)
			return;
		TGCountryPickerViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.countries = countries;
		[strongSelf rebuildSections];
		if (strongSelf.searchBar.text.length)
			[strongSelf applyQuery:strongSelf.searchBar.text];
		[strongSelf.tableView reloadData];
	}];
}

- (void)installCancelButton {
	UIImage *plate = [[UIImage imageNamed:@"HeaderButton_Login.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0];
	UIImage *pressed = [[UIImage imageNamed:@"HeaderButton_Login_Pressed.png"] stretchableImageWithLeftCapWidth:11 topCapHeight:0];
	if (!plate) {
		self.navigationItem.leftBarButtonItem = [TGIcons headerBarButtonItemWithTitle:TGL(@"Common.Cancel", @"Cancel") bold:NO
									   target:self
									   action:@selector(cancelButtonPressed)];
		return;
	}

	UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
	[button setBackgroundImage:plate forState:UIControlStateNormal];
	if (pressed)
		[button setBackgroundImage:pressed forState:UIControlStateHighlighted];
	[button setTitle:TGL(@"Common.Cancel", @"Cancel") forState:UIControlStateNormal];
	[button setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	button.titleLabel.font = [UIFont boldSystemFontOfSize:12];
	button.titleLabel.shadowOffset = CGSizeMake(0, -1);
	[button setTitleShadowColor:[UIColor colorWithRed:0x07 / 255.0f green:0x08 / 255.0f blue:0x0a / 255.0f alpha:0.35f]
					   forState:UIControlStateNormal];

	CGSize titleSize = [[button titleForState:UIControlStateNormal] sizeWithFont:button.titleLabel.font];
	CGFloat width = MAX(59.0f, ceilf(titleSize.width) + 14.0f);
	button.frame = CGRectMake(0, 0, width, plate.size.height);

	[button addTarget:self action:@selector(cancelButtonPressed) forControlEvents:UIControlEventTouchUpInside];
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:button];
}

- (void)cancelButtonPressed {
	[self.searchBar resignFirstResponder];
	if (self.navigationController && self.navigationController.viewControllers.count > 1)
		[self.navigationController popViewControllerAnimated:YES];
	else
		[self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	if (!_searchFieldStyled) {
		_searchFieldStyled = YES;
		[self.searchBar layoutIfNeeded];
		[self styleSearchInputField:self.searchBar];
		[self applyPlaceholderColour:self.searchBar];
		[self hideStripe:self.searchBar];
	}
}

- (void)applyPlaceholderColour:(UIView *)view {
	if ([view isKindOfClass:[UITextField class]]) {
		TGStyleSearchField((UITextField *)view);
		return;
	}
	for (UIView *child in view.subviews)
		[self applyPlaceholderColour:child];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	if (_searchActive) {
		_searchActive = NO;
		[self.navigationController setNavigationBarHidden:NO animated:animated];
	}
}

- (void)hideStripe:(UIView *)view {
	if ([view isKindOfClass:[UIImageView class]] && view.frame.size.height == 1)
		view.hidden = YES;
	for (UIView *child in view.subviews)
		[self hideStripe:child];
}

- (void)styleSearchInputField:(UIView *)view {
	if ([view isKindOfClass:[UITextField class]]) {
		UITextField *field = (UITextField *)view;
		BOOL retina = [[UIScreen mainScreen] respondsToSelector:@selector(scale)] &&
			[[UIScreen mainScreen] scale] > 1.5f;
		field.borderStyle = UITextBorderStyleNone;
		field.background = nil;
		field.clipsToBounds = NO;

		SEL clearButtonSelector = NSSelectorFromString([[NSString alloc]
			initWithFormat:@"%sBu%s", "clear", "tton"]);
		if ([field respondsToSelector:clearButtonSelector]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
			UIButton *clearButton = [field performSelector:clearButtonSelector];
#pragma clang diagnostic pop
			if ([clearButton isKindOfClass:[UIButton class]]) {
				UIImage *clear = [UIImage imageNamed:@"ClearInput.png"];
				UIImage *clearPressed = [UIImage imageNamed:@"ClearInput_Pressed.png"];
				if (clear)
					[clearButton setImage:clear forState:UIControlStateNormal];
				if (clearPressed)
					[clearButton setImage:clearPressed forState:UIControlStateHighlighted];
				if (retina)
					clearButton.frame = CGRectOffset(clearButton.frame, 0, 0.5f);
			}
		}

		UIImage *inputImage = [UIImage imageNamed:@"SearchInputField.png"];
		if (inputImage) {
			int leftCap = (int)(inputImage.size.width / 2);
			inputImage = [inputImage stretchableImageWithLeftCapWidth:leftCap topCapHeight:0];
			UIImageView *inputImageView = [[UIImageView alloc] initWithFrame:
					CGRectMake(0, retina ? 0.5f : 0.0f, field.frame.size.width, inputImage.size.height)];
			inputImageView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
			inputImageView.image = inputImage;
			[field insertSubview:inputImageView atIndex:0];
		}

		UIImage *icon = [UIImage imageNamed:@"SearchBarIcon.png"];
		UIView *leftView = [field leftView];
		if (icon && [leftView isKindOfClass:[UIImageView class]]) {
			[(UIImageView *)leftView setImage:icon];
			[leftView sizeToFit];
		}
		return;
	}

	for (UIView *child in view.subviews)
		[self styleSearchInputField:child];
}

- (UIView *)sectionIndexView {
	UIView *view = nil;
	@try {
		id value = [self.tableView valueForKey:@"_index"];
		if ([value isKindOfClass:[UIView class]])
			view = value;
	}
	@catch (NSException *exception) {
		view = nil;
	}
	return view;
}

- (void)setSearchActive:(BOOL)active animated:(BOOL)animated {
	if (_searchActive == active)
		return;
	_searchActive = active;

	UIView *indexView = [self sectionIndexView];
	if (indexView) {
		[UIView animateWithDuration:0.15f animations:^{
			indexView.alpha = active ? 0.0f : 1.0f;
		}];
	}

	[self.navigationController setNavigationBarHidden:active animated:animated];
}

- (void)rebuildSections {
	NSMutableArray *titles = [NSMutableArray array];
	NSMutableArray *sections = [NSMutableArray array];
	NSMutableDictionary *index = [NSMutableDictionary dictionary];
	for (NSArray *c in self.countries) {
		NSString *name = c[0];
		if (!name.length)
			continue;
		NSString *title = [TGSafeFirstCharacter(name) uppercaseString];
		NSNumber *slot = index[title];
		if (!slot) {
			slot = @(titles.count);
			index[title] = slot;
			[titles addObject:title];
			[sections addObject:[NSMutableArray array]];
		}
		[sections[slot.unsignedIntegerValue] addObject:c];
	}

	NSArray *order = [titles sortedArrayUsingComparator:^NSComparisonResult(NSString *a, NSString *b) {
		return TGCountryNameCompare(a, b);
	}];
	NSMutableArray *sortedSections = [NSMutableArray arrayWithCapacity:order.count];
	for (NSString *title in order) {
		NSMutableArray *items = sections [[index[title] unsignedIntegerValue]];
		[items sortUsingComparator:^NSComparisonResult(NSArray *a, NSArray *b) {
			NSComparisonResult byName = TGCountryNameCompare(a[0], b[0]);
			return byName != NSOrderedSame ? byName : [a[2] compare:b[2]];
		}];
		[sortedSections addObject:items];
	}

	self.sectionTitles = order;
	self.sections = sortedSections;
}

- (NSArray *)rowsForSection:(NSInteger)section {
	if (self.filtered)
		return self.filtered;
	if (section < 0 || section >= (NSInteger)self.sections.count)
		return @[];
	return self.sections[section];
}

- (NSArray *)rowAtIndexPath:(NSIndexPath *)indexPath {
	NSArray *rows = [self rowsForSection:indexPath.section];
	if (indexPath.row < 0 || indexPath.row >= (NSInteger)rows.count)
		return nil;
	NSArray *row = rows[indexPath.row];
	return row.count >= 3 ? row : nil;
}

- (void)applyQuery:(NSString *)text {
	NSString *string = [text lowercaseString];
	if (!string.length) {
		self.filtered = nil;
		return;
	}

	NSString *transliterated = TGCountrySearchFold(string);

	NSMutableArray *matches = [NSMutableArray array];
	for (NSArray *section in self.sections) {
		for (NSArray *item in section) {
			NSString *name = TGCountrySearchFold([item[0] lowercaseString]);
			NSString *englishName = item.count > 4 ? TGCountrySearchFold([item[4] lowercaseString]) : nil;
			if ([name hasPrefix:string] || [name hasPrefix:transliterated] ||
					(englishName.length && ([englishName hasPrefix:string] || [englishName hasPrefix:transliterated]))) {
				[matches addObject:item];
				continue;
			}
			BOOL matched = NO;
			for (NSString *word in [name componentsSeparatedByString:@" "]) {
				if ([word hasPrefix:string] || [word hasPrefix:transliterated]) {
					[matches addObject:item];
					matched = YES;
					break;
				}
			}
			if (matched || !englishName.length)
				continue;
			for (NSString *word in [englishName componentsSeparatedByString:@" "]) {
				if ([word hasPrefix:string] || [word hasPrefix:transliterated]) {
					[matches addObject:item];
					break;
				}
			}
		}
	}

	if (!matches.count) {
		for (NSArray *section in self.sections) {
			for (NSArray *item in section) {
				NSString *iso = item.count > 3 ? [item[3] lowercaseString] : @"";
				NSString *dial = item.count > 2 ? item[2] : @"";
				if (dial.length > 1)
					dial = [dial substringFromIndex:1];
				if ((iso.length && [iso hasPrefix:string]) || (dial.length && [dial hasPrefix:string]))
					[matches addObject:item];
			}
		}
	}

	self.filtered = matches;
}

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)text {
	[self applyQuery:text];
	[self.tableView reloadData];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
	[searchBar resignFirstResponder];
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)searchBar {
	[searchBar setShowsCancelButton:YES animated:YES];
	[self setSearchActive:YES animated:YES];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)searchBar {
	if (searchBar.text.length)
		return;
	[searchBar setShowsCancelButton:NO animated:YES];
	[self setSearchActive:NO animated:YES];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
	searchBar.text = @"";
	self.filtered = nil;
	[searchBar resignFirstResponder];
	[searchBar setShowsCancelButton:NO animated:YES];
	[self setSearchActive:NO animated:YES];
	[self.tableView reloadData];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	[self.searchBar resignFirstResponder];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return self.filtered ? 1 : (NSInteger)self.sections.count;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	return [self rowsForSection:section].count;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return self.filtered ? 0 : 25;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	if (self.filtered || section < 0 || section >= (NSInteger)self.sectionTitles.count)
		return nil;

	UIView *container = [[UIView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, 25)];
	container.clipsToBounds = NO;
	container.opaque = NO;

	UIImage *background = [UIImage imageNamed:section == 0 ? @"CategoryDividerFirst.png" : @"CategoryDivider.png"];
	if (background) {
		UIImageView *backgroundView = [[UIImageView alloc] initWithFrame:
				CGRectMake(0, -1, tableView.bounds.size.width, 26)];
		backgroundView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		backgroundView.image = background;
		[container addSubview:backgroundView];
	} else {
		container.backgroundColor = [[TGTheme shared] listBackgroundColour];
	}

	UILabel *label = [[UILabel alloc] init];
	label.font = [UIFont boldSystemFontOfSize:15];
	label.backgroundColor = [UIColor clearColor];
	label.numberOfLines = 1;
	label.textColor = [UIColor whiteColor];
	label.shadowColor = TGColourFromHex(0x88929c);
	label.shadowOffset = CGSizeMake(0, -1);
	label.text = self.sectionTitles[section];
	[label sizeToFit];
	label.frame = CGRectOffset(label.frame, 10, 1);
	[container addSubview:label];

	return container;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {
	if (self.filtered)
		return nil;
	NSMutableArray *titles = [NSMutableArray arrayWithObject:UITableViewIndexSearch];
	[titles addObjectsFromArray:self.sectionTitles];
	return titles;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {
	if (index == 0) {
		[tableView scrollRectToVisible:tableView.tableHeaderView.frame animated:NO];
		return -1;
	}
	return index - 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *reuse = @"TGCountryCell";
	TGCountryPickerRowCell *cell = (TGCountryPickerRowCell *)[tableView dequeueReusableCellWithIdentifier:reuse];
	if (!cell)
		cell = [[TGCountryPickerRowCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuse];
	NSArray *c = [self rowAtIndexPath:indexPath];
	cell.useIndex = !self.filtered;
	cell.countryTitleLabel.text = c ? c[0] : @"";
	cell.countryCodeLabel.text = c ? c[2] : @"";
	cell.accessibilityLabel = cell.countryTitleLabel.text;
	cell.accessibilityValue = cell.countryCodeLabel.text;
	cell.accessoryType = UITableViewCellAccessoryNone;
	cell.selectionStyle = UITableViewCellSelectionStyleBlue;
	[cell setNeedsLayout];
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	NSArray *c = [self rowAtIndexPath:indexPath];
	if (!c)
		return;
	[self.searchBar resignFirstResponder];
	if (self.onPick)
		self.onPick(c[0], c[1], c[2]);
	if (self.navigationController)
		[self.navigationController popViewControllerAnimated:YES];
	else
		[self dismissViewControllerAnimated:YES completion:nil];
}

@end
