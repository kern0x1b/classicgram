#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

NSDictionary *TGTrFormattedText(NSString * _Nullable text, NSArray * _Nullable entities);
NSDictionary * _Nullable TGTrPack(id _Nullable raw);
NSArray *TGTrPacks(NSDictionary * _Nullable target);
NSDictionary * _Nullable TGTrTranscript(id _Nullable raw);
NSDictionary * _Nullable TGTrNoteOfMessage(NSDictionary * _Nullable message);
id _Nullable TGTrStringValue(id _Nullable raw);

NS_ASSUME_NONNULL_END
