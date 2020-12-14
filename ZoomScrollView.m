//
//  ZoomScrollView.m
//  ZhongNanSandbox
//
//  Created by LeonJing on 2020/12/10.
//  Copyright © 2020 tc. All rights reserved.
//

#import "ZoomScrollView.h"

@interface ZoomScrollView () <UIGestureRecognizerDelegate>
@property(nonatomic, strong) UITapGestureRecognizer* tap;
@property(nonatomic, assign) CGRect initialImageFrame;
@property(nonatomic, assign) CGFloat imageAspectRatio;
@end

@implementation ZoomScrollView

- (void)dealloc
{
    [self stopObservingBoundsChange];
}

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self configure];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self configure];
    }
    return self;
}

- (void)setContentOffset:(CGPoint)contentOffset {
    CGSize contentSize = self.contentSize;
    CGSize scrollViewSize = self.bounds.size;
    CGPoint newContentOffset = contentOffset;
    
    if (contentSize.width < scrollViewSize.width) {
        newContentOffset.x = (contentSize.width - scrollViewSize.width) * 0.5;
    }
    
    if (contentSize.height < scrollViewSize.height) {
        newContentOffset.y = (contentSize.height - scrollViewSize.height) * 0.5;
    }
    
    [super setContentOffset:newContentOffset];
}

- (void)layoutSubviews {
    [super layoutSubviews];
    [self setupInitialImageFrame];
}

- (void) setupInitialImageFrame {
    if (nil != self.imageView && CGRectIsNull(self.initialImageFrame)) {
        CGSize imageViewSize = [self rectSizeFor:self.imageAspectRatio thatFits:self.bounds.size];
        self.initialImageFrame = CGRectMake(0, 0, imageViewSize.width, imageViewSize.height);
        self.imageView.frame = self.initialImageFrame;
        self.contentSize = self.initialImageFrame.size;
    } else {
        return;
    }
}

- (void) configure {
    self.initialImageFrame = CGRectNull;
    self.showsVerticalScrollIndicator = NO;
    self.showsHorizontalScrollIndicator = NO;
    [self startObservingBoundsChange];
}

- (CGSize) rectSizeFor:(CGFloat)aspectRatio thatFits:(CGSize)size {
    CGFloat containerWidth = size.width;
    CGFloat containerHeight = size.height;
    CGFloat resultWidth = 0;
    CGFloat resultHeight = 0;
    
    if (aspectRatio <= 0 || containerHeight <= 0) {
        return size;
    }
    
    if (containerWidth / containerHeight >= aspectRatio) {
        resultHeight = containerHeight;
        resultWidth = containerHeight * aspectRatio;
    } else {
        resultWidth = containerWidth;
        resultHeight = containerWidth / aspectRatio;
    }
    
    return CGSizeMake(resultWidth, resultHeight);
}

- (void) scaleImageForTransitionFrom:(CGRect) oldBounds to:(CGRect)newBounds {
    UIImageView* imageView = self.imageView;
    if (nil == imageView) {
        return;
    }
    
    CGPoint oldContentOffset = CGPointMake(oldBounds.origin.x,oldBounds.origin.y);
    CGSize oldSize = oldBounds.size;
    CGSize newSize = newBounds.size;
    CGSize containedImageSizeOld = [self rectSizeFor:self.imageAspectRatio thatFits:oldSize];
    CGSize containedImageSizeNew = [self rectSizeFor:self.imageAspectRatio thatFits:newSize];
    
    if (containedImageSizeOld.height <= 0) {
        containedImageSizeOld = containedImageSizeNew;
    }
    
    CGFloat orientationRatio = containedImageSizeNew.height / containedImageSizeOld.height;
    CGAffineTransform transform = CGAffineTransformMakeScale(orientationRatio, orientationRatio);
    self.imageView.frame = CGRectApplyAffineTransform(imageView.frame, transform);
    self.contentSize = imageView.frame.size;
    
    CGFloat xOffset = (oldContentOffset.x + oldSize.width * 0.5) * orientationRatio - newSize.width * 0.5;
    CGFloat yOffset = (oldContentOffset.y + oldSize.height * 0.5) * orientationRatio - newSize.height * 0.5;
    
    xOffset -= MAX(xOffset + newSize.width - self.contentSize.width, 0);
    yOffset -= MAX(yOffset + newSize.height - self.contentSize.height, 0);
    xOffset -= MAX(xOffset, 0);
    yOffset -= MAX(yOffset, 0);
    
    self.contentOffset = CGPointMake(xOffset, yOffset);
}

- (void) startObservingBoundsChange {
    [self addObserver:self forKeyPath:@"bounds" options:NSKeyValueObservingOptionOld | NSKeyValueObservingOptionNew context:@"LEON_ZSV"];
}

- (void) stopObservingBoundsChange {
    [self removeObserver:self forKeyPath:@"bounds" context:@"LEON_ZSV"];
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == @"LEON_ZSV") {
        CGRect oldRect = [[change objectForKey:NSKeyValueChangeOldKey] CGRectValue];
        CGRect newRect = [[change objectForKey:NSKeyValueChangeNewKey] CGRectValue];
        if (!CGSizeEqualToSize(oldRect.size, newRect.size)) {
            [self scaleImageForTransitionFrom:oldRect to:newRect];
        }
    } else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

- (void) tapToZoom:(UIGestureRecognizer*)sender {
    if (sender.state != UIGestureRecognizerStateEnded) {
        return;
    }
    if (self.zoomScale > self.minimumZoomScale) {
        [self setZoomScale:self.minimumZoomScale animated:YES];
    } else {
        UIImageView* imageView = self.imageView;
        if (nil == imageView) {
            return;
        }
        CGPoint tapLocation = [sender locationInView:imageView];
        CGFloat zoomRectWidth = imageView.frame.size.width / self.maximumZoomScale;
        CGFloat zoomRectHeight = imageView.frame.size.height / self.maximumZoomScale;
        CGFloat zoomRectX = tapLocation.x - zoomRectWidth * 0.5;
        CGFloat zoomRectY = tapLocation.y - zoomRectHeight * 0.5;
        CGRect zoomRect = CGRectMake(zoomRectX,zoomRectY,zoomRectWidth,zoomRectHeight);
        [self zoomToRect:zoomRect animated:YES];
    }
}

- (CGFloat)imageAspectRatio {
    UIImage* image = self.imageView.image;
    if (image) {
        return image.size.width / image.size.height;
    } else {
        return 1;
    }
}

- (void) setImageView:(UIImageView *)imageView {
    if (_imageView != imageView) {
        UIImageView* oldValue = _imageView;
        
        _imageView = imageView;
        
        [oldValue removeGestureRecognizer:self.tap];
        [oldValue removeFromSuperview];
        self.initialImageFrame = CGRectNull;

        _imageView.userInteractionEnabled = YES;
        [_imageView addGestureRecognizer:self.tap];
        [self addSubview:_imageView];
    }
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return otherGestureRecognizer == self.panGestureRecognizer;
}

- (UITapGestureRecognizer *) tap {
    if (nil == _tap) {
        UITapGestureRecognizer* t = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(tapToZoom:)];
        t.numberOfTapsRequired = 2;
        t.delegate = self;
        
        _tap = t;
    }
    return _tap;
}
@end
