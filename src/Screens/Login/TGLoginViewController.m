#import "TGLoginViewController.h"
#import "TGLocalization.h"
#import "TGTheme.h"
#import "TGCountryPickerViewController.h"
#import "TGPhoneFormat.h"
#import "TGActionSheet.h"
#import "TGQRImage.h"
#import "TGAccountManager.h"
#import "TGBackspaceTextField.h"
#import "TGLoginToolbarButton.h"
#import <QuartzCore/QuartzCore.h>
#import "TGLoginViewControllerInternal.h"

@implementation TGLoginViewController

- (void)dealloc {
	[self tearDownTextInput];
}

@dynamic busy;

@end
