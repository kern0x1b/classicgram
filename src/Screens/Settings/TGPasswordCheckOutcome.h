#import <Foundation/Foundation.h>

typedef enum {
	TGPasswordCheckOutcomeAccepted = 0,
	TGPasswordCheckOutcomeWrongPassword,
	TGPasswordCheckOutcomeNotChecked
} TGPasswordCheckOutcome;

TGPasswordCheckOutcome TGPasswordCheckOutcomeForError(NSString *errorMessage, BOOL gotAnswer);
