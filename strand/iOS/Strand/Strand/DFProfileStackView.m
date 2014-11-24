//
//  DFProfileStackView.m
//  Strand
//
//  Created by Henry Bridge on 11/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFProfileStackView.h"
#import "DFPeanutUserObject.h"
#import "UIImage+RoundedCorner.h"
#import "UIImage+Resize.h"

@interface DFProfileStackView()

@property (nonatomic, retain) NSDictionary *fillColorsById;
@property (nonatomic, retain) NSDictionary *abbreviationsById;
@property (nonatomic, retain) NSDictionary *imagesById;
@property (nonatomic, retain) UIView *popTargetView;
@property (nonatomic, retain) MMPopLabel *popLabel;

@end

@implementation DFProfileStackView

- (void)awakeFromNib
{
  [super awakeFromNib];
  
  if (self.maxProfilePhotos == 0)
    self.maxProfilePhotos = 4;
  if (self.profilePhotoWidth == 0.0)
    self.profilePhotoWidth = 35.0;
  
  UITapGestureRecognizer *tapRecognizer = [[UITapGestureRecognizer alloc]
                                           initWithTarget:self
                                           action:@selector(tapped:)];
  [self addGestureRecognizer:tapRecognizer];
}

- (void)setPeanutUser:(DFPeanutUserObject *)user
{
  NSArray *users = user ? @[user] : @[];
  [self setPeanutUsers:users];
  if (users.count == 0) {
    DDLogWarn(@"%@ asked to show a nil user", self.class);
  }
}

- (void)setPeanutUsers:(NSArray *)users
{
  _peanutUsers = users;

  dispatch_async(dispatch_get_main_queue(), ^{
    [self.popLabel removeFromSuperview];
    [self.popTargetView removeFromSuperview];
  });
  NSMutableDictionary *fillColors = [[NSMutableDictionary alloc] initWithCapacity:users.count];
  NSMutableDictionary *abbreviations = [[NSMutableDictionary alloc] initWithCapacity:users.count];
  NSMutableDictionary *images = [[NSMutableDictionary alloc] initWithCapacity:users.count];
  NSArray *allColors = [DFStrandConstants profilePhotoStackColors];
  for (NSUInteger i = 0; i < self.peanutUsers.count; i++) {
    //fill color
    DFPeanutUserObject *user = _peanutUsers[i];
    NSInteger numberForUser = [self numberForUser:user];
    NSUInteger colorIndex = abs((int)numberForUser % (int)[allColors count]);
    UIColor *color = allColors[colorIndex];
    fillColors[@(user.id)] = color;
    
    //name
    NSString *abbreviation = @"";
    if ([user firstName].length > 0) {
      abbreviation = [[[user firstName] substringToIndex:1] uppercaseString];
    }
    abbreviations[@(user.id)] = abbreviation;
    
    //image
    UIImage *image = [user roundedThumbnailOfPointSize:CGSizeMake(self.profilePhotoWidth,
                                                                  self.profilePhotoWidth)];
    if (image)
      images[@(user.id)] = image;
    
  }
  _fillColorsById = fillColors;
  _abbreviationsById = abbreviations;
  _imagesById = images;
  
  [self sizeToFit];
  [self setNeedsDisplay];
}

- (void)reloadImages
{
  NSMutableDictionary *images = [NSMutableDictionary new];
  for (DFPeanutUserObject *user in self.peanutUsers) {
    UIImage *image = [user roundedThumbnailOfPointSize:CGSizeMake(self.profilePhotoWidth,
                                                                  self.profilePhotoWidth)];
    if (image)
      images[@(user.id)] = image;
  }
  self.imagesById = images;
}

- (void)setMaxProfilePhotos:(NSUInteger)maxProfilePhotos
{
  _maxProfilePhotos = maxProfilePhotos;
  [self setNeedsDisplay];
}

