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
@property (nonatomic, retain) NSDictionary *firstNamesById;
@property (nonatomic, retain) NSDictionary *imagesById;
@property (nonatomic, retain) NSMutableDictionary *badgeImagesById;
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
  if (self.maxAbbreviationLength == 0)
    self.maxAbbreviationLength = 1;
  if (!self.nameLabelFont) {
    self.nameLabelFont = [UIFont fontWithName:@"HelveticaNeue-Bold" size:11];
  }
  
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

+ (id<NSCopying>)idForUser:(DFPeanutUserObject *)user
{
  if (user.id) return @(user.id);
  else return user.phone_number;
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
  NSMutableDictionary *firstNames = [[NSMutableDictionary alloc] initWithCapacity:users.count];
  NSMutableDictionary *images = [[NSMutableDictionary alloc] initWithCapacity:users.count];
  NSArray *allColors = [DFStrandConstants profilePhotoStackColors];
  for (NSUInteger i = 0; i < self.peanutUsers.count; i++) {
    //fill color
    DFPeanutUserObject *user = _peanutUsers[i];
    UIColor *color;
    if ([user isEqual:[DFPeanutUserObject TeamSwapUser]]) {
      color = [DFStrandConstants defaultBackgroundColor];
    } else {
      NSInteger numberForUser = [self numberForUser:user];
      NSUInteger colorIndex = abs((int)numberForUser % (int)[allColors count]);
      color = allColors[colorIndex];
    }
    fillColors[[self.class idForUser:user]] = color;
    
    //name
    NSString *abbreviation = @"";
    NSString *firstName = [user firstName];
    if (firstName.length > 0) {
      abbreviation = [[firstName
                       substringToIndex:MIN(self.maxAbbreviationLength, user.firstName.length)]
                      uppercaseString];
    }
    abbreviations[[self.class idForUser:user]] = abbreviation;
    firstNames[[self.class idForUser:user]] = firstName;
    
    //image
    UIImage *image = [user roundedThumbnailOfPointSize:CGSizeMake(self.profilePhotoWidth,
                                                                  self.profilePhotoWidth)];
    if (image)
      images[[self.class idForUser:user]] = image;
    
  }
  _fillColorsById = fillColors;
  _abbreviationsById = abbreviations;
  _firstNamesById = firstNames;
  _imagesById = images;
  
  [self sizeToFit];
  [self invalidateIntrinsicContentSize];
  [self setNeedsDisplay];
}

- (void)setColor:(UIColor *)color forUser:(DFPeanutUserObject *)user
{
  NSMutableDictionary *newFills = [[NSMutableDictionary alloc] initWithDictionary:self.fillColorsById];
  newFills[[self.class idForUser:user]] = color;
  _fillColorsById = newFills;
  [self setNeedsDisplay];
}

- (void)setBadgeImage:(UIImage *)badgeImage forUser:(DFPeanutUserObject *)user
{
  if (!self.badgeImagesById) self.badgeImagesById = [NSMutableDictionary new];
  if (badgeImage) {
    self.badgeImagesById[[self.class idForUser:user]] = badgeImage;
  } else {
    [self.badgeImagesById removeObjectForKey:[self.class idForUser:user]];
  }
  [self setNeedsDisplay];
}

