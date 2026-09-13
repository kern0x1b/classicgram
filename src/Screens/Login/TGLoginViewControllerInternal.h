#import <UIKit/UIKit.h>
#import "TGLoginViewController.h"
#import "TGBackspaceTextField.h"
#import "TGLoginToolbarButton.h"
#import "TGActionSheet.h"
#import "TGResendCountdown.h"

typedef NS_ENUM(NSInteger, TGLoginStep) {
	TGLoginStepPhone,
	TGLoginStepCode,
	TGLoginStepPassword,
	TGLoginStepEmail,
	TGLoginStepEmailCode,
	TGLoginStepRecoveryCode,
	TGLoginStepNewPassword,
	TGLoginStepNewPasswordConfirm,
	TGLoginStepNewPasswordHint,
	TGLoginStepRegistration
};

static const NSInteger kLoginAlertTerms = 101;
static const NSInteger kLoginAlertDeleteAccount = 102;
static const NSInteger kLoginExistingAccountAlertTag = 92;

@interface TGLoginViewController () <UIAlertViewDelegate> {
	BOOL _busy;
	TGResendCountdown *_resendCountdown;
	TGActionSheet *_currentActionSheet;
	UITextField *_lastNameField;
	UITextField *_inputField;
	UITextField *_countryCodeField;
}

@property (nonatomic, assign) TGLoginStep currentStep;
@property (nonatomic, strong) UILabel *noticeLabel;
@property (nonatomic, strong) UIButton *countryButton;
@property (nonatomic, strong) UIImageView *inputBackgroundView;
@property (nonatomic, strong) UIImageView *inputDivider;
@property (nonatomic, strong) UITextField *countryCodeField;
@property (nonatomic, strong) UITextField *inputField;
@property (nonatomic, strong) UIButton *nextButton;
@property (nonatomic, strong) UIButton *resendButton;
@property (nonatomic, strong) UIButton *extraButton;
@property (nonatomic, strong) UIButton *cancelButton;
@property (nonatomic, assign) NSInteger slotToSwitchTo;
@property (nonatomic, strong) UIButton *backButton;
@property (nonatomic, strong) UILabel *timeoutLabel;
@property (nonatomic, strong) UILabel *requestingCallLabel;
@property (nonatomic, strong) UILabel *callSentLabel;
@property (nonatomic, assign) NSInteger callRequestState;
@property (nonatomic, strong) UIView *shadeView;
@property (nonatomic, strong) UIButton *addPhotoButton;
@property (nonatomic, strong) UIImage *plateImage;
@property (nonatomic, strong) UIImage *plateTopImage;
@property (nonatomic, strong) UIImage *plateBottomImage;
@property (nonatomic, strong) UIActivityIndicatorView *spinner;
@property (nonatomic, copy) NSString *savedPhoneNumber;
@property (nonatomic, copy) NSString *emailPattern;
@property (nonatomic, copy) NSString *passwordHint;
@property (nonatomic, copy) NSString *recoveryEmailPattern;
@property (nonatomic, copy) NSString *verifiedRecoveryCode;
@property (nonatomic, copy) NSString *pendingNewPassword;
@property (nonatomic, copy) NSString *nextCodeTypeTitle;
@property (nonatomic, copy) NSString *nextCodeType;
@property (nonatomic, assign) BOOL busy;
@property (nonatomic, strong) TGResendCountdown *resendCountdown;
@property (nonatomic, assign) NSInteger resendSeconds;
@property (nonatomic, strong) TGActionSheet *currentActionSheet;
@property (nonatomic, assign) BOOL suppressResendButton;
@property (nonatomic, strong) UITextField *lastNameField;
@property (nonatomic, strong) UIImageView *lastNameBackgroundView;
@property (nonatomic, assign) BOOL codeIsText;
@property (nonatomic, assign) BOOL codeIsPhrase;
@property (nonatomic, assign) NSInteger expectedCodeLength;
@property (nonatomic, copy) NSString *termsText;
@property (nonatomic, assign) NSInteger termsMinUserAge;
@property (nonatomic, copy) NSString *lastQueriedPhonePrefix;
@property (nonatomic, assign) BOOL countryCodeEdited;
@property (nonatomic, assign) BOOL didPrefillGuessedCountry;
@property (nonatomic, assign) CGFloat keyboardHeight;
@property (nonatomic, strong) id keyboardFrameObserverToken;

