#import "TGNewContactViewControllerInternal.h"
#import "TGLocalization.h"
#import "TGContactsService.h"
#import "TGQRViewController.h"
#import "TGActionSheet.h"
#import "TGActionSheetIndexBuilder.h"
#import <AddressBook/AddressBook.h>

@implementation TGNewContactViewController (Actions)

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

- (void)cancelTapped {
	[self closeSelf];
}

- (void)doneTapped {
	if (self.saving || ![self isFormValid])
		return;

	NSString *first = [self trimmed:self.firstNameField.text];
	NSString *last = [self trimmed:self.lastNameField.text];
	NSArray *phones = [self enteredPhones];
	NSString *primaryPhone = phones.count
		? [[phones objectAtIndex:0] objectForKey:@"phone"]
		: (self.prefillPhone ?: @"");

	self.saving = YES;
	[self updateDoneEnabled];
	[self.view endEditing:YES];

	if ([self writesAddressBookRecord])
		[self saveToAddressBookFirst:first last:last phones:phones];
	else if ([self updatesAddressBookRecord])
		[self updateAddressBookRecordFirst:first last:last phone:primaryPhone];

	void (^report)(BOOL, int64_t) = self.onDone;
	BOOL share = self.sharePhoneNumber;

	if (self.resolvedUserId) {
		int64_t userId = self.resolvedUserId;
		[TGContactsService addContactWithUserId:userId
										  phone:primaryPhone
									  firstName:first
									   lastName:last
							   sharePhoneNumber:share
									 completion:^(BOOL ok) {
										 if (report)
											 report(ok, ok ? userId : 0);
									 }];
	} else {
		[TGContactsService importContactWithPhone:primaryPhone
										firstName:first
										 lastName:last
									   completion:^(BOOL ok, int64_t userId) {
										   if (report)
											   report(ok, userId);
									   }];
	}

	[self closeSelf];
}

- (void)saveToAddressBookFirst:(NSString *)first last:(NSString *)last phones:(NSArray *)phones {
	ABAddressBookRef book = ABAddressBookCreateWithOptions(NULL, NULL);
	if (!book)
		return;
	UIImage *photo = self.avatarImage;
	ABAddressBookRequestAccessWithCompletion(book, ^(bool granted, CFErrorRef error) {
		if (!granted) {
			CFRelease(book);
			return;
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			ABRecordRef person = ABPersonCreate();
			if (first.length)
				ABRecordSetValue(person, kABPersonFirstNameProperty, (__bridge CFStringRef)first, NULL);
			if (last.length)
				ABRecordSetValue(person, kABPersonLastNameProperty, (__bridge CFStringRef)last, NULL);

			ABMutableMultiValueRef phoneValues = ABMultiValueCreateMutable(kABMultiStringPropertyType);
			for (NSDictionary *item in phones) {
				ABMultiValueAddValueAndLabel(phoneValues,
					(__bridge CFStringRef)[item objectForKey:@"phone"],
					(__bridge CFStringRef)[item objectForKey:@"abLabel"], NULL);
			}
			ABRecordSetValue(person, kABPersonPhoneProperty, phoneValues, NULL);
			CFRelease(phoneValues);

			if (photo) {
				NSData *data = UIImageJPEGRepresentation(photo, 0.9f);
				if (data)
					ABPersonSetImageData(person, (__bridge CFDataRef)data, NULL);
			}

			ABAddressBookAddRecord(book, person, NULL);
			ABAddressBookSave(book, NULL);
			CFRelease(person);
			CFRelease(book);
		});
	});
}

- (void)updateAddressBookRecordFirst:(NSString *)first last:(NSString *)last phone:(NSString *)phone {
	NSString *targetDigits = [self digitsOf:phone];
	if (!targetDigits.length)
		return;
	ABAddressBookRef book = ABAddressBookCreateWithOptions(NULL, NULL);
	if (!book)
		return;
	ABAddressBookRequestAccessWithCompletion(book, ^(bool granted, CFErrorRef error) {
		if (!granted) {
			CFRelease(book);
			return;
		}
		dispatch_async(dispatch_get_main_queue(), ^{
			ABRecordRef matchedPerson = NULL;
			CFArrayRef people = ABAddressBookCopyArrayOfAllPeople(book);
			if (people) {
				CFIndex count = CFArrayGetCount(people);
				for (CFIndex i = 0; i < count && !matchedPerson; i++) {
					ABRecordRef person = CFArrayGetValueAtIndex(people, i);
					ABMultiValueRef phoneValues = ABRecordCopyValue(person, kABPersonPhoneProperty);
					if (!phoneValues)
						continue;
					CFIndex phoneCount = ABMultiValueGetCount(phoneValues);
					for (CFIndex j = 0; j < phoneCount; j++) {
						NSString *raw = (__bridge_transfer NSString *)
							ABMultiValueCopyValueAtIndex(phoneValues, j);
						if ([[self digitsOf:(raw ?: @"")] isEqualToString:targetDigits]) {
							matchedPerson = person;
							break;
						}
					}
					CFRelease(phoneValues);
				}
			}
			if (matchedPerson) {
				if (first.length)
					ABRecordSetValue(matchedPerson, kABPersonFirstNameProperty, (__bridge CFStringRef)first, NULL);
				if (last.length)
					ABRecordSetValue(matchedPerson, kABPersonLastNameProperty, (__bridge CFStringRef)last, NULL);
				ABAddressBookSave(book, NULL);
			}
			if (people)
				CFRelease(people);
			CFRelease(book);
		});
	});
}

