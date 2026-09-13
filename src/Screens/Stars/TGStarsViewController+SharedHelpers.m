#import "TGStarsViewController.h"
#import "TGStarsViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGClient+Premium.h"
#import "TGClient+Contacts.h"
#import "TGClient+Payments.h"
#import "TGUpgradedGiftInfoViewController.h"
#import "TGForwardPicker.h"
#import "TGAlertView.h"
#import "TGActionSheet.h"
#import "TGTheme.h"
#import "TGIcons.h"
#import <objc/runtime.h>

static const char *TGStarsPromptFieldLengthLimiterKey = "TGStarsPromptFieldLengthLimiterKey";

@interface TGStarsPromptFieldLengthLimiter : NSObject <UITextFieldDelegate>

- (id)initWithMaxLength:(NSInteger)maxLength;

@end

@implementation TGStarsPromptFieldLengthLimiter {
	NSInteger _maxLength;
}

- (id)initWithMaxLength:(NSInteger)maxLength {
	self = [super init];
	if (self != nil)
		_maxLength = maxLength;
	return self;
}

- (BOOL)textField:(UITextField *)field shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
	NSString *current = field.text ?: @"";
	if (range.location > current.length)
		return NO;
	NSString *next = [current stringByReplacingCharactersInRange:range withString:string];
	return next.length <= (NSUInteger)_maxLength;
}

@end

@implementation TGStarsViewController (SharedHelpers)

- (UIView *)sheetHostView {
	if (self.navigationController.view)
		return self.navigationController.view;
	return self.view;
}

- (void)showMessage:(NSString *)message {
	TGAlertView *alert = [TGAlertView alloc];
	alert = [alert initWithTitle:TGL(@"Stars.Intro.Title", @"Telegram Stars")
						 message:message
			   cancelButtonTitle:TGL(@"Common.OK", @"OK")
				   okButtonTitle:nil
				 completionBlock:nil];
	[alert show];
}

- (void)finishSimpleAction:(BOOL)success failure:(NSString *)failureMessage {
	if (!success) {
		[self showMessage:failureMessage];
		return;
	}
	[self.navigationController popToViewController:self animated:YES];
	[self reloadTapped];
}

- (void)proceedIfEnoughStarsForPrice:(long long)price then:(void (^)(void))block {
	if (price <= 0) {
		if (block)
			block();
		return;
	}
	__weak typeof(self) weakSelf = self;
	[[TGClient shared] starBalanceWithCompletion:^(long long balance) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (balance < price) {
			[TGStarsViewController presentNotEnoughStarsAlertFromViewController:strongSelf];
			return;
		}
		if (block)
			block();
	}];
}

