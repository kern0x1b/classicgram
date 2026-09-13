#import <UIKit/UIKit.h>

extern NSString *const TGCustomEmojiImagesDidChangeNotification;

UIImage *TGCustomEmojiCachedImage(long long customEmojiId);

void TGCustomEmojiRequestImage(long long customEmojiId);
