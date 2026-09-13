#import "TGFormSaveState.h"
#import "TGTextFieldStyle.h"
#import "TGIcons.h"
#import "TGGroupedCaption.h"
#import "TGListBackground.h"
#import "TGBusinessLocationViewController.h"
#import <MapKit/MapKit.h>
#import "TGLocalization.h"
#import "TGBusinessService.h"
#import "TGTheme.h"
#import "TGAlertView.h"
#import "TGSnackbar.h"
#import "TGBusinessLocationPickerViewController.h"

@interface TGBusinessLocationViewController () <UITextFieldDelegate>

@property (nonatomic, strong) UITextField *addressField;
@property (nonatomic, assign) BOOL hasPoint;
@property (nonatomic, assign) double latitude;
@property (nonatomic, assign) double longitude;
@property (nonatomic, assign) BOOL loaded;
@property (nonatomic, assign) BOOL saving;
@property (nonatomic, strong) UIBarButtonItem *saveButtonItem;

@end

@implementation TGBusinessLocationViewController

- (instancetype)init {
	self = [super initWithStyle:UITableViewStyleGrouped];
	if (self)
		self.title = TGL(@"Business.Location", @"Location");
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.tableView.backgroundColor = TGGroupedListBackground();
	self.saveButtonItem = [[UIBarButtonItem alloc]
		initWithTitle:TGL(@"Common.Save", @"Save")
				style:UIBarButtonItemStyleDone
			   target:self
			   action:@selector(save)];
	self.navigationItem.rightBarButtonItem = self.saveButtonItem;

	self.addressField = [[UITextField alloc] initWithFrame:CGRectZero];
	self.addressField.placeholder = TGL(@"BusinessLocationSetup.AddressPlaceholder", @"Enter Address");
	self.addressField.font = TGTextFieldFont();
	self.addressField.backgroundColor = [UIColor clearColor];
	self.addressField.clearButtonMode = UITextFieldViewModeWhileEditing;
	self.addressField.returnKeyType = UIReturnKeyDone;
	self.addressField.textColor = [[TGTheme shared] primaryTextColour];
	self.addressField.delegate = self;
	self.addressField.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	TGStyleTextField(self.addressField);

	__weak typeof(self) weakSelf = self;
	[TGBusinessService businessSettingsWithCompletion:^(NSDictionary *settings, BOOL failed) {
		__strong typeof(weakSelf) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		if (failed) {
			strongSelf.saveButtonItem.enabled = TGFormCanSave(YES, YES, NO);
			[TGSnackbar showInView:strongSelf.navigationController.view
							  text:TGL(@"Toast.CouldNotLoadBusinessSettings", @"Could not read your business settings")
						   seconds:2
						  onCommit:nil];
			return;
		}
		NSDictionary *location = settings[@"location"];
		strongSelf.addressField.text = [location[@"address"] isKindOfClass:NSString.class]
			? location[@"address"]
			: @"";
		strongSelf.hasPoint = [location[@"hasPoint"] boolValue];
		strongSelf.latitude = [location[@"latitude"] doubleValue];
		strongSelf.longitude = [location[@"longitude"] doubleValue];
		strongSelf.loaded = YES;
		[strongSelf.tableView reloadData];
	}];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

#pragma mark - table

- (BOOL)hasDeleteRow {
	return self.hasPoint || self.addressField.text.length > 0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	if (section == 0)
		return 1;
	if (section == 1)
		return self.hasPoint ? 2 : 1;
	return self.hasDeleteRow ? 1 : 0;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section {
	if (section == 0)
		return TGL(@"BusinessLocationSetup.Text", @"Display the location of your business on your account.");
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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 0) {
		UITableViewCell *bareCell = [UITableViewCell alloc];
		UITableViewCell *cell = [bareCell initWithStyle:UITableViewCellStyleDefault
										reuseIdentifier:nil];
		[[TGTheme shared] styleCell:cell];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		CGFloat width = tableView.bounds.size.width - 40;
		self.addressField.frame = CGRectMake(15, 12, width, 22);
		[cell.contentView addSubview:self.addressField];
		return cell;
	}

	if (indexPath.section == 1 && indexPath.row == 0) {
		UITableViewCell *bareCell = [UITableViewCell alloc];
		UITableViewCell *cell = [bareCell initWithStyle:UITableViewCellStyleDefault
										reuseIdentifier:nil];
		[[TGTheme shared] styleCell:cell];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.textLabel.text = TGL(@"BusinessLocationSetup.SetLocationOnMap", @"Set Location on Map");
		UISwitch *toggle = [[UISwitch alloc] init];
		toggle.on = self.hasPoint;
		[toggle addTarget:self action:@selector(pointSwitchChanged:) forControlEvents:UIControlEventValueChanged];
		cell.accessoryView = toggle;
		return cell;
	}

	UITableViewCell *bareCell = [UITableViewCell alloc];
	UITableViewCell *cell = [bareCell initWithStyle:UITableViewCellStyleDefault
									reuseIdentifier:nil];
	[[TGTheme shared] styleCell:cell];

	if (indexPath.section == 1 && indexPath.row == 1) {
		cell.selectionStyle = UITableViewCellSelectionStyleDefault;
		MKMapView *mapView = [[MKMapView alloc] initWithFrame:CGRectMake(0, 0, tableView.bounds.size.width, [self mapPreviewHeight])];
		mapView.userInteractionEnabled = NO;
		mapView.layer.cornerRadius = [[TGTheme shared] mediaCornerRadius];
		mapView.clipsToBounds = YES;
		mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(self.latitude, self.longitude);
		[mapView setRegion:MKCoordinateRegionMake(coordinate, MKCoordinateSpanMake(0.01, 0.01)) animated:NO];
		MKPointAnnotation *pin = [[MKPointAnnotation alloc] init];
		pin.coordinate = coordinate;
		[mapView addAnnotation:pin];
		[cell.contentView addSubview:mapView];
		return cell;
	}

	[TGIcons actionButtonInCell:cell
						  title:TGL(@"BusinessLocationSetup.DeleteLocation", @"Delete Location")
						   kind:TGActionButtonKindDestructive
						 target:self
						 action:@selector(deleteLocationPressed)];
	return cell;
}

- (CGFloat)mapPreviewHeight {
	return 160;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
	if (indexPath.section == 1 && indexPath.row == 1)
		return [self mapPreviewHeight];
	if (indexPath.section == 2)
		return TGActionRowHeight();
	return 44;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
	if (indexPath.section == 1 && indexPath.row == 1) {
		[self openLocationPicker];
		return;
	}
}

- (void)deleteLocationPressed {
	self.addressField.text = @"";
	self.hasPoint = NO;
	self.latitude = 0;
	self.longitude = 0;
	[self.tableView reloadData];
}

- (void)pointSwitchChanged:(UISwitch *)toggle {
	if (toggle.on) {
		[toggle setOn:self.hasPoint animated:NO];
		[self openLocationPicker];
		return;
	}
	self.hasPoint = NO;
	[self.tableView reloadData];
}

- (void)openLocationPicker {
	TGBusinessLocationPickerViewController *picker = [[TGBusinessLocationPickerViewController alloc]
		initWithHasPoint:self.hasPoint latitude:self.latitude longitude:self.longitude];
	__weak typeof(self) weakSelf = self;
	picker.onPicked = ^(double latitude, double longitude) {
		typeof(self) strongSelf = weakSelf;
		if (!strongSelf)
			return;
		strongSelf.hasPoint = YES;
		strongSelf.latitude = latitude;
		strongSelf.longitude = longitude;
		[strongSelf.tableView reloadData];
	};
	[self.navigationController pushViewController:picker animated:YES];
}

#pragma mark - save

- (void)save {
	if (self.saving)
		return;
	[self.view endEditing:YES];
	NSString *address = [self.addressField.text stringByTrimmingCharactersInSet:
			[NSCharacterSet whitespaceAndNewlineCharacterSet]];
	if (!address.length && self.hasPoint) {
		[self showAlert:TGL(@"BusinessLocationSetup.ErrorAddressEmpty.Text", @"Address can't be empty.")];
		return;
	}
	self.saving = YES;
	self.saveButtonItem.enabled = NO;
	BOOL hasPoint = self.hasPoint;
	__weak typeof(self) weakSelf = self;
	[TGBusinessService setBusinessAddress:address
								 latitude:self.latitude
								longitude:self.longitude
								 hasPoint:hasPoint
							   completion:^(BOOL ok) {
								   __strong typeof(weakSelf) strongSelf = weakSelf;
								   if (!strongSelf)
									   return;
								   UIView *host = strongSelf.navigationController.view;
								   if (!ok) {
									   strongSelf.saving = NO;
									   strongSelf.saveButtonItem.enabled = YES;
									   [TGSnackbar showInView:host
												  text:TGL(@"Toast.CouldNotSaveBusinessLocation", @"Could not save the business location")
											   seconds:2
											  onCommit:nil];
									   return;
								   }
								   NSString *saved = TGL(@"Toast.BusinessLocationSaved", @"Saved");
								   [TGSnackbar showInView:host text:saved seconds:2 onCommit:nil];
								   [strongSelf.navigationController popViewControllerAnimated:YES];
							   }];
}

- (void)showAlert:(NSString *)message {
	TGAlertView *bareAlert = [TGAlertView alloc];
	TGAlertView *alert = [bareAlert initWithTitle:nil message:message
										 delegate:nil
								cancelButtonTitle:TGL(@"Common.OK", @"OK")
								otherButtonTitles:nil];
	[alert show];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
	[textField resignFirstResponder];
	return NO;
}

- (BOOL)textField:(UITextField *)field shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
	NSString *current = field.text ?: @"";
	if (range.location > current.length)
		return NO;
	NSString *next = [current stringByReplacingCharactersInRange:range withString:string];
	return next.length <= 96;
}

@end
