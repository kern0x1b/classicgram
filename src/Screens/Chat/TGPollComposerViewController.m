#import "TGTextFieldStyle.h"
#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGPollComposerViewController.h"
#import "TGLocalization.h"
#import "TGClient.h"
#import "TGClient+Network.h"
#import "TGTheme.h"
#import "TGIcons.h"

static const NSUInteger kTGPollQuestionLengthMax = 255;
static const NSUInteger kTGPollOptionLengthMax = 100;
static const NSUInteger kTGPollExplanationLengthMax = 200;
static const NSUInteger kTGPollOptionCountMin = 2;
static const NSUInteger kTGPollOptionCountFallback = 12;

static const NSInteger kTGPollSectionQuestion = 0;
static const NSInteger kTGPollSectionOptions = 1;
static const NSInteger kTGPollSectionSettings = 2;
static const NSInteger kTGPollSectionExplanation = 3;

static const NSInteger kTGPollSettingAnonymous = 0;
static const NSInteger kTGPollSettingMultiple = 1;
static const NSInteger kTGPollSettingQuiz = 2;

static UIColor *TGPollColour(int rgb, CGFloat alpha) {
	return [UIColor colorWithRed:((rgb >> 16) & 0xff) / 255.0f
						   green:((rgb >> 8) & 0xff) / 255.0f
							blue:(rgb & 0xff) / 255.0f
						   alpha:alpha];
}

static void TGPollApplyMinimumWidth(UIButton *button, CGFloat minimumWidth) {
	if (!button || button.frame.size.width >= minimumWidth)
		return;
	CGRect frame = button.frame;
	frame.size.width = minimumWidth;
	button.frame = frame;
	for (UIView *sub in button.subviews) {
		CGRect subFrame = sub.frame;
		subFrame.origin.x = 0;
		subFrame.size.width = minimumWidth;
		sub.frame = subFrame;
	}
}

@interface TGPollOptionCell : UITableViewCell
@property (nonatomic, strong) UITextField *field;
@property (nonatomic, strong) UIButton *removeButton;
@property (nonatomic, strong) UIButton *correctButton;
@end

@implementation TGPollOptionCell

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier {
	self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:reuseIdentifier];
	if (!self)
		return nil;

	self.removeButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.removeButton.frame = CGRectMake(7, 6, 30, 30);
	self.removeButton.exclusiveTouch = YES;
	self.removeButton.adjustsImageWhenHighlighted = NO;
	self.removeButton.hidden = YES;
	UIImage *plate = [UIImage imageNamed:@"ListEditingSwitch.png"];
	if (plate)
		[self.removeButton setBackgroundImage:plate forState:UIControlStateNormal];
	else
		self.removeButton.backgroundColor = TGPollColour(0xd0021b, 1.0f);
	UIView *minus = [[UIView alloc] initWithFrame:CGRectMake(8, 14, 14, 2)];
	minus.backgroundColor = [UIColor whiteColor];
	minus.userInteractionEnabled = NO;
	[self.removeButton addSubview:minus];
	[self addSubview:self.removeButton];

	self.correctButton = [UIButton buttonWithType:UIButtonTypeCustom];
	self.correctButton.frame = CGRectMake(0, 5, 34, 34);
	self.correctButton.exclusiveTouch = YES;
	self.correctButton.hidden = YES;
	UIImage *check = [UIImage imageNamed:@"ListCheck.png"];
	if (check) {
		[self.correctButton setImage:check forState:UIControlStateNormal];
	} else {
		[self.correctButton setTitle:@"✓" forState:UIControlStateNormal];
		[self.correctButton setTitleColor:TGPollColour(0x1a7ee0, 1.0f)
								 forState:UIControlStateNormal];
	}
	[self.contentView addSubview:self.correctButton];
	return self;
}