@end

static inline UIColor *tgRGBA(int rgb, CGFloat alpha) {
	return [UIColor colorWithRed:((rgb >> 16) & 0xff) / 255.0f
						   green:((rgb >> 8) & 0xff) / 255.0f
							blue:(rgb & 0xff) / 255.0f
						   alpha:alpha];
}

static inline void tgStylePlaceholder(UITextField *field, UIFont *font, UIColor *colour) {
	NSString *text = field.placeholder;
	if (text.length == 0)
		return;
	if (![field respondsToSelector:@selector(setAttributedPlaceholder:)])
		return;
	NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
	if (colour != nil)
		[attributes setObject:colour forKey:NSForegroundColorAttributeName];
	if (font != nil)
		[attributes setObject:font forKey:NSFontAttributeName];
	field.attributedPlaceholder = [[NSAttributedString alloc] initWithString:text attributes:attributes];
}

@interface TGLoginViewController (Private)

- (void)tearDownTextInput;

- (NSString *)formattedPhoneForDigits:(NSString *)nationalDigits;

- (void)updateTitleText;

- (void)reformatPhoneField;

- (void)viewDidLoad;

- (UIButton *)loginToolbarButtonWithTitle:(NSString *)title
									plate:(NSString *)plateName
								  pressed:(NSString *)pressedName
							  leftCapHalf:(BOOL)leftCapHalf
								  leftCap:(int)leftCap
							 shadowColour:(UIColor *)shadowColour
							  paddingLeft:(CGFloat)paddingLeft
							 paddingRight:(CGFloat)paddingRight
								 minWidth:(CGFloat)minWidth
								   isBack:(BOOL)isBack;

- (void)sizeLoginToolbarButton:(UIButton *)button
				   paddingLeft:(CGFloat)paddingLeft
				  paddingRight:(CGFloat)paddingRight
					  minWidth:(CGFloat)minWidth;

- (void)setupNavigationBar;

- (UIButton *)neutralLoginButtonWithTitle:(NSString *)title;

- (void)setLoginButton:(UIButton *)button title:(NSString *)title;

- (void)installCancelButtonIfNeeded;

- (void)cancelTapped;

- (UILabel *)countdownStateLabelWithText:(NSString *)text;

- (void)setupUI;

- (void)buildBackgroundLayers;

- (void)buildNoticeLabel;

- (void)buildCountryButton;

- (void)buildPlateImages;

- (void)buildInputPlate;

- (void)buildPhoneFields;

- (void)buildLastNameRow;

- (void)buildCountdownLabels;

- (void)buildResendAndExtraButtons;

- (void)buildShadeView;

- (void)prefillGuessedCountry;

- (void)phoneFieldsDidEndEditing;

- (NSString *)currentCountryId;

- (NSString *)countryNameForId:(NSString *)countryId;

- (NSString *)currentCountryName;

- (NSString *)defaultDialCode;

- (void)setMatchedCountryTitle:(NSString *)title;

- (void)setUnmatchedCountryTitle;

- (void)updateCountryNameForDialCode;

- (void)countryButtonTapped;

- (void)dismissCountryPicker;

- (CGFloat)plateWidthForCurrentStep;

- (void)restylePlaceholders;

- (void)setNextButtonTitle:(NSString *)title;

- (void)layoutInterface;

- (void)layoutRegistrationStepForViewSize:(CGSize)viewSize;

- (void)layoutPhoneRowForViewSize:(CGSize)viewSize;

- (void)layoutCentredPlateForViewSize:(CGSize)viewSize;

