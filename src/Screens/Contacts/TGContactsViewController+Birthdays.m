#import "TGContactsViewController.h"
#import "TGContactsViewControllerInternal.h"
#import "TGFlatActionCell.h"
#import "TGContactRowCell.h"
#import "TGInviteFriendsViewController.h"
#import "TGContactsService.h"
#import "TGIcons.h"
#import "TGTheme.h"
#import "TGLocalization.h"
#import "TGImageDecode.h"
#import "TGNewContactViewController.h"
#import "RootViewController.h"
#import "UIView+SafeTint.h"
#import "TGEmoji.h"
#import <QuartzCore/QuartzCore.h>
#import <AddressBook/AddressBook.h>
#import <dlfcn.h>
#import "TGAlertView.h"
#import "TGActionSheet.h"
#import "TGFlattenContacts.h"
#import "TGSnackbar.h"

@implementation TGContactsViewController (Birthdays)

- (NSString *)birthdayTextFrom:(NSDictionary *)birthdate {
	NSString *text = birthdate[@"text"];
	if (![text isKindOfClass:NSString.class] || !text.length)
		return nil;
	return [self isBirthdayToday:birthdate]
		? [NSString stringWithFormat:TGL(@"Contacts.BirthdayToday", @"%@ (today)"), text]
		: text;
}

- (BOOL)isBirthdayToday:(NSDictionary *)birthdate {
	return TGBirthdateIsToday(birthdate);
}

- (void)showBirthdayPickerForUser:(NSDictionary *)u {
	self.birthdayUser = u;
	[self showBirthdayPickerWithDoneTitle:TGL(@"UserInfo.SuggestPhoto.AlertSuggest", @"Suggest")
								   action:@selector(sendBirthdaySuggestion)
							  initialDate:nil];
}

- (void)showBirthdayPickerWithDoneTitle:(NSString *)doneTitle
								 action:(SEL)action
							initialDate:(NSDate *)initialDate {
	UIActionSheet *sheet = [[UIActionSheet alloc]
				 initWithTitle:nil
					  delegate:self
			 cancelButtonTitle:nil
		destructiveButtonTitle:nil
			 otherButtonTitles:nil];
	sheet.actionSheetStyle = UIActionSheetStyleBlackTranslucent;
	sheet.tag = 6;

	CGFloat sheetWidth = self.navigationController.view.bounds.size.width;
	if (sheetWidth < 1.0f)
		sheetWidth = self.view.bounds.size.width;
	if (sheetWidth < 1.0f)
		sheetWidth = TGContactsScreenWidth();
	UIToolbar *bar = [[UIToolbar alloc] initWithFrame:CGRectMake(0, 0, sheetWidth, 44)];
	bar.barStyle = UIBarStyleBlackTranslucent;
	UIBarButtonItem *cancel = [[UIBarButtonItem alloc]
		initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
							 target:self
							 action:@selector(dismissBirthdaySheet)];
	UIBarButtonItem *space = [[UIBarButtonItem alloc]
		initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
							 target:nil
							 action:nil];
	UIBarButtonItem *done = [[UIBarButtonItem alloc]
		initWithTitle:doneTitle
				style:UIBarButtonItemStyleDone
			   target:self
			   action:action];
	bar.items = @[ cancel, space, done ];
	[sheet addSubview:bar];

	UIDatePicker *picker = [[UIDatePicker alloc] initWithFrame:
			CGRectMake(0, 44, sheetWidth, 216)];
	picker.datePickerMode = UIDatePickerModeDate;
	picker.maximumDate = [NSDate date];
	if (initialDate)
		picker.date = initialDate;
	[sheet addSubview:picker];
	self.birthdayPicker = picker;
	self.birthdaySheet = sheet;

	UIView *presentationHost = self.navigationController.view;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(presentationHost.bounds), CGRectGetMidY(presentationHost.bounds), 1, 1)
					 inView:presentationHost];
	[sheet setBounds:CGRectMake(0, 0, sheetWidth, 320)];
}

- (void)dismissBirthdaySheet {
	[self.birthdaySheet dismissWithClickedButtonIndex:-1 animated:YES];
	self.birthdaySheet = nil;
	self.birthdayPicker = nil;
	self.birthdayUser = nil;
}

- (void)sendBirthdaySuggestion {
	NSDictionary *u = self.birthdayUser;
	NSDate *date = self.birthdayPicker.date;
	[self.birthdaySheet dismissWithClickedButtonIndex:-1 animated:YES];
	self.birthdaySheet = nil;
	self.birthdayPicker = nil;
	self.birthdayUser = nil;
	if (!u || !date)
		return;
	NSDateComponents *parts = [[NSCalendar currentCalendar]
		components:(NSDayCalendarUnit | NSMonthCalendarUnit | NSYearCalendarUnit)
		  fromDate:date];
	__weak typeof(self) weakSelf = self;
	[TGContactsService suggestBirthdateToUser:[u[@"id"] longLongValue]
										  day:parts.day
										month:parts.month
										 year:parts.year
								   completion:^(BOOL ok) {
									   TGContactsViewController *strongSelf = weakSelf;
									   if (!strongSelf)
										   return;
									   [TGSnackbar showInView:strongSelf.view
														  text:(ok
															  ? TGL(@"Contacts.BirthdaySuggested", @"Birthday suggested.")
															  : TGL(@"Contacts.CouldNotSuggestBirthday", @"Could not suggest a birthday."))
													   seconds:2
													  onCommit:nil];
								   }];
}

@end
