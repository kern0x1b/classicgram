#import <CoreGraphics/CoreGraphics.h>
#import <Foundation/Foundation.h>

NSString *TGMembersString(NSDictionary *m, NSString *key);
NSInteger TGMembersInteger(NSDictionary *m, NSString *key);
NSString *TGMembersShortDate(NSTimeInterval seconds);
NSString *TGMembersStatusText(NSDictionary *member);
NSString *TGMembersRoleText(NSDictionary *member);
BOOL TGMembersStatusIsOnline(NSDictionary *member);

extern const CGFloat kMemberAvatar;
int64_t TGMembersUserId(NSDictionary *m);