- (void)reloadImages
{
  NSMutableDictionary *images = [NSMutableDictionary new];
  for (DFPeanutUserObject *user in self.peanutUsers) {
    UIImage *image = [user roundedThumbnailOfPointSize:CGSizeMake(self.profilePhotoWidth,
                                                                  self.profilePhotoWidth)];
    if (image)
      images[[self.class idForUser:user]] = image;
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

- (CGSize)intrinsicContentSize
{
  return [self sizeThatFits:CGSizeZero];
}

- (NSInteger)numberForUser:(DFPeanutUserObject *)user {
  if (user.id)
    return (NSInteger)user.id;
  
  return user.phone_number.hash;
}

- (CGSize)sizeThatFits:(CGSize)size
{
  if (self.peanutUsers.count == 0) return CGSizeZero;
  CGSize newSize = size;
  newSize.height = self.profilePhotoWidth + [self nameLabelHeight];
  newSize.width = (CGFloat)MIN(self.maxProfilePhotos + 1, self.peanutUsers.count) * self.profilePhotoWidth
  + MAX(self.peanutUsers.count - 1, 0) * 2.0;
  return newSize;
}

- (CGRect)rectForCircleAtIndex:(NSUInteger)index
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

- (CGFloat)nameLabelHeight
{
  if (self.nameMode != DFProfileStackViewNameShowAlways) return 0;
  
  return self.nameLabelFont.pointSize * [[UIScreen mainScreen] scale] + nameLabelMargin * 2.0;
  
}

- (void)drawRect:(CGRect)rect {
  CGContextRef context = UIGraphicsGetCurrentContext();
  
  for (NSUInteger i = 0; i < MIN(self.peanutUsers.count, _maxProfilePhotos); i++) {
    DFPeanutUserObject *user = self.peanutUsers[i];
    id userID = [self.class idForUser:user];
    UIColor *fillColor = self.fillColorsById[userID];
    NSString *abbreviation = self.abbreviationsById[userID];
    NSString *firstName = self.firstNamesById[userID];
    UIImage *image = self.imagesById[userID];
    
    CGRect circleRect = [self rectForCircleAtIndex:i];
    if (!image) {
      CGContextSetFillColorWithColor(context, fillColor.CGColor);
      CGContextFillEllipseInRect(context, circleRect);
      [self drawAbbreviationText:abbreviation inRect:circleRect context:context];
    } else {
      [image drawInRect:circleRect];
    }
    if (self.nameMode == DFProfileStackViewNameShowAlways) {
      [self drawNameText:firstName belowCircleRect:circleRect context:context];
    }
    UIImage *badgeImage = self.badgeImagesById[userID];
    if (badgeImage) {
      [self drawBadgeImage:badgeImage onCircleRect:circleRect context:context];
    }
  }
}

- (void)drawAbbreviationText:(NSString *)text inRect:(CGRect)rect context:(CGContextRef)context
{
  UILabel *label = [[UILabel alloc] initWithFrame:rect];
  label.textColor = [UIColor whiteColor];
  label.textAlignment = NSTextAlignmentCenter;
  label.text = text;
  label.font = [UIFont fontWithName:@"HelveticaNeue" size:ceil(rect.size.height)/2.0];
  [label drawTextInRect:rect];
}

const CGFloat nameLabelMargin = 2.0;

- (void)drawNameText:(NSString *)text belowCircleRect:(CGRect)circleRect context:(CGContextRef)context
{
  CGRect nameRect = circleRect;
  nameRect.origin.y = CGRectGetMaxY(circleRect) + nameLabelMargin;
  nameRect.size.height = self.nameLabelFont.pointSize;
  
  UILabel *label = [[UILabel alloc] initWithFrame:nameRect];
  label.textColor = [UIColor blackColor];
  label.textAlignment = NSTextAlignmentCenter;
  label.text = text;
  label.font = self.nameLabelFont;
  [label drawTextInRect:nameRect];
}

- (void)drawBadgeImage:(UIImage *)image onCircleRect:(CGRect)circleRect context:(CGContextRef)context
{
  CGRect badgeRect = CGRectMake(CGRectGetMaxX(circleRect) - image.size.width,
                                CGRectGetMaxY(circleRect) - image.size.height,
                                image.size.width,
                                image.size.height);
  [image drawInRect:badgeRect];
}


#pragma mark - Actions

- (void)tapped:(UITapGestureRecognizer *)sender
{
  if (self.nameMode == DFProfileStackViewNameModeNone) return;
  
  for (NSUInteger i = 0; i < MIN(self.peanutUsers.count, _maxProfilePhotos); i++) {
    CGRect rectForName = [self rectForCircleAtIndex:i];
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
