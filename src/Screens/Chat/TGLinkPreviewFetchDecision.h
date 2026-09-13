#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const TGLinkPreviewOptionURL;
extern NSString *const TGLinkPreviewOptionForceSmallMedia;
extern NSString *const TGLinkPreviewOptionForceLargeMedia;
extern NSString *const TGLinkPreviewOptionShowAboveText;

BOOL TGLinkPreviewFetchCandidateText(NSString *_Nullable text);

BOOL TGLinkPreviewOptionsAreDisabled(NSDictionary *_Nullable linkPreviewOptions);

NSDictionary *TGLinkPreviewOptionValuesFromMessage(NSDictionary *_Nullable linkPreviewOptions);

NS_ASSUME_NONNULL_END
