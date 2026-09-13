#import <UIKit/UIKit.h>

@interface TGFileDetailsViewController : UITableViewController <UIActionSheetDelegate, UIDocumentInteractionControllerDelegate>

@property (nonatomic, assign) long long fileId;
@property (nonatomic, copy) NSString *fileName;
@property (nonatomic, copy) NSString *fileType;
@property (nonatomic, copy) NSString *mimeType;
@property (nonatomic, assign) int64_t chatId;
@property (nonatomic, assign) int64_t messageId;
@property (nonatomic, strong) NSDictionary *file;
@property (nonatomic, copy) NSString *extension;
@property (nonatomic, assign) long long prefixSize;
@property (nonatomic, assign) BOOL busy;
@property (nonatomic, strong) NSMutableArray *infoRows;
@property (nonatomic, strong) NSArray *sheetActions;
@property (nonatomic, strong) UIDocumentInteractionController *documentController;
@property (nonatomic, copy) NSString *exportPath;
@property (nonatomic, strong) NSFileHandle *exportHandle;
@property (nonatomic, assign) long long exportOffset;
@property (nonatomic, assign) long long exportTotal;

@end