- (void)promptWithTitle:(NSString *)title
				message:(NSString *)message
			placeholder:(NSString *)placeholder
				numeric:(BOOL)numeric
			  maxLength:(NSInteger)maxLength
			actionTitle:(NSString *)actionTitle
				handler:(void (^)(NSString *text))handler {
	__block TGAlertView *alert = nil;
	alert = [[TGAlertView alloc] initWithTitle:title
									   message:message
							 cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
								 okButtonTitle:actionTitle
							   completionBlock:^(bool okButtonPressed) {
								   TGAlertView *strongAlert = alert;
								   alert = nil;
								   if (!okButtonPressed || !strongAlert || !handler)
									   return;
								   NSString *text = [[strongAlert textFieldAtIndex:0] text];
								   if (!text.length)
									   return;
								   handler(text);
							   }];
	if ([alert respondsToSelector:@selector(setAlertViewStyle:)])
		alert.alertViewStyle = UIAlertViewStylePlainTextInput;
	UITextField *field = [alert textFieldAtIndex:0];
	if (numeric)
		field.keyboardType = UIKeyboardTypeNumberPad;
	field.placeholder = placeholder;
	if (maxLength > 0) {
		TGStarsPromptFieldLengthLimiter *lengthLimiter = [[TGStarsPromptFieldLengthLimiter alloc] initWithMaxLength:maxLength];
		field.delegate = lengthLimiter;
		objc_setAssociatedObject(field, TGStarsPromptFieldLengthLimiterKey, lengthLimiter, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
	}
	[alert show];
}

- (void)promptForPasswordWithTitle:(NSString *)title
						   message:(NSString *)message
					   actionTitle:(NSString *)actionTitle
						   handler:(void (^)(NSString *password))handler {
	__block TGAlertView *alert = nil;
	alert = [[TGAlertView alloc] initWithTitle:title
									   message:message
							 cancelButtonTitle:TGL(@"Common.Cancel", @"Cancel")
								 okButtonTitle:actionTitle
							   completionBlock:^(bool okButtonPressed) {
								   TGAlertView *strongAlert = alert;
								   alert = nil;
								   if (!okButtonPressed || !strongAlert || !handler)
									   return;
								   NSString *password = [[strongAlert textFieldAtIndex:0] text];
								   if (!password.length)
									   return;
								   handler(password);
							   }];
	if ([alert respondsToSelector:@selector(setAlertViewStyle:)])
		alert.alertViewStyle = UIAlertViewStyleSecureTextInput;
	[alert show];
}

- (NSString *)nameFromUser:(NSDictionary *)user {
	NSMutableString *name = [NSMutableString string];
	NSString *first = user[@"first_name"];
	NSString *last = user[@"last_name"];
	if ([first isKindOfClass:[NSString class]] && first.length)
		[name appendString:first];
	if ([last isKindOfClass:[NSString class]] && last.length) {
		if (name.length)
			[name appendString:@" "];
		[name appendString:last];
	}
	if (name.length)
		return name;
	NSString *username = user[@"username"];
	if ([username isKindOfClass:[NSString class]] && username.length)
		return [NSString stringWithFormat:@"@%@", username];
	return TGL(@"Stars.SharedHelpers.User", @"User");
}

- (void)pickUserWithTitle:(NSString *)title
				  handler:(void (^)(int64_t userId, NSString *name))handler {
	TGStarsListViewController *list =
		[[TGStarsListViewController alloc] initWithTitle:title];
	list.loading = YES;
	list.emptyText = TGL(@"Stars.SharedHelpers.NoContacts", @"No Contacts");
	__weak typeof(self) weakSelf = self;
	__weak TGStarsListViewController *weakList = list;
	[self.navigationController pushViewController:list animated:YES];
	[[TGClient shared] searchContacts:@""
								limit:200
						   completion:^(NSArray *users, BOOL failed) {
							   typeof(self) strongSelf = weakSelf;
							   TGStarsListViewController *strongList = weakList;
							   if (!strongSelf || !strongList)
								   return;
							   if ([users isKindOfClass:[NSArray class]]) {
								   for (NSDictionary *user in users) {
									   if (![user isKindOfClass:[NSDictionary class]])
										   continue;
									   int64_t userId = [user[@"id"] longLongValue];
									   if (!userId)
										   continue;
									   NSString *name = [strongSelf nameFromUser:user];
									   NSString *badge = [TGClient isPremiumUser:user] ? TGL(@"Premium.Premium", @"Premium") : nil;
									   [strongList appendRow:TGStarsBadgeRow(name, badge, nil, ^{
										   typeof(self) innerSelf = weakSelf;
										   if (!innerSelf)
											   return;
										   [innerSelf.navigationController popViewControllerAnimated:YES];
										   if (handler)
											   handler(userId, name);
									   })];
								   }
							   }
							   [strongList finishLoadingWithMore:NO];
						   }];
}

- (void)pickChatWithHandler:(void (^)(int64_t chatId))handler {
	TGForwardPicker *picker = [[TGForwardPicker alloc] init];
	__weak typeof(self) weakSelf = self;
	picker.onPicked = ^(NSArray *chatIds) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		[strongSelf.navigationController popViewControllerAnimated:NO];
		if (handler)
			handler([[chatIds firstObject] longLongValue]);
	};
	[self.navigationController pushViewController:picker animated:YES];
}

@end
