#import <UIKit/UIKit.h>

extern const CGFloat kActionButtonHeight;
extern const CGFloat kButtonsRowHeight;
extern const CGFloat kButtonGutter;
extern const CGFloat kGroupedInset;
extern const CGFloat kButtonsRowGutter;
extern const CGFloat kTitleContainerHeight;
extern const CGFloat kGroupTitleContainerHeight;
extern const CGFloat kProfileAvatarSide;
extern const CGFloat kProfileAvatarPhotoSide;
extern const CGFloat kProfileAvatarPhotoOffset;
extern const CGFloat kProfileAvatarRadius;
extern const CGFloat kProfileNameGap;
extern const CGFloat kGroupNameGap;
extern const CGFloat kMemberRowHeight;
extern const CGFloat kMemberAvatarSide;

CGFloat TGProfileRetinaPixel(void);
NSString *TGProfileText(id value);
NSString *TGProfileNumberText(id value);
BOOL TGProfileBool(id value);
int64_t TGProfileInt64(id value);
NSString *TGProfileInitial(NSString *name);
UIImage *TGProfileStretched(NSString *name);
UIImage *TGProfileStretchedInCentre(NSString *name);
UIImage *TGProfileAvatarPlate(UIImage *photo);
UIImage *TGProfilePlaceholderPlate(int64_t colourId, BOOL isGroup);
BOOL TGProfileCanRenderText(NSString *text);
NSString *TGProfileLastSeenText(long long wasOnline);
