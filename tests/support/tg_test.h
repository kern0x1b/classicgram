#ifndef TG_HOST_TESTS_TG_TEST_H
#define TG_HOST_TESTS_TG_TEST_H

#import <stdio.h>
#import <math.h>

typedef struct {
	int checkCount;
	int failureCount;
} TGTestOutcome;

#define TGTestOutcomeZero ((TGTestOutcome){0, 0})

#define TGTestExpectTrue(outcomePtr, condition, description) do { \
	(outcomePtr)->checkCount++; \
	if (!(condition)) { \
		(outcomePtr)->failureCount++; \
		fprintf(stdout, "       %s:%d  %s\n", __FILE__, __LINE__, description); \
	} \
} while (0)

#define TGTestExpectEqualLongLong(outcomePtr, actual, expected, description) \
	TGTestExpectTrue(outcomePtr, (long long)(actual) == (long long)(expected), description)

#define TGTestExpectEqualInteger(outcomePtr, actual, expected, description) \
	TGTestExpectTrue(outcomePtr, (long)(actual) == (long)(expected), description)

#define TGTestExpectEqualDouble(outcomePtr, actual, expected, tolerance, description) \
	TGTestExpectTrue(outcomePtr, fabs((double)(actual) - (double)(expected)) <= (tolerance), description)

typedef TGTestOutcome (*TGTestCaseFunction)(void);

typedef struct {
	const char *name;
	TGTestCaseFunction function;
} TGTestCaseEntry;

#endif
