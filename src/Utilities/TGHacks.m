#import "TGHacks.h"
#import <objc/runtime.h>

static const char *containerViewCustomLayoutDelegate = "containerViewCustomLayoutDelegate";

static void SwizzleInstanceMethodWithAnotherClass(Class c1, SEL orig, Class c2, SEL new) {
	Method origMethod = nil, newMethod = nil;

	origMethod = class_getInstanceMethod(c1, orig);
	newMethod = class_getInstanceMethod(c2, new);
	if ((origMethod != nil) && (newMethod != nil)) {
		if (class_addMethod(c1, orig, method_getImplementation(newMethod), method_getTypeEncoding(newMethod)))
			class_replaceMethod(c1, new, method_getImplementation(origMethod), method_getTypeEncoding(origMethod));
		else
			method_exchangeImplementations(origMethod, newMethod);
	} else
		NSLog(@"Attempt to swizzle nonexistent methods!");
}

@protocol TGLayoutContainerViewDelegate <NSObject>
- (void)layoutSubviews:(UIView *)view;
@end

#define TGFullscreenContainerClass(ClassName)                                                            \
	@interface ClassName : UIView                                                                        \
	@end                                                                                                 \
	@implementation ClassName                                                                            \
                                                                                                         \
	-(void)layoutSubviewsTG {                                                                            \
		id layoutDelegate = objc_getAssociatedObject(self, containerViewCustomLayoutDelegate);           \
		if (layoutDelegate != nil) {                                                                     \
			[(id<TGLayoutContainerViewDelegate>)layoutDelegate layoutSubviews:self];                     \
		} else {                                                                                         \
			static void (*impl)(id, SEL) = NULL;                                                         \
			static dispatch_once_t onceToken;                                                            \
			dispatch_once(&onceToken, ^{                                                                 \
				Method method = class_getInstanceMethod([ClassName class], @selector(layoutSubviewsTG)); \
				impl = (void (*)(id, SEL))method_getImplementation(method);                              \
			});                                                                                          \
                                                                                                         \
			if (impl)                                                                                    \
				impl(self, @selector(layoutSubviewsTG));                                                 \
		}                                                                                                \
	}                                                                                                    \
	@end

TGFullscreenContainerClass(TGLayoutContainerView)

	@implementation TGHacks

+ (void)setLayoutDelegateForContainerView:(id)view layoutDelegate:(id)layoutDelegate {
	objc_setAssociatedObject(view, containerViewCustomLayoutDelegate, layoutDelegate, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

+ (void)hackSetAnimationDuration {
	NSArray *classPairs = @[
		@[ @"UILayoutContainerView", [TGLayoutContainerView class] ],
	];

	for (NSArray *classPair in classPairs)
		SwizzleInstanceMethodWithAnotherClass(NSClassFromString(classPair[0]), @selector(layoutSubviews), classPair[1], @selector(layoutSubviewsTG));
}

@end