- (void)setProfilePhotoWidth:(CGFloat)profilePhotoWidth
{
  if (profilePhotoWidth != _profilePhotoWidth) {
  _profilePhotoWidth = profilePhotoWidth;
    [self reloadImages];
    [self setNeedsDisplay];
  }
}

- (NSInteger)numberForUser:(DFPeanutUserObject *)user {
  return (NSInteger)user.id;
}

- (CGSize)sizeThatFits:(CGSize)size
{
  CGSize newSize = size;
  newSize.height = self.profilePhotoWidth;
  NSUInteger lastIndex = MIN(self.peanutUsers.count, self.maxProfilePhotos) - 1;
  CGRect lastFrame = [self rectForIndex:lastIndex];
  return CGSizeMake(CGRectGetMaxX(lastFrame), lastFrame.size.height);
}

- (CGRect)rectForIndex:(NSUInteger)index
{
  CGRect rect = CGRectMake((CGFloat)index * self.profilePhotoWidth,
                           0,
                           self.profilePhotoWidth,
                           self.profilePhotoWidth);
  if (index > 0) {
    rect.origin.x = rect.origin.x + (CGFloat)index * 2.0;
  }
  return rect;
}

- (void)drawRect:(CGRect)rect {
  CGContextRef context = UIGraphicsGetCurrentContext();
  
  for (NSUInteger i = 0; i < MIN(self.peanutUsers.count, _maxProfilePhotos); i++) {
    DFPeanutUserObject *user = self.peanutUsers[i];
    UIColor *fillColor = self.fillColorsById[@(user.id)];
    NSString *abbreviation = self.abbreviationsById[@(user.id)];
    UIImage *image = self.imagesById[@(user.id)];
    
    CGRect abbreviationRect = [self rectForIndex:i];
    if (!image) {
      CGContextSetFillColorWithColor(context, fillColor.CGColor);
      CGContextFillEllipseInRect(context, abbreviationRect);
      UILabel *label = [[UILabel alloc] initWithFrame:abbreviationRect];
      label.textColor = [UIColor whiteColor];
      label.textAlignment = NSTextAlignmentCenter;
      label.text = abbreviation;
      label.font = [UIFont fontWithName:@"HelveticaNeue" size:ceil(abbreviationRect.size.height)/2.0];
      [label drawTextInRect:abbreviationRect];
    } else {
      [image drawInRect:abbreviationRect];
    }
  }
}


#pragma mark - Actions

- (void)tapped:(UITapGestureRecognizer *)sender
{
  if (!self.shouldShowNameLabel) return;
  
  for (NSUInteger i = 0; i < MIN(self.peanutUsers.count, _maxProfilePhotos); i++) {
    CGRect rectForName = [self rectForIndex:i];
    CGPoint tapPoint = [sender locationInView:self];
    if (CGRectContainsPoint(rectForName, tapPoint)) {
      [self iconTappedForPeanutUser:self.peanutUsers[i] inRect:rectForName];
    }
  }
}

- (void)iconTappedForPeanutUser:(DFPeanutUserObject *)peanutUser inRect:(CGRect)rect
{
  CGRect rectInSuper = [self.superview convertRect:rect fromView:self];
  self.popTargetView = [[UIView alloc] initWithFrame:rectInSuper];
  self.popTargetView.backgroundColor = [UIColor clearColor];
  self.popTargetView.userInteractionEnabled = NO;
  [self.superview addSubview:self.popTargetView];
  
  [self.popLabel dismiss];
  self.popLabel = [MMPopLabel popLabelWithText:peanutUser.fullName];
  [self.superview addSubview:self.popLabel];
  [self.popLabel setNeedsLayout];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
    [self.popLabel popAtView:self.popTargetView animatePopLabel:YES animateTargetView:NO];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      [self.popLabel dismiss];
    });
  });
  self.popLabel.delegate = self;
  
}

- (void)dismissedPopLabel:(MMPopLabel *)popLabel
{
  [popLabel removeFromSuperview];
  [self.popTargetView removeFromSuperview];
}

@end
