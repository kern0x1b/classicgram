#import <UIKit/UIKit.h>

typedef enum {
	TGStoryListMenu = 0,
	TGStoryListArchive,
	TGStoryListProfile,
	TGStoryListAlbums,
	TGStoryListAlbum,
	TGStoryListForwards,
	TGStoryListTag,
	TGStoryListVenue,
	TGStoryListLocation,
	TGStoryListSettings,
	TGStoryListHidden,
	TGStoryListExceptions
} TGStoryListMode;

@interface TGStoryListViewController : UIViewController <UITableViewDataSource, UITableViewDelegate>

@property (nonatomic, assign) TGStoryListMode mode;
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, assign) NSInteger storyId;
@property (nonatomic, assign) NSInteger albumId;
@property (nonatomic, copy) NSString *tag;
@property (nonatomic, copy) NSString *venueProvider;
@property (nonatomic, copy) NSString *venueId;
@property (nonatomic, copy) NSString *locationCountryCode;
@property (nonatomic, copy) NSString *locationState;
@property (nonatomic, copy) NSString *locationCity;
@property (nonatomic, copy) NSString *locationStreet;

+ (void)pushMode:(TGStoryListMode)mode
		  chatId:(int64_t)chatId
		   title:(NSString *)title
			from:(UIViewController *)host;

@end
