#import <UIKit/UIKit.h>

@interface TGIcons : NSObject

+ (void)flush;

@end

@interface TGIcons (Drawing)

+ (UIImage *)chats;
+ (UIImage *)contacts;
+ (UIImage *)settings;

+ (UIImage *)compose;
+ (UIImage *)send;
+ (UIImage *)attach;
+ (UIImage *)play;
+ (UIImage *)pause;
+ (UIImage *)document;
+ (UIImage *)pin;
+ (UIImage *)microphone;
+ (UIImage *)sticker;

+ (UIImage *)musicNoteOfSide:(CGFloat)side colour:(UIColor *)colour;

+ (UIImage *)floatingPlateOfSide:(CGFloat)side chevron:(BOOL)chevron
						 pressed:(BOOL)pressed;

+ (UIImage *)microphoneOfSide:(CGFloat)side colour:(UIColor *)colour;

+ (UIImage *)waveform:(NSData *)waveform size:(CGSize)size
			   played:(CGFloat)played
			   colour:(UIColor *)colour;

+ (UIImage *)progressLineOfSize:(CGSize)size played:(CGFloat)played
						 colour:(UIColor *)colour;

+ (UIImage *)bubbleTailForColour:(UIColor *)colour outgoing:(BOOL)outgoing;

+ (UIImage *)messageChecksRead:(BOOL)read white:(BOOL)white;
+ (UIImage *)messageTimestampPlateOutgoing:(BOOL)outgoing;

+ (UIImage *)archiveAvatarOfSide:(CGFloat)side;
+ (UIImage *)savedMessagesAvatarOfSide:(CGFloat)side;
+ (UIImage *)myNotesAvatarOfSide:(CGFloat)side;
+ (UIImage *)hiddenAuthorAvatarOfSide:(CGFloat)side;
+ (UIImage *)generalTopicAvatarOfSide:(CGFloat)side;

+ (UIImage *)avatarWithInitials:(NSString *)initials
						   size:(CGFloat)size
					   colourId:(int64_t)colourId;

+ (UIImage *)callArrowOutgoing:(BOOL)outgoing missed:(BOOL)missed;

+ (UIImage *)menuGlyphNamed:(NSString *)name;

+ (void)styleHeaderButton:(UIButton *)button;
+ (UIButton *)headerButtonWithTitle:(NSString *)title bold:(BOOL)bold
							 target:(id)target
							 action:(SEL)action;

+ (UIButton *)backButtonWithTitle:(NSString *)title target:(id)target action:(SEL)action;
+ (UIBarButtonItem *)backBarButtonItemWithTitle:(NSString *)title
										 target:(id)target
										 action:(SEL)action;
+ (UIBarButtonItem *)headerBarButtonItemWithTitle:(NSString *)title
											 bold:(BOOL)bold
										   target:(id)target
										   action:(SEL)action;
+ (void)setUnreadCount:(NSInteger)count onBackButton:(UIButton *)backButton;

typedef enum {
	TGActionButtonKindNeutral = 0,
	TGActionButtonKindDestructive
} TGActionButtonKind;

+ (UIButton *)actionButtonWithTitle:(NSString *)title
							   kind:(TGActionButtonKind)kind
							 target:(id)target
							 action:(SEL)action;

+ (CGFloat)actionRowHeight;
+ (UIButton *)actionButtonInCell:(UITableViewCell *)cell
						   title:(NSString *)title
							kind:(TGActionButtonKind)kind
						  target:(id)target
						  action:(SEL)action;
+ (void)setActionButton:(UIButton *)button enabled:(BOOL)enabled;
+ (void)removeActionButtonFromCell:(UITableViewCell *)cell;

@end