- (void)setField:(UITextField *)field {
	if (_field == field)
		return;
	if (_field.superview == self.contentView)
		[_field removeFromSuperview];
	_field = field;
	if (field)
		[self.contentView addSubview:field];
	[self setNeedsLayout];
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGRect bounds = self.contentView.bounds;
	CGFloat rightInset = self.correctButton.hidden ? 12.0f : 44.0f;
	self.field.frame = CGRectMake(11, 11, bounds.size.width - 11 - rightInset, 22);
	self.correctButton.frame = CGRectMake(bounds.size.width - 40, 5, 34, 34);
	self.removeButton.frame = CGRectMake(7, 6, 30, 30);
}

@end

@interface TGPollComposerViewController () <UITextFieldDelegate>
@property (nonatomic, strong) UITextField *questionField;
@property (nonatomic, strong) UITextField *explanationField;
@property (nonatomic, strong) NSMutableArray *optionFields;
@property (nonatomic, strong) UIButton *sendButton;
@property (nonatomic, assign) NSUInteger optionCountMax;
@property (nonatomic, assign) NSInteger correctOption;
@property (nonatomic, assign) BOOL anonymous;
@property (nonatomic, assign) BOOL multipleAnswers;
@property (nonatomic, assign) BOOL quizMode;
@property (nonatomic, assign) BOOL sending;
@property (nonatomic, assign) BOOL didFocusQuestion;
@property (nonatomic, strong) id keyboardWillShowObserverToken;
@property (nonatomic, strong) id keyboardWillHideObserverToken;
@end

@implementation TGPollComposerViewController

- (id)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (!self)
		return nil;
	self.optionFields = [[NSMutableArray alloc] init];
	self.optionCountMax = kTGPollOptionCountFallback;
	self.correctOption = -1;
	self.anonymous = YES;
	return self;
}

- (void)dealloc {
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	if (self.keyboardWillShowObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.keyboardWillShowObserverToken];
	if (self.keyboardWillHideObserverToken)
		[[NSNotificationCenter defaultCenter] removeObserver:self.keyboardWillHideObserverToken];
}

- (void)viewDidLoad {
	[super viewDidLoad];
	self.title = TGL(@"CreatePoll.Title", @"New Poll");
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.tableView.separatorColor = [[TGTheme shared] groupedSeparatorColour];
	self.tableView.rowHeight = 44.0f;
	self.tableView.allowsSelectionDuringEditing = YES;

	UIButton *cancel = [TGIcons headerButtonWithTitle:TGL(@"Common.Cancel", @"Cancel") bold:NO
											   target:self
											   action:@selector(cancelPressed)];
	TGPollApplyMinimumWidth(cancel, 59.0f);
	self.navigationItem.leftBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:cancel];

	self.sendButton = [TGIcons headerButtonWithTitle:TGL(@"MediaPicker.Send", @"Send") bold:YES
											  target:self
											  action:@selector(sendPressed)];
	TGPollApplyMinimumWidth(self.sendButton, 51.0f);
	self.navigationItem.rightBarButtonItem =
		[[UIBarButtonItem alloc] initWithCustomView:self.sendButton];

	self.questionField = [self makeFieldWithPlaceholder:TGL(@"CreatePoll.TextPlaceholder", @"Ask a question") limit:kTGPollQuestionLengthMax];
	self.questionField.clearButtonMode = UITextFieldViewModeWhileEditing;
	self.explanationField = [self makeFieldWithPlaceholder:TGL(@"CreatePoll.Explanation", @"Add a Comment (Optional)") limit:kTGPollExplanationLengthMax];
	self.explanationField.returnKeyType = UIReturnKeyDone;

	while (self.optionFields.count < kTGPollOptionCountMin)
		[self.optionFields addObject:[self makeOptionField]];
	[self refreshOptionPlaceholders];

	__weak typeof(self) weakSelf = self;
	self.keyboardWillShowObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:UIKeyboardWillShowNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf keyboardWillShow:note];
				}];
	self.keyboardWillHideObserverToken = [[NSNotificationCenter defaultCenter]
		addObserverForName:UIKeyboardWillHideNotification
					object:nil
					 queue:nil
				usingBlock:^(NSNotification *note) {
					__strong typeof(weakSelf) strongSelf = weakSelf;
					if (!strongSelf)
						return;
					[strongSelf keyboardWillHide:note];
				}];

	[self.tableView setEditing:YES animated:NO];
	[self updateSendEnabled];
	[self loadOptionCountLimit];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];
	if (self.didFocusQuestion)
		return;
	self.didFocusQuestion = YES;
	[self.questionField becomeFirstResponder];
}

