#import <Foundation/Foundation.h>

#ifdef __cplusplus
extern "C" {
#endif

Class TGFrameworkClass(NSString *framework, NSString *className);
void *TGFrameworkSymbol(NSString *framework, const char *symbol);
NSString *TGFrameworkString(NSString *framework, const char *symbol);
void TGFrameworkSelfTest(void);

#ifdef __cplusplus
}
#endif

#define TGAVClass(name) TGFrameworkClass(@"AVFoundation", @ #name)
#define TGAVString(name) TGFrameworkString(@"AVFoundation", #name)
#define TGMPClass(name) TGFrameworkClass(@"MediaPlayer", @ #name)
#define TGMPString(name) TGFrameworkString(@"MediaPlayer", #name)
#define TGALClass(name) TGFrameworkClass(@"AssetsLibrary", @ #name)
#define TGALString(name) TGFrameworkString(@"AssetsLibrary", #name)
#define TGCLClass(name) TGFrameworkClass(@"CoreLocation", @ #name)
