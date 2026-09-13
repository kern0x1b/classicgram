#import <Foundation/Foundation.h>

typedef NS_ENUM(uint8_t, TGHiddenStoriesRowKind) {
	TGHiddenStoriesRowKindPoster = 0,
};

@interface TGHiddenStoriesItem : NSObject

@property (nonatomic, readonly) TGHiddenStoriesRowKind kind;
@property (nonatomic, readonly, copy) NSString *reuseIdentifier;
@property (nonatomic, readonly) Class cellClass;

@property (nonatomic, readonly) int64_t posterId;
@property (nonatomic, readonly) BOOL posterIsChat;
@property (nonatomic, readonly, copy) NSString *titleText;

- (instancetype)initWithKind:(TGHiddenStoriesRowKind)kind
			 reuseIdentifier:(NSString *)reuseIdentifier
				   cellClass:(Class)cellClass
					posterId:(int64_t)posterId
				posterIsChat:(BOOL)posterIsChat
				   titleText:(NSString *)titleText NS_DESIGNATED_INITIALIZER;

- (instancetype)init NS_UNAVAILABLE;

@end