- (void)viewWillDisappear:(BOOL)animated {
	[super viewWillDisappear:animated];
	[self.view endEditing:YES];
}

#pragma mark - limits

- (void)loadOptionCountLimit {
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] optionNamed:@"poll_answer_count_max" completion:^(id value) {
		TGPollComposerViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (![value isKindOfClass:[NSNumber class]])
			return;
		NSInteger limit = [value integerValue];
		if (limit < (NSInteger)kTGPollOptionCountMin)
			return;
		strongSelf.optionCountMax = (NSUInteger)limit;
		[strongSelf appendEmptyOptionIfNeeded];
		[strongSelf refreshOptionPlaceholders];
	}];
}

#pragma mark - fields

- (UITextField *)makeFieldWithPlaceholder:(NSString *)placeholder limit:(NSUInteger)limit {
	UITextField *field = [[UITextField alloc] initWithFrame:CGRectZero];
	field.placeholder = placeholder;
	field.font = TGTextFieldFont();
	field.backgroundColor = [UIColor clearColor];
	field.textColor = [[TGTheme shared] primaryTextColour];
	field.contentMode = UIViewContentModeLeft;
	field.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	field.clearButtonMode = UITextFieldViewModeNever;
	field.returnKeyType = UIReturnKeyNext;
	field.delegate = self;
	field.tag = (NSInteger)limit;
	TGStyleTextField(field);
	[field addTarget:self action:@selector(fieldChanged:)
		forControlEvents:UIControlEventEditingChanged];
	return field;
}

- (UITextField *)makeOptionField {
	return [self makeFieldWithPlaceholder:TGL(@"CreatePoll.OptionPlaceholder", @"Option") limit:kTGPollOptionLengthMax];
}

