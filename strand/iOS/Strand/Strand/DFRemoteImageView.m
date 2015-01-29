//
//  DFRemoteImageView.m
//  Strand
//
//  Created by Henry Bridge on 1/12/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFRemoteImageView.h"
#import "DFAnalytics.h"

@interface DFRemoteImageView()

@property (nonatomic) CGSize lastRequestedImageSize;

@end


@implementation DFRemoteImageView

- (instancetype)init
{
  self = [super init];
  if (self) {
    [self configure];
  }
  return self;
}

- (instancetype)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    [self configure];
  }
  return self;
}

- (instancetype)initWithImage:(UIImage *)image
{
  self = [super initWithImage:image];
  if (self) {
    [self configure];
  }
  return self;
}

- (void)configure
{
  // activity indicator
  self.activityView = [UIActivityIndicatorView new];
  self.activityView.activityIndicatorViewStyle = UIActivityIndicatorViewStyleGray;
  [self addSubview:self.activityView];
  self.activityView.translatesAutoresizingMaskIntoConstraints = NO;
  [self addConstraint:[NSLayoutConstraint constraintWithItem:self.activityView
                                                   attribute:NSLayoutAttributeCenterX
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:self
                                                   attribute:NSLayoutAttributeCenterX
                                                  multiplier:1
                                                    constant:0]];
  [self addConstraint:[NSLayoutConstraint constraintWithItem:self.activityView
                                                   attribute:NSLayoutAttributeCenterY
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:self
                                                   attribute:NSLayoutAttributeCenterY
                                                  multiplier:1
                                                    constant:0]];
  
  
  // error label
  self.errorLabel = [UILabel new];
  self.errorLabel.text = @"Could not load image";
  self.errorLabel.textColor = [UIColor lightGrayColor];
  self.errorLabel.font = [UIFont systemFontOfSize:15.0];
  [self addSubview:self.errorLabel];
  [self.errorLabel invalidateIntrinsicContentSize];
  self.errorLabel.translatesAutoresizingMaskIntoConstraints = NO;
  [self addConstraint:[NSLayoutConstraint constraintWithItem:self.errorLabel
                                                   attribute:NSLayoutAttributeCenterX
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:self
                                                   attribute:NSLayoutAttributeCenterX
                                                  multiplier:1
                                                    constant:0]];
  [self addConstraint:[NSLayoutConstraint constraintWithItem:self.errorLabel
                                                   attribute:NSLayoutAttributeCenterY
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:self
                                                   attribute:NSLayoutAttributeCenterY
                                                  multiplier:1
                                                    constant:0]];

  
  // reload button
  self.reloadButton = [UIButton new];
  [self addSubview:self.reloadButton];
  [self.reloadButton setTitle:@" Retry" forState:UIControlStateNormal];
  [self.reloadButton setImage:[[UIImage imageNamed:@"Assets/Icons/RefreshButtonIcon"]
                               imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                     forState:UIControlStateNormal];
  self.reloadButton.tintColor = [DFStrandConstants strandBlue];
  [self.reloadButton setTitleColor:[DFStrandConstants strandBlue] forState:UIControlStateNormal];
  self.reloadButton.titleLabel.font = [UIFont systemFontOfSize:13.0];
  [self.reloadButton sizeToFit];
  
  self.reloadButton.translatesAutoresizingMaskIntoConstraints = NO;
  [self addConstraint:[NSLayoutConstraint constraintWithItem:self.reloadButton
                                                   attribute:NSLayoutAttributeCenterX
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:self
                                                   attribute:NSLayoutAttributeCenterX
                                                  multiplier:1
                                                    constant:0]];
  [self addConstraint:[NSLayoutConstraint constraintWithItem:self.reloadButton
                                                   attribute:NSLayoutAttributeTop
                                                   relatedBy:NSLayoutRelationEqual
                                                      toItem:self.errorLabel
                                                   attribute:NSLayoutAttributeBottom
                                                  multiplier:1
                                                    constant:8]];
  
  [self.reloadButton addTarget:self
                        action:@selector(reloadPressed:)
              forControlEvents:UIControlEventTouchUpInside];
  self.userInteractionEnabled = YES;
}

- (void)setIsLoading:(BOOL)isLoading error:(BOOL)isError
{
  if (isLoading) {
    [self.activityView startAnimating];
    self.reloadButton.hidden = YES;
    self.errorLabel.hidden = YES;
  } else {
    [self.activityView stopAnimating];
    if (isError) {
      self.errorLabel.hidden = NO;
      self.reloadButton.hidden = NO;
    } else {
      self.errorLabel.hidden =YES;
      self.reloadButton.hidden = YES;
    }
  }
}

- (void)setImage:(UIImage *)image
{
  [super setImage:image];
  if (image) {
   [self.activityView stopAnimating];
  } else {
    [self.activityView startAnimating];
  }
}

- (void)loadImageWithID:(DFPhotoIDType)photoID deliveryMode:(DFImageRequestDeliveryMode)deliveryMode
{
  [self setIsLoading:YES error:NO];
  
  self.photoID = photoID;
  self.deliveryMode = deliveryMode;
  
  DFImageRequestContentMode contentMode = DFImageRequestContentModeAspectFill;
  if (self.contentMode == UIViewContentModeScaleAspectFit)
    contentMode = DFImageRequestContentModeAspectFit;
  
  CGSize requestSize = self.frame.size;
  self.lastRequestedImageSize = requestSize;
  [[DFImageManager sharedManager]
   imageForID:photoID
   pointSize:self.frame.size
   contentMode:DFImageRequestContentModeAspectFill
   deliveryMode:deliveryMode
   completion:^(UIImage *image) {
     if (!CGSizeEqualToSize(requestSize, self.lastRequestedImageSize)) return;
     dispatch_async(dispatch_get_main_queue(), ^{
       if (!self.image) {
         self.alpha = 0.0;
         [UIView animateWithDuration:0.2 animations:^{
           self.alpha = 1.0;
         }];
       }
       self.image = image;
       [self setIsLoading:NO error:image ? NO : YES];
     });
   }];
}

- (void)reloadPressed:(UIButton *)sender
{
  [self loadImageWithID:self.photoID deliveryMode:self.deliveryMode];
  [DFAnalytics logPhotoLoadRetried];
}

@end
