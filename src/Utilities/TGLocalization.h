#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

extern NSString *const TGLocalizationDidChangeNotification;

#ifdef __cplusplus
extern "C" {
#endif

NSString *TGLocalizedString(NSString *key, NSString *fallback);
NSString *TGLocalizedPlural(NSString *key, NSInteger count, NSString *fallbackOne, NSString *fallbackOther);

#ifdef __cplusplus
}
#endif

#define TGL(key, fallback) TGLocalizedString(key, fallback)
#define TGLPlural(key, count, one, other) TGLocalizedPlural(key, count, one, other)

NSLocale *TGFormatterLocale(void);

NSTextAlignment TGLocalizedLeadingTextAlignment(void);

UIImage *TGLocalizedDirectionalStretchableImage(UIImage *image, NSInteger leftCapWidth);

UIImage *TGLocalizedDirectionalImage(UIImage *image);

BOOL TGLocalizedIsRTL(void);

CGRect TGLocalizedMirroredRect(CGRect rect, CGFloat containerWidth);

void TGApplyRTLTableMirroring(UITableView *tableView);

void TGApplyRTLCellMirroring(UITableViewCell *cell);

void TGApplyRTLHeaderMirroring(UIView *headerOrFooterView);

@interface TGLocalization : NSObject

+ (instancetype)shared;

- (void)loadInstalledPack;

- (void)installPackId:(NSString *)packId strings:(NSDictionary *)strings;

- (void)installPackId:(NSString *)packId
			  strings:(NSDictionary *)strings
		   pluralCode:(NSString *)pluralCode
				  rtl:(BOOL)rtl;

- (void)clearInstalledPack;

- (NSString *)installedPackId;

- (BOOL)wantsSystemLanguagePack;
- (NSString *)systemLanguagePackId;
- (void)rememberSystemLanguagePackAttempt;

- (NSString *)installedPackPluralCode;

- (BOOL)installedPackIsRTL;

- (NSString *)overrideForKey:(NSString *)key;

@end