- (NSString *)trimmed:(NSString *)text {
	if (![text isKindOfClass:[NSString class]] || !text.length)
		return @"";
	return [text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (void)fieldChanged:(UITextField *)field {
	NSInteger index = [self.optionFields indexOfObject:field];
	if (index != NSNotFound) {
		[self refreshRemoveControlForOption:index];
		[self appendEmptyOptionIfNeeded];
		[self refreshOptionPlaceholders];
	}
	[self updateSendEnabled];
}

- (BOOL)canRemoveOptionAtIndex:(NSUInteger)index {
	if (index >= self.optionFields.count)
		return NO;
	UITextField *field = [self.optionFields objectAtIndex:index];
	return field.text.length > 0;
}

- (TGPollOptionCell *)optionCellAtIndex:(NSUInteger)index {
	id cell = [self.tableView cellForRowAtIndexPath:
			[NSIndexPath indexPathForRow:(NSInteger)index inSection:kTGPollSectionOptions]];
	return [cell isKindOfClass:[TGPollOptionCell class]] ? cell : nil;
}

- (void)refreshRemoveControlForOption:(NSUInteger)index {
	TGPollOptionCell *cell = [self optionCellAtIndex:index];
	cell.removeButton.hidden = ![self canRemoveOptionAtIndex:index];
}

- (void)refreshCorrectMarks {
	for (NSInteger i = 0; i < self.optionFields.count; i++) {
		TGPollOptionCell *cell = [self optionCellAtIndex:i];
		if (!cell)
			continue;
		cell.correctButton.hidden = !self.quizMode;
		cell.correctButton.alpha = (self.correctOption == (NSInteger)i) ? 1.0f : 0.22f;
		[cell setNeedsLayout];
	}
}

- (void)refreshOptionPlaceholders {
	for (NSInteger i = 0; i < self.optionFields.count; i++) {
		UITextField *field = [self.optionFields objectAtIndex:i];
		BOOL trailingBlank = (i + 1 == self.optionFields.count) &&
			self.optionFields.count > kTGPollOptionCountMin &&
			!field.text.length;
		field.placeholder = trailingBlank
			? TGL(@"CreatePoll.AddOption", @"Add an Option")
			: [NSString stringWithFormat:@"%@ %lu", TGL(@"CreatePoll.OptionPlaceholder", @"Option"), (unsigned long)(i + 1)];
	}
}

- (void)appendEmptyOptionIfNeeded {
	if (self.optionFields.count >= self.optionCountMax)
		return;
	UITextField *last = [self.optionFields lastObject];
	if (!last.text.length)
		return;
	[self.optionFields addObject:[self makeOptionField]];
	NSIndexPath *path = [NSIndexPath indexPathForRow:(NSInteger)self.optionFields.count - 1
										   inSection:kTGPollSectionOptions];
	[self.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:path]
						  withRowAnimation:UITableViewRowAnimationFade];
}

#pragma mark - actions

- (void)removeOptionPressed:(UIButton *)button {
	UIView *view = button;
	while (view && ![view isKindOfClass:[TGPollOptionCell class]])
		view = view.superview;
	if (!view)
		return;
	NSIndexPath *path = [self.tableView indexPathForCell:(UITableViewCell *)view];
	if (!path)
		return;
	[self tableView:self.tableView commitEditingStyle:UITableViewCellEditingStyleDelete
		 forRowAtIndexPath:path];
}

- (void)correctOptionPressed:(UIButton *)button {
	UIView *view = button;
	while (view && ![view isKindOfClass:[TGPollOptionCell class]])
		view = view.superview;
	if (!view)
		return;
	NSIndexPath *path = [self.tableView indexPathForCell:(UITableViewCell *)view];
	if (!path || path.section != kTGPollSectionOptions)
		return;
	self.correctOption = (self.correctOption == path.row) ? -1 : path.row;
	[self refreshCorrectMarks];
	[self updateSendEnabled];
}

- (void)anonymousToggled:(UISwitch *)toggle {
	self.anonymous = toggle.on;
}

- (void)multipleToggled:(UISwitch *)toggle {
	self.multipleAnswers = toggle.on;
}

- (void)quizToggled:(UISwitch *)toggle {
	[self.view endEditing:YES];
	self.quizMode = toggle.on;
	if (self.quizMode)
		self.multipleAnswers = NO;
	else
		self.correctOption = -1;
	[self.tableView reloadData];
	[self updateSendEnabled];
}

- (void)cancelPressed {
	[self closeSelf];
}

- (void)closeSelf {
	[self.view endEditing:YES];
	if (self.navigationController.viewControllers.count > 1) {
		[self.navigationController popViewControllerAnimated:YES];
		return;
	}
	UIViewController *presenting = self.presentingViewController;
	if (!presenting)
		presenting = self.navigationController.presentingViewController;
	if (presenting)
		[presenting dismissViewControllerAnimated:YES completion:nil];
	else
		[self dismissViewControllerAnimated:YES completion:nil];
}

- (BOOL)isPollValid {
	if (![self trimmed:self.questionField.text].length)
		return NO;
	NSInteger filled = 0;
	BOOL correctIsFilled = NO;
	for (NSInteger i = 0; i < self.optionFields.count; i++) {
		UITextField *field = [self.optionFields objectAtIndex:i];
		if (![self trimmed:field.text].length)
			continue;
		filled++;
		if (self.correctOption == (NSInteger)i)
			correctIsFilled = YES;
	}
	if (filled < kTGPollOptionCountMin)
		return NO;
	if ((NSUInteger)filled > self.optionCountMax)
		return NO;
	if (self.quizMode && !correctIsFilled)
		return NO;
	return YES;
}

- (void)updateSendEnabled {
	BOOL enabled = !self.sending && [self isPollValid];
	self.sendButton.enabled = enabled;
	self.sendButton.alpha = enabled ? 1.0f : 0.5f;
}

- (void)sendPressed {
	if (self.sending || ![self isPollValid])
		return;
	[self.view endEditing:YES];

	NSString *question = [self trimmed:self.questionField.text];
	NSMutableArray *options = [[NSMutableArray alloc] init];
	NSInteger correct = -1;
	for (NSInteger i = 0; i < self.optionFields.count; i++) {
		UITextField *field = [self.optionFields objectAtIndex:i];
		NSString *text = [self trimmed:field.text];
		if (!text.length)
			continue;
		if (self.quizMode && self.correctOption == (NSInteger)i)
			correct = (NSInteger)options.count;
		[options addObject:text];
	}
	if (!question.length || options.count < kTGPollOptionCountMin)
		return;
	if (self.quizMode && correct < 0)
		return;

	NSString *explanation = self.quizMode ? [self trimmed:self.explanationField.text] : @"";
	self.sending = YES;
	[self updateSendEnabled];

	void (^finish)(NSString *, NSArray *, BOOL, BOOL, NSInteger, NSString *, void (^)(BOOL)) = self.onSend;
	if (!finish) {
		[self closeSelf];
		return;
	}

	__weak typeof(self) weakSelf = self;
	finish(question, options, self.anonymous,
		self.quizMode ? NO : self.multipleAnswers, correct, explanation, ^(BOOL success) {
			TGPollComposerViewController *strongSelf = weakSelf;
			if (!strongSelf)
				return;
			if (success) {
				[strongSelf closeSelf];
				return;
			}
			strongSelf.sending = NO;
			[strongSelf updateSendEnabled];
		});
}

#pragma mark - keyboard

- (void)applyKeyboardOverlap:(CGFloat)overlap {
	if (overlap < 0.0f)
		overlap = 0.0f;
	UIEdgeInsets insets = self.tableView.contentInset;
	insets.bottom = overlap;
	self.tableView.contentInset = insets;
	insets = self.tableView.scrollIndicatorInsets;
	insets.bottom = overlap;
	self.tableView.scrollIndicatorInsets = insets;
}

- (void)keyboardWillShow:(NSNotification *)note {
	NSValue *value = [note.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey];
	if (![value isKindOfClass:[NSValue class]])
		return;
	CGRect keyboard = [self.view convertRect:[value CGRectValue] fromView:nil];
	[self applyKeyboardOverlap:CGRectGetMaxY(self.view.bounds) - CGRectGetMinY(keyboard)];
}

- (void)keyboardWillHide:(NSNotification *)note {
	[self applyKeyboardOverlap:0.0f];
}

#pragma mark - text field

- (BOOL)textField:(UITextField *)field
	shouldChangeCharactersInRange:(NSRange)range
				replacementString:(NSString *)string {
	NSInteger limit = field.tag > 0 ? (NSUInteger)field.tag : kTGPollOptionLengthMax;
	NSString *current = field.text ?: @"";
	if (NSMaxRange(range) > current.length)
		return NO;
	NSInteger length = current.length - range.length + string.length;
	return !(length > limit && string.length > 0);
}

- (UITextField *)fieldAfter:(UITextField *)field {
	if (field == self.questionField)
		return self.optionFields.count ? [self.optionFields objectAtIndex:0] : nil;
	NSInteger index = [self.optionFields indexOfObject:field];
	if (index == NSNotFound)
		return nil;
	if (index + 1 < self.optionFields.count)
		return [self.optionFields objectAtIndex:index + 1];
	return self.quizMode ? self.explanationField : nil;
}

- (BOOL)textFieldShouldReturn:(UITextField *)field {
	UITextField *next = [self fieldAfter:field];
	if (next)
		[next becomeFirstResponder];
	else
		[field resignFirstResponder];
	return NO;
}

- (void)textFieldDidEndEditing:(UITextField *)field {
	[self updateSendEnabled];
}

#pragma mark - table

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return self.quizMode ? 4 : 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == kTGPollSectionOptions)
		return (NSInteger)self.optionFields.count;
	if (section == kTGPollSectionSettings)
		return self.quizMode ? 2 : 3;
	return 1;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	if (section == kTGPollSectionQuestion)
		return TGL(@"CreatePoll.TextHeader", @"QUESTION");
	if (section == kTGPollSectionOptions)
		return TGL(@"CreatePoll.OptionsTitle", @"OPTIONS");
	if (section == kTGPollSectionSettings)
		return TGL(@"CreatePoll.SettingsTitle", @"SETTINGS");
	return TGL(@"CreatePoll.ExplanationHeader", @"EXPLANATION");
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderViewWithTitle:title width:tableView.bounds.size.width];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	NSString *title = [self tableView:tableView titleForHeaderInSection:section];
	return [[TGTheme shared] groupedHeaderHeightForTitle:title];
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section == kTGPollSectionOptions) {
		if (self.quizMode)
			return TGL(@"CreatePoll.QuizTip", @"Tap to choose the correct answer");
		if (self.optionFields.count >= self.optionCountMax)
			return TGL(@"CreatePoll.AllOptionsAdded", @"You have added the maximum number of options.");
		NSInteger remaining = self.optionCountMax - self.optionFields.count;
		return TGLPlural(@"CreatePoll.AddMoreOptions", (NSInteger)remaining,
			@"You can add 1 more option.", @"You can add %@ more options.");
	}
	if (section == kTGPollSectionSettings)
		return self.quizMode
			? TGL(@"CreatePoll.QuizInfo", @"Polls in Quiz Mode have one correct answer. Users can't revoke their answers.")
			: TGL(@"CreatePoll.AnonymousFooter", @"An anonymous poll never shows who voted for what.");
	if (section == kTGPollSectionExplanation)
		return TGL(@"CreatePoll.ExplanationInfo", @"Users will see this comment after choosing a wrong answer, good for educational purposes.");
	return nil;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	CGFloat measured = [[TGTheme shared] groupedCommentHeightForText:caption width:tableView.bounds.size.width];
	return TGGroupedFooterHeight(caption, measured);
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
	NSString *caption = [self tableView:tableView titleForFooterInSection:section];
	if (!caption.length)
		return nil;
	return [[TGTheme shared] groupedCommentViewWithText:caption width:tableView.bounds.size.width];
}