- (void)addPhotoPressed {
	[self.view endEditing:YES];
	NSMutableArray *actions = [NSMutableArray array];
	NSMutableArray *titles = [NSMutableArray array];
	if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypeCamera]) {
		[titles addObject:TGL(@"Common.TakePhoto", @"Take Photo")];
		[actions addObject:@"camera"];
	}
	if ([UIImagePickerController isSourceTypeAvailable:UIImagePickerControllerSourceTypePhotoLibrary]) {
		[titles addObject:TGL(@"Media.ChooseFromGallery", @"Choose from Library")];
		[actions addObject:@"library"];
	}
	if (!actions.count) {
		[[[UIAlertView alloc] initWithTitle:TGL(@"NewContact.Title", @"New Contact")
									message:TGL(@"Settings.ThereIsNoCameraAndNo", @"There is no camera and no photo library on this device.")
								   delegate:nil
						  cancelButtonTitle:TGL(@"Common.OK", @"OK")
						  otherButtonTitles:nil] show];
		return;
	}
	NSInteger cancelIndex;
	UIActionSheet *sheet = [TGActionSheetIndexBuilder
				sheetWithTitle:nil
					  delegate:self
				   otherTitles:titles
			  destructiveIndex:-1
				   cancelTitle:TGL(@"Common.Cancel", @"Cancel")
		destructiveButtonIndex:NULL
			 cancelButtonIndex:&cancelIndex];
	sheet.tag = 240;
	self.photoSheetActions = actions;
	[sheet tg_showFromRect:CGRectMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds), 1, 1) inView:self.view];
}

- (void)actionSheet:(UIActionSheet *)sheet clickedButtonAtIndex:(NSInteger)index {
	if (sheet.tag != 240 || index == sheet.cancelButtonIndex)
		return;
	if ((NSUInteger)index >= self.photoSheetActions.count)
		return;
	[self presentPhotoPickerFromSource:
			[self.photoSheetActions[index] isEqualToString:@"camera"]
			? UIImagePickerControllerSourceTypeCamera
			: UIImagePickerControllerSourceTypePhotoLibrary];
}

- (void)presentPhotoPickerFromSource:(UIImagePickerControllerSourceType)source {
	UIImagePickerController *picker = [[UIImagePickerController alloc] init];
	picker.sourceType = source;
	picker.delegate = self;
	picker.allowsEditing = YES;
	[self presentViewController:picker animated:YES completion:nil];
}

- (void)imagePickerController:(UIImagePickerController *)picker didFinishPickingMediaWithInfo:(NSDictionary *)info {
	UIImage *image = [info objectForKey:UIImagePickerControllerEditedImage];
	if (!image)
		image = [info objectForKey:UIImagePickerControllerOriginalImage];
	if (image) {
		self.avatarImage = image;
		self.avatarView.image = image;
		self.avatarView.hidden = NO;
	}
	[picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)imagePickerControllerDidCancel:(UIImagePickerController *)picker {
	[picker dismissViewControllerAnimated:YES completion:nil];
}

- (void)qrTapped {
	[self.view endEditing:YES];
	TGQRViewController *scanner = [[TGQRViewController alloc] init];
	__weak typeof(self) weakSelf = self;
	__weak typeof(scanner) weakScanner = scanner;
	scanner.onCode = ^BOOL(NSString *payload) {
		TGNewContactViewController *strongSelf = weakSelf;
		if (!strongSelf)
			return YES;
		[TGContactsService resolveContactQRCode:payload completion:^(NSDictionary *user, BOOL recognizedCode) {
			TGNewContactViewController *innerSelf = weakSelf;
			int64_t userId = [user[@"id"] longLongValue];
			if (!innerSelf)
				return;
			if (!userId) {
				NSString *codeMessage = recognizedCode
					? TGL(@"AuthSessions.AddDevice.InvalidQRCode", @"That QR code could not be used. It may have expired.")
					: TGL(@"Contacts.QrCode.NoCodeFound", @"No valid QR code found in the image. Please try again.");
				[[[UIAlertView alloc] initWithTitle:TGL(@"PeerInfo.QRCode.Title", @"QR Code")
											message:codeMessage
										   delegate:nil
								  cancelButtonTitle:TGL(@"Common.OK", @"OK")
								  otherButtonTitles:nil] show];
				TGQRViewController *stillScanning = weakScanner;
				[stillScanning resumeScanning];
				return;
			}
			TGNewContactViewController *form = [[TGNewContactViewController alloc] init];
			form.peerUserId = userId;
			form.prefillFirstName = user[@"first_name"] ?: @"";
			form.prefillLastName = user[@"last_name"] ?: @"";
			form.prefillPhone = user[@"phone"] ?: @"";
			form.onDone = innerSelf.onDone;
			NSMutableArray *stack = [innerSelf.navigationController.viewControllers mutableCopy];
			[stack removeLastObject];
			[stack removeLastObject];
			[stack addObject:form];
			[innerSelf.navigationController setViewControllers:stack animated:YES];
		}];
		return YES;
	};
	[self.navigationController pushViewController:scanner animated:YES];
}

@end
