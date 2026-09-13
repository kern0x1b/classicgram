#import "TGBusinessLocationPickerViewController.h"
#import "TGIcons.h"
#import <MapKit/MapKit.h>
#import <CoreLocation/CoreLocation.h>
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGAlertView.h"

@interface TGBusinessLocationPickerViewController () <CLLocationManagerDelegate>

@property (nonatomic, strong) MKMapView *mapView;
@property (nonatomic, strong) UIImageView *centerPin;
@property (nonatomic, strong) UIButton *useMyLocationButton;
@property (nonatomic, strong) UIButton *confirmButton;
@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, assign) BOOL hasPoint;
@property (nonatomic, assign) double latitude;
@property (nonatomic, assign) double longitude;
@property (nonatomic, assign) BOOL locating;
@property (nonatomic, assign) BOOL confirmed;

@end

@implementation TGBusinessLocationPickerViewController

- (instancetype)initWithHasPoint:(BOOL)hasPoint
						 latitude:(double)latitude
						longitude:(double)longitude {
	self = [super init];
	if (self) {
		_hasPoint = hasPoint;
		_latitude = latitude;
		_longitude = longitude;
		self.title = TGL(@"Map.ChooseLocationTitle", @"Location");
		self.hidesBottomBarWhenPushed = YES;
	}
	return self;
}

- (void)viewDidLoad {
	[super viewDidLoad];
	if ([self respondsToSelector:@selector(setEdgesForExtendedLayout:)])
		self.edgesForExtendedLayout = UIRectEdgeNone;
	self.view.backgroundColor = [[TGTheme shared] listBackgroundColour];

	self.mapView = [[MKMapView alloc] initWithFrame:self.view.bounds];
	self.mapView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[self.view addSubview:self.mapView];

	self.centerPin = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"MapLocationIcon_Active"]];
	[self.view addSubview:self.centerPin];

	self.useMyLocationButton = [self buttonWithTitle:TGL(@"Location.AddMyLocation", @"Add My Current Location")];
	self.useMyLocationButton.backgroundColor = [[TGTheme shared] listBackgroundColour];
	[self.useMyLocationButton setTitleColor:[[TGTheme shared] accentColour] forState:UIControlStateNormal];
	[self.useMyLocationButton addTarget:self action:@selector(useMyLocation) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:self.useMyLocationButton];

	self.confirmButton = [self buttonWithTitle:TGL(@"Location.AddThisLocation", @"Add This Location")];
	self.confirmButton.backgroundColor = [[TGTheme shared] accentColour];
	[self.confirmButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
	[self.confirmButton addTarget:self action:@selector(confirm) forControlEvents:UIControlEventTouchUpInside];
	[self.view addSubview:self.confirmButton];

	MKCoordinateRegion region = self.hasPoint
		? MKCoordinateRegionMake(CLLocationCoordinate2DMake(self.latitude, self.longitude), MKCoordinateSpanMake(0.01, 0.01))
		: MKCoordinateRegionMake(CLLocationCoordinate2DMake(0, 0), MKCoordinateSpanMake(60, 60));
	[self.mapView setRegion:region animated:NO];
}

- (UIButton *)buttonWithTitle:(NSString *)title {
	return [TGIcons actionButtonWithTitle:title
									 kind:TGActionButtonKindNeutral
								   target:nil
								   action:NULL];
}

- (void)viewWillAppear:(BOOL)animated {
	[super viewWillAppear:animated];
	[[TGTheme shared] styleNavigationBar:self.navigationController.navigationBar];
}

- (void)viewDidLayoutSubviews {
	[super viewDidLayoutSubviews];
	CGFloat pinSide = 32;
	CGRect bounds = self.view.bounds;
	self.centerPin.frame = CGRectMake((bounds.size.width - pinSide) / 2,
		(bounds.size.height - pinSide) / 2 - pinSide / 2,
		pinSide, pinSide);

	CGFloat sideInset = 15;
	CGFloat buttonHeight = 44;
	CGFloat gap = 10;
	CGFloat bottomInset = 20;
	CGFloat width = bounds.size.width - sideInset * 2;
	self.confirmButton.frame = CGRectMake(sideInset, bounds.size.height - bottomInset - buttonHeight, width, buttonHeight);
	self.useMyLocationButton.frame = CGRectMake(sideInset,
		self.confirmButton.frame.origin.y - gap - buttonHeight, width, buttonHeight);
}

- (void)confirm {
	if (self.confirmed)
		return;
	self.confirmed = YES;
	self.confirmButton.enabled = NO;
	CLLocationCoordinate2D coordinate = self.mapView.centerCoordinate;
	if (self.onPicked)
		self.onPicked(coordinate.latitude, coordinate.longitude);
	[self.navigationController popViewControllerAnimated:YES];
}

- (void)useMyLocation {
	if (self.locating)
		return;
	if (![CLLocationManager locationServicesEnabled]) {
		[self showUnavailable];
		return;
	}
	if (!self.locationManager) {
		self.locationManager = [[CLLocationManager alloc] init];
		self.locationManager.delegate = self;
	}
	self.locating = YES;
	[self beginLocationUpdatesRequestingAuthorizationIfNeeded];
}

- (void)beginLocationUpdatesRequestingAuthorizationIfNeeded {
	CLAuthorizationStatus status = [CLLocationManager respondsToSelector:@selector(authorizationStatus)]
		? [CLLocationManager authorizationStatus]
		: kCLAuthorizationStatusAuthorizedAlways;
	if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
		self.locating = NO;
		[self showAccessDenied];
		return;
	}
	if (status == kCLAuthorizationStatusNotDetermined) {
		if ([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)])
			[self.locationManager requestWhenInUseAuthorization];
		return;
	}
	[self.locationManager startUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations {
	[manager stopUpdatingLocation];
	self.locating = NO;
	CLLocation *fix = [locations lastObject];
	if (!fix)
		return;
	[self.mapView setRegion:MKCoordinateRegionMake(fix.coordinate, MKCoordinateSpanMake(0.01, 0.01)) animated:YES];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
	[manager stopUpdatingLocation];
	self.locating = NO;
	if ([error.domain isEqualToString:kCLErrorDomain] && error.code == kCLErrorDenied)
		[self showAccessDenied];
	else
		[self showUnavailable];
}

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status {
	if (!self.locating || status == kCLAuthorizationStatusNotDetermined)
		return;
	if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted) {
		self.locating = NO;
		[self showAccessDenied];
		return;
	}
	[manager startUpdatingLocation];
}

- (void)showAccessDenied {
	TGAlertView *bareAlert = [TGAlertView alloc];
	TGAlertView *alert = [bareAlert initWithTitle:nil
										   message:TGL(@"AccessDenied.Location", @"Telegram needs access to your location. Please go to Settings > Privacy > Location and set Telegram to ON.")
										  delegate:nil
								 cancelButtonTitle:TGL(@"Common.OK", @"OK")
								 otherButtonTitles:nil];
	[alert show];
}

- (void)showUnavailable {
	TGAlertView *bareAlert = [TGAlertView alloc];
	TGAlertView *alert = [bareAlert initWithTitle:nil
										   message:TGL(@"Chat.LocationIsNotAvailable", @"Location is not available.")
										  delegate:nil
								 cancelButtonTitle:TGL(@"Common.OK", @"OK")
								 otherButtonTitles:nil];
	[alert show];
}

@end