- (NSInteger)settingForRow:(NSInteger)row {
	if (row == 0)
		return kTGPollSettingAnonymous;
	if (self.quizMode)
		return kTGPollSettingQuiz;
	return row == 1 ? kTGPollSettingMultiple : kTGPollSettingQuiz;
}

- (UITableViewCell *)switchCellWithTitle:(NSString *)title
									  on:(BOOL)on
								  action:(SEL)action {
	UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:nil];
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.textLabel.text = title;
	UISwitch *toggle = [[UISwitch alloc] initWithFrame:CGRectZero];
	toggle.on = on;
	[toggle addTarget:self action:action forControlEvents:UIControlEventValueChanged];
	cell.accessoryView = toggle;
	cell.editingAccessoryView = toggle;
	return cell;
}

- (UITableViewCell *)plainFieldCellWithField:(UITextField *)field
								   tableView:(UITableView *)tableView {
	TGPollOptionCell *cell = [[TGPollOptionCell alloc] initWithReuseIdentifier:nil];
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.field = field;
	return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
		 cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == kTGPollSectionQuestion)
		return [self plainFieldCellWithField:self.questionField tableView:tableView];

	if (indexPath.section == kTGPollSectionExplanation)
		return [self plainFieldCellWithField:self.explanationField tableView:tableView];

	if (indexPath.section == kTGPollSectionSettings) {
		NSInteger setting = [self settingForRow:indexPath.row];
		if (setting == kTGPollSettingAnonymous)
			return [self switchCellWithTitle:TGL(@"CreatePoll.Anonymous", @"Anonymous Voting")
										  on:self.anonymous
									  action:@selector(anonymousToggled:)];
		if (setting == kTGPollSettingMultiple)
			return [self switchCellWithTitle:TGL(@"CreatePoll.MultiAnswer", @"Multiple Answers")
										  on:self.multipleAnswers
									  action:@selector(multipleToggled:)];
		return [self switchCellWithTitle:TGL(@"CreatePoll.Quiz", @"Quiz Mode")
									  on:self.quizMode
								  action:@selector(quizToggled:)];
	}

	TGPollOptionCell *cell = [[TGPollOptionCell alloc] initWithReuseIdentifier:nil];
	[[TGTheme shared] styleCell:cell];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	NSInteger index = (NSUInteger)indexPath.row;
	if (index < self.optionFields.count)
		cell.field = [self.optionFields objectAtIndex:index];
	cell.removeButton.hidden = ![self canRemoveOptionAtIndex:index];
	[cell.removeButton addTarget:self action:@selector(removeOptionPressed:)
				forControlEvents:UIControlEventTouchUpInside];
	cell.correctButton.hidden = !self.quizMode;
	cell.correctButton.alpha = (self.correctOption == (NSInteger)index) ? 1.0f : 0.22f;
	[cell.correctButton addTarget:self action:@selector(correctOptionPressed:)
				 forControlEvents:UIControlEventTouchUpInside];
	return cell;
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
	return indexPath.section == kTGPollSectionOptions &&
		[self canRemoveOptionAtIndex:(NSUInteger)indexPath.row];
}