- (void)layoutNoticeLabelForViewSize:(CGSize)viewSize;

- (void)layoutCountdownRowForViewSize:(CGSize)viewSize;

- (void)inputBackgroundTapped:(UITapGestureRecognizer *)recognizer;

- (void)textFieldDidHitLastBackspace;

- (void)setBusy:(BOOL)busy;

- (NSString *)trimmedInput;

- (NSString *)digitsOnly:(NSString *)string;

- (BOOL)hasSubmittableInput;

- (void)updateNextEnabled;

- (void)shakeView:(UIView *)view;

- (void)shakeInputRow;

- (void)inputChanged;

- (void)countryCodeChanged;

- (void)actionButtonTapped;

- (NSInteger)slotAlreadyHoldingPhoneDigits:(NSString *)digits;

- (void)submitPhoneNumber:(NSString *)text;

- (void)submitCode:(NSString *)text;

- (void)submitRegistrationFirstName:(NSString *)text;

- (void)submitPassword:(NSString *)text;

- (void)submitEmailAddress:(NSString *)text;

- (void)submitEmailCode:(NSString *)text;

- (void)submitRecoveryCode:(NSString *)text;

- (void)submitNewPassword:(NSString *)text;

- (void)submitNewPasswordConfirm:(NSString *)text;

- (void)submitNewPasswordHint:(NSString *)text;

- (void)finishNewPasswordRecoveryWithHint:(NSString *)hint;

- (void)showLoginAlert:(NSString *)message;

- (NSString *)loginErrorMessage:(NSString *)genericMessage forRetryAfterSeconds:(NSInteger)retryAfterSeconds;

- (void)enterStep:(TGLoginStep)step title:(NSString *)title notice:(NSString *)notice;

- (void)finishStepTransition;

- (void)finishStepTransitionFocusingInput;

- (void)showCodeStepWithPhoneNumber:(NSString *)phoneNumber;

- (void)applyTextCodeType:(BOOL)isPhrase;

- (void)applyCodeInfo:(NSDictionary *)info;

- (void)showRegistrationStep;

- (void)applyRegistrationTerms:(NSDictionary *)terms;

- (void)lastNameBackgroundTapped;

- (void)showPasswordStepWithHint:(NSString *)hint recoveryEmailPattern:(NSString *)recoveryEmailPattern;

- (void)showPhoneStep;

- (BOOL)handleExistingAccountAlert:(UIAlertView *)alertView buttonIndex:(NSInteger)buttonIndex;

- (void)showEmailStep;

- (void)showEmailCodeStepWithPattern:(NSString *)pattern;

- (void)applyEmailState:(NSDictionary *)info;

- (void)showRecoveryCodeStep;

- (void)showNewPasswordStep;

- (void)showNewPasswordConfirmStep;

- (void)showNewPasswordHintStep;

- (void)extraTapped;

- (void)showPasswordResetOptions;

- (void)confirmAccountDeletion;

- (void)deleteAccountNow;

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex;

- (void)installBackButton;

- (void)backTapped;

- (void)logOutAndReturnToPhoneStep;

- (void)startResendCountdown;

- (void)startResendCountdownWithSeconds:(NSInteger)seconds;

- (void)beginCallRequest;

- (void)failCallRequestWithRetryAfterSeconds:(NSInteger)retryAfterSeconds;

- (void)finishCallRequest;

- (void)beginSilentResend;

- (BOOL)nextCodeTypeIsCall;

- (void)startResendTimer;

- (void)stopResendCountdown;

- (void)updateResendTitle;

- (void)resendTapped;

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string;

- (void)applyPhoneFormattingInField:(UITextField *)textField range:(NSRange)range replacement:(NSString *)string;

- (BOOL)textFieldShouldReturn:(UITextField *)textField;

- (void)viewDidAppear:(BOOL)animated;

- (void)dealloc;

@end

@interface TGLoginViewController (Input) <TGBackspaceTextFieldDelegate>
@end
