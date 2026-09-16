#import "TGQRImage.h"
#include <qrcodegen.h>
#import <QuartzCore/QuartzCore.h>

static const int kQRQuietModules = 4;

UIImage *TGQRCodeImage(NSString *text, CGFloat maximumSide) {
	if (!text.length || maximumSide <= 0)
		return nil;

	const char *utf8 = [text UTF8String];
	if (!utf8)
		return nil;

	uint8_t temporary[qrcodegen_BUFFER_LEN_MAX];
	uint8_t code[qrcodegen_BUFFER_LEN_MAX];
	if (!qrcodegen_encodeText(utf8, temporary, code, qrcodegen_Ecc_MEDIUM,
			qrcodegen_VERSION_MIN, qrcodegen_VERSION_MAX, qrcodegen_Mask_AUTO, false))
		return nil;
	int size = qrcodegen_getSize(code);

	CGFloat screenScale = 1.0f;
	if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)])
		screenScale = [UIScreen mainScreen].scale;
	if (screenScale < 1.0f)
		screenScale = 1.0f;

	NSInteger across = size + kQRQuietModules * 2;
	NSInteger module = (int)((maximumSide * screenScale) / across);
	if (module < 1)
		module = 1;
	NSInteger pixels = module * across;

	CGColorSpaceRef grey = CGColorSpaceCreateDeviceGray();
	CGContextRef context = CGBitmapContextCreate(NULL, (size_t)pixels,
		(size_t)pixels, 8, (size_t)pixels, grey, (CGBitmapInfo)kCGImageAlphaNone);
	CGColorSpaceRelease(grey);
	if (!context)
		return nil;

	CGContextSetGrayFillColor(context, 1.0f, 1.0f);
	CGContextFillRect(context, CGRectMake(0, 0, pixels, pixels));
	CGContextTranslateCTM(context, 0, pixels);
	CGContextScaleCTM(context, 1, -1);
	CGContextSetGrayFillColor(context, 0.0f, 1.0f);

	for (int row = 0; row < size; row++) {
		int start = -1;
		for (int column = 0; column <= size; column++) {
			BOOL dark = column < size && qrcodegen_getModule(code, column, row);
			if (dark && start < 0)
				start = column;
			if (!dark && start >= 0) {
				CGContextFillRect(context, CGRectMake((start + kQRQuietModules) * module, (row + kQRQuietModules) * module, (column - start) * module, module));
				start = -1;
			}
		}
	}

	CGImageRef bitmap = CGBitmapContextCreateImage(context);
	CGContextRelease(context);
	if (!bitmap)
		return nil;

	UIImage *image = [UIImage imageWithCGImage:bitmap scale:screenScale
								   orientation:UIImageOrientationUp];
	CGImageRelease(bitmap);
	return image;
}

@interface TGQRCodeView ()
@property (nonatomic, strong) UIImageView *codeView;
@property (nonatomic, strong) NSString *drawnText;
@property (nonatomic, assign) CGFloat drawnSide;
@end

@implementation TGQRCodeView

- (id)initWithFrame:(CGRect)frame {
	self = [super initWithFrame:frame];
	if (!self)
		return nil;
	self.backgroundColor = [UIColor whiteColor];
	self.layer.cornerRadius = 4;
	self.layer.borderWidth = 1;
	self.layer.borderColor = [UIColor colorWithWhite:0.72f alpha:1.0f].CGColor;
	self.clipsToBounds = YES;
	self.codeView = [[UIImageView alloc] initWithFrame:CGRectZero];
	[self addSubview:self.codeView];
	return self;
}

- (void)setText:(NSString *)text {
	if (text == _text || [text isEqualToString:_text])
		return;
	_text = [text copy];
	self.drawnText = nil;
	[self setNeedsLayout];
}

- (void)layoutSubviews {
	[super layoutSubviews];
	CGFloat side = MIN(self.bounds.size.width, self.bounds.size.height);
	if (side <= 0)
		return;
	if (!self.text.length) {
		self.codeView.image = nil;
		self.drawnText = nil;
		return;
	}
	if (![self.drawnText isEqualToString:self.text] || self.drawnSide != side) {
		self.codeView.image = TGQRCodeImage(self.text, side);
		self.drawnText = self.text;
		self.drawnSide = side;
	}
	CGSize size = self.codeView.image.size;
	self.codeView.frame = CGRectMake((int)((self.bounds.size.width - size.width) / 2),
		(int)((self.bounds.size.height - size.height) / 2),
		size.width, size.height);
}

- (CGSize)sizeThatFits:(CGSize)size {
	CGFloat side = MIN(size.width, size.height);
	UIImage *image = TGQRCodeImage(self.text, side);
	if (!image)
		return CGSizeZero;
	return CGSizeMake(image.size.width, image.size.height);
}

@end