- (UITableViewCellEditingStyle)tableView:(UITableView *)tableView
		   editingStyleForRowAtIndexPath:(NSIndexPath *)indexPath {
	return UITableViewCellEditingStyleNone;
}

- (BOOL)tableView:(UITableView *)tableView
	shouldIndentWhileEditingRowAtIndexPath:(NSIndexPath *)indexPath {
	return indexPath.section == kTGPollSectionOptions &&
		[self canRemoveOptionAtIndex:(NSUInteger)indexPath.row];
}

- (void)tableView:(UITableView *)tableView
	commitEditingStyle:(UITableViewCellEditingStyle)editingStyle
	 forRowAtIndexPath:(NSIndexPath *)indexPath {
	if (editingStyle != UITableViewCellEditingStyleDelete ||
		indexPath.section != kTGPollSectionOptions)
		return;
	NSInteger index = (NSUInteger)indexPath.row;
	if (index >= self.optionFields.count)
		return;

	UITextField *field = [self.optionFields objectAtIndex:index];
	field.delegate = nil;
	[field removeFromSuperview];
	[self.optionFields removeObjectAtIndex:index];
	if (self.correctOption == (NSInteger)index)
		self.correctOption = -1;
	else if (self.correctOption > (NSInteger)index)
		self.correctOption -= 1;
	[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
					 withRowAnimation:UITableViewRowAnimationFade];

	NSMutableArray *added = [[NSMutableArray alloc] init];
	while (self.optionFields.count < kTGPollOptionCountMin) {
		[self.optionFields addObject:[self makeOptionField]];
		[added addObject:[NSIndexPath indexPathForRow:(NSInteger)self.optionFields.count - 1
											inSection:kTGPollSectionOptions]];
	}
	if (added.count)
		[tableView insertRowsAtIndexPaths:added withRowAnimation:UITableViewRowAnimationFade];

	[self appendEmptyOptionIfNeeded];
	[self refreshOptionPlaceholders];
	dispatch_async(dispatch_get_main_queue(), ^{
		[tableView reloadData];
	});
	[self updateSendEnabled];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:NO];
	if (indexPath.section == kTGPollSectionQuestion) {
		[self.questionField becomeFirstResponder];
		return;
	}
	if (indexPath.section == kTGPollSectionExplanation) {
		[self.explanationField becomeFirstResponder];
		return;
	}
	if (indexPath.section != kTGPollSectionOptions)
		return;
	NSInteger index = (NSUInteger)indexPath.row;
	if (index < self.optionFields.count)
		[[self.optionFields objectAtIndex:index] becomeFirstResponder];
}

@end
