#import "TGQRImage.h"
#import "TGQRCode.h"
#import "quirc/quirc.h"
#import <QuartzCore/QuartzCore.h>

static const int kQRQuietModules = 4;

UIImage *TGQRCodeImage(NSString *text, CGFloat maximumSide) {
	if (!text.length || maximumSide <= 0)
		return nil;

	const char *utf8 = [text UTF8String];
	if (!utf8)
		return nil;

	TGQRMatrix matrix;
	if (TGQRCodeEncodeString(utf8, QUIRC_ECC_LEVEL_M, &matrix) != 0)
		return nil;

	CGFloat screenScale = 1.0f;
	if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)])
		screenScale = [UIScreen mainScreen].scale;
	if (screenScale < 1.0f)
		screenScale = 1.0f;

	NSInteger across = matrix.size + kQRQuietModules * 2;
	NSInteger module = (int)((maximumSide * screenScale) / across);
	if (module < 1)
		module = 1;
	NSInteger pixels = module * across;

	CGColorSpaceRef grey = CGColorSpaceCreateDeviceGray();
	CGContextRef context = CGBitmapContextCreate(NULL, (size_t)pixels,
		(size_t)pixels, 8, (size_t)pixels, grey, (CGBitmapInfo)kCGImageAlphaNone);
	CGColorSpaceRelease(grey);
	if (!context) {
		TGQRMatrixRelease(&matrix);
		return nil;
	}

	CGContextSetGrayFillColor(context, 1.0f, 1.0f);
	CGContextFillRect(context, CGRectMake(0, 0, pixels, pixels));
	CGContextTranslateCTM(context, 0, pixels);
	CGContextScaleCTM(context, 1, -1);
	CGContextSetGrayFillColor(context, 0.0f, 1.0f);

	for (NSInteger row = 0; row < matrix.size; row++) {
		NSInteger start = -1;
		for (NSInteger column = 0; column <= matrix.size; column++) {
			BOOL dark = column < matrix.size && matrix.modules[row * matrix.size + column];
			if (dark && start < 0)
				start = column;
			if (!dark && start >= 0) {
				CGContextFillRect(context, CGRectMake((start + kQRQuietModules) * module, (row + kQRQuietModules) * module, (column - start) * module, module));
				start = -1;
			}
		}
	}
	TGQRMatrixRelease(&matrix);

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
