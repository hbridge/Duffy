//
//  DFProfileStackView.m
//  Strand
//
//  Created by Henry Bridge on 11/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFProfileStackView.h"
#import <WYPopoverController/WYPopoverController.h>
#import "DFPeanutUserObject.h"
#import "UIImage+RoundedCorner.h"
#import "UIImage+Resize.h"
#import "DFPeanutFeedDataManager.h"

@interface DFProfileStackView()

@property (nonatomic, retain) NSDictionary *fillColorsById;
@property (nonatomic, retain) NSDictionary *abbreviationsById;
@property (nonatomic, retain) NSDictionary *firstNamesById;
@property (nonatomic, retain) NSDictionary *imagesById;
@property (nonatomic, retain) NSMutableDictionary *badgeImagesById;
@property (nonatomic, retain) UIView *popTargetView;
@property (nonatomic, retain) MMPopLabel *popLabel;
@property (nonatomic) CGFloat profilePhotoWidth;
@property (nonatomic) CGRect lastFrame;
@property (nonatomic, retain) WYPopoverController *morePopover;

@end

static CGFloat deleteButtonSize = 15;
static CGFloat deleteButtonMargin = 4;

@implementation DFProfileStackView

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

- (void)awakeFromNib
{
  [super awakeFromNib];
  [self configure];
}


- (void)configure
{
  if (self.profilePhotoWidth == 0.0)
    self.profilePhotoWidth = 35.0;
  if (self.maxAbbreviationLength == 0)
    self.maxAbbreviationLength = 1;
  if (!self.nameLabelFont) {
    self.nameLabelFont = [UIFont fontWithName:@"HelveticaNeue-Bold" size:11];
  }
  if (!self.nameLabelColor) {
    self.nameLabelColor = [UIColor blackColor];
  }
  if (self.photoMargins == 0.0) {
    self.photoMargins = 2.0;
  }
  if (self.nameLabelVerticalMargin == 0.0) self.nameLabelVerticalMargin = 2.0;
  
  [self layoutIfNeeded];
  
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
  else if (user.phone_number) return user.phone_number;
  return @(0);
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
  NSArray *allColors = [DFStrandConstants profilePhotoStackColors];
  for (NSUInteger i = 0; i < self.peanutUsers.count; i++) {
    //fill color
    DFPeanutUserObject *user = _peanutUsers[i];
    UIColor *color;
    if ([user isEqual:[DFPeanutUserObject TeamSwapUser]]) {
      color = [DFStrandConstants teamSwapUserColor];
    } else {
      NSInteger numberForUser = [self numberForUser:user];
      NSUInteger colorIndex = abs((int)numberForUser % (int)[allColors count]);
      color = allColors[colorIndex];
    }
    fillColors[[self.class idForUser:user]] = color;
    
    //name
    NSString *abbreviation = @"?";
    NSString *firstName = [user firstName];
    if (firstName.length > 0) {
      abbreviation = [[firstName
                       substringToIndex:MIN(self.maxAbbreviationLength, user.firstName.length)]
                      uppercaseString];
    }
    abbreviations[[self.class idForUser:user]] = abbreviation;
    
    // override name here so abbreviation isn't "Y"
    if (user.id == [[DFUser currentUser] userID]) {
      firstName = @"You";
    }
    firstNames[[self.class idForUser:user]] = [firstName isNotEmpty] ? firstName : user.phone_number;
  }
  
  _fillColorsById = fillColors;
  _abbreviationsById = abbreviations;
  _firstNamesById = firstNames;
  
  [self sizeToFit];
  [self reloadImages];
  
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
  if (!user) return;
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
  newSize.height = self.frame.size.height;
  NSUInteger numProfiles = [self maxPeanutUsersToDraw];
  NSUInteger numSpaces = MAX(self.peanutUsers.count - 1, 0);
  newSize.width = (CGFloat)numProfiles * self.profilePhotoWidth
  + numSpaces * self.photoMargins;
  newSize.width += self.deleteButtonsVisible ? deleteButtonMargin : 0;
  return newSize;
}

- (NSUInteger)maxPeanutUsersToDraw
{
  return self.maxProfilePhotos ? MIN(self.maxProfilePhotos, self.peanutUsers.count) : self.peanutUsers.count;
}

- (CGFloat)profilePhotoWidth
{
  return self.frame.size.height - [self otherContentHeight];
}

- (CGRect)rectForCircleAtIndex:(NSUInteger)index
{
  CGRect rect = CGRectMake((CGFloat)index * self.profilePhotoWidth,
                           self.deleteButtonsVisible ? deleteButtonMargin : 0,
                           self.profilePhotoWidth,
                           self.profilePhotoWidth);
  if (index > 0) {
    rect.origin.x = rect.origin.x + (CGFloat)index * self.photoMargins;
  }
  return rect;
}

- (CGFloat)otherContentHeight
{
  if (!self.showNames && !self.deleteButtonsVisible) return 0;
  
  CGFloat height = 0.0;
  if (self.showNames) {
    height += self.nameLabelFont.pointSize + self.nameLabelVerticalMargin * 2;
  }
  
  if (self.deleteButtonsVisible) {
    height += deleteButtonMargin;
  }
  
  return height;
}

- (BOOL)shouldDrawUserAtIndex:(NSUInteger)i inRect:(CGRect)rect
{
  NSUInteger numUsersThatFitInRect = [self numUsersThatFitInRect:rect];
  return (i < numUsersThatFitInRect - 1 ||
          (i == [self maxPeanutUsersToDraw] - 1 && i == numUsersThatFitInRect - 1));
}

- (NSUInteger)numUsersThatFitInRect:(CGRect)rect
{
  CGFloat numWithoutSpaces = floor(rect.size.width / self.profilePhotoWidth);
  if (numWithoutSpaces * self.profilePhotoWidth + (numWithoutSpaces - 1) * self.photoMargins > rect.size.width) {
    return (NSUInteger)numWithoutSpaces - 1;
  }
  return (NSUInteger)numWithoutSpaces;
}

- (void)drawRect:(CGRect)rect {
  
  for (NSUInteger i = 0; i < [self maxPeanutUsersToDraw]; i++) {
    CGRect circleRect = [self rectForCircleAtIndex:i];
    
    if (CGRectGetMaxX(circleRect) > rect.size.width) break;
    if ([self shouldDrawUserAtIndex:i inRect:rect]) {
      // if this is the last user or the next circle fits entirely in the bounds, draw a user
      DFPeanutUserObject *user = self.peanutUsers[i];
      [self drawProfileForPeanutUser:user inCircleRect:circleRect];
      if (self.deleteButtonsVisible) [self drawDeleteButtonInCircleRect:circleRect];
    } else {
      [self drawElipsisInCircleRect:circleRect];
    }
  }
}

- (void)drawProfileForPeanutUser:(DFPeanutUserObject *)user inCircleRect:(CGRect)circleRect
{
  CGContextRef context = UIGraphicsGetCurrentContext();
  
  id userID = [self.class idForUser:user];
  UIColor *fillColor = self.fillColorsById[userID];
  NSString *abbreviation = self.abbreviationsById[userID];
  NSString *firstName = self.firstNamesById[userID];
  UIImage *image = self.imagesById[userID];
  
  if (abbreviation.length == 0 && !image) {
    image = [UIImage imageNamed:@"Assets/Icons/NoRecipientAvatar"];
  }
  
  if (!image) {
    CGContextSetFillColorWithColor(context, fillColor.CGColor);
    CGContextFillEllipseInRect(context, circleRect);
    [self drawAbbreviationText:abbreviation inRect:circleRect context:context];
  } else {
    [image drawInRect:circleRect];
  }
  if (self.showNames) {
    [self drawNameText:firstName belowCircleRect:circleRect context:context];
  }
  UIImage *badgeImage = self.badgeImagesById[userID];
  if (badgeImage) {
    [self drawBadgeImage:badgeImage onCircleRect:circleRect context:context];
  }
}
- (void)drawDeleteButtonInCircleRect:(CGRect)circleRect
{
  CGRect deleteRect = [DFProfileStackView rectForDeleteButtonInCircle:circleRect];
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextSetFillColorWithColor(context, [[[DFStrandConstants strandBlue] colorWithAlphaComponent:1.0] CGColor]);
  CGContextFillEllipseInRect(context, deleteRect);
  CGContextDrawImage(context, deleteRect, [[[UIImage imageNamed:@"Assets/Icons/DeletePersonX"]
                                            imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                                           CGImage]);

}

+ (CGRect)rectForDeleteButtonInCircle:(CGRect)circleRect
{
  CGRect deleteRect = CGRectMake(CGRectGetMaxX(circleRect) - deleteButtonSize + deleteButtonMargin,
                                 0,
                                 deleteButtonSize,
                                 deleteButtonSize);
  return deleteRect;
}


- (void)drawElipsisInCircleRect:(CGRect)circleRect
{
  CGContextRef context = UIGraphicsGetCurrentContext();
  CGContextSetFillColorWithColor(context, [[UIColor lightGrayColor] CGColor]);
  CGContextFillEllipseInRect(context, circleRect);
  [self drawAbbreviationText:@"..." inRect:circleRect context:context];
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

- (void)drawNameText:(NSString *)text belowCircleRect:(CGRect)circleRect context:(CGContextRef)context
{
  CGRect nameRect = circleRect;
  nameRect.origin.y = CGRectGetMaxY(circleRect) + self.nameLabelVerticalMargin;
  nameRect.size.height = self.nameLabelFont.pointSize;
  
  UILabel *label = [[UILabel alloc] initWithFrame:nameRect];
  label.textColor = self.nameLabelColor;
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
  if (![self.delegate respondsToSelector:@selector(profileStackView:peanutUserTapped:)]) return;
  for (NSUInteger i = 0; i < [self maxPeanutUsersToDraw]; i++) {
    CGPoint tapPoint = [sender locationInView:self];

    CGRect rectForName = [self rectForCircleAtIndex:i];
    if (self.deleteButtonsVisible) {
      CGRect rectForDeleteButton = [DFProfileStackView rectForDeleteButtonInCircle:rectForName];
      if (CGRectContainsPoint(rectForDeleteButton, tapPoint)
          && [self shouldDrawUserAtIndex:i inRect:self.bounds]) {
        if ([self.delegate respondsToSelector:@selector(profileStackView:peanutUserDeleted:)]) {
          [self.delegate profileStackView:self peanutUserDeleted:self.peanutUsers[i]];
          return;
        }
      }
    }
    
    if (CGRectContainsPoint(rectForName, tapPoint)) {
      if ([self shouldDrawUserAtIndex:i inRect:self.bounds]) {
        DFPeanutUserObject *user = self.peanutUsers[i];
        [self.delegate profileStackView:self peanutUserTapped:user];
      } else {
        [self moreUsersCircleTappedInRect:rectForName];
      }
    }
  }
}

- (void)popLabelAtRect:(CGRect)rect withText:(NSString *)text
{
  CGRect rectInSuper = [self.superview convertRect:rect fromView:self];
  self.popTargetView = [[UIView alloc] initWithFrame:rectInSuper];
  self.popTargetView.backgroundColor = [UIColor clearColor];
  self.popTargetView.userInteractionEnabled = NO;
  [self.superview addSubview:self.popTargetView];
  
  [self.popLabel dismiss];
  self.popLabel = [MMPopLabel popLabelWithText:text];
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

- (void)moreUsersCircleTappedInRect:(CGRect)rect
{
  NSUInteger numUsersThatFitInRect = [self numUsersThatFitInRect:self.bounds];
  NSRange range = (NSRange){numUsersThatFitInRect - 1, self.peanutUsers.count - numUsersThatFitInRect + 1};
  NSArray *peanutUsers = [self.peanutUsers subarrayWithRange:range];
  
  DFUserListViewController *ulistController = [[DFUserListViewController alloc] initWithUsers:peanutUsers];
  ulistController.delegate = self;
  self.morePopover =  [[WYPopoverController alloc]
                                   initWithContentViewController:ulistController];
  [self.morePopover presentPopoverFromRect:rect
                                    inView:self
                  permittedArrowDirections:WYPopoverArrowDirectionUp
                                  animated:YES
                                   options:WYPopoverAnimationOptionFadeWithScale
                                completion:nil];
}

- (void)pickerController:(DFPeoplePickerViewController *)pickerController
didFinishWithPickedContacts:(NSArray *)peanutContacts
{
  DFPeanutContact *contact = peanutContacts.firstObject;
  DFPeanutUserObject *user = [[DFPeanutFeedDataManager sharedManager]
                              userWithPhoneNumber:contact.phone_number];
  [self.delegate profileStackView:self peanutUserTapped:user];
}

- (void)dismissedPopLabel:(MMPopLabel *)popLabel
{
  [popLabel removeFromSuperview];
  [self.popTargetView removeFromSuperview];
}

- (void)layoutSubviews
{
  [super layoutSubviews];
  if (!CGRectEqualToRect(self.frame, self.lastFrame)) {
    self.lastFrame = self.frame;
    [self invalidateIntrinsicContentSize];
    [self reloadImages];
  }
}

- (void)setDeleteButtonsVisible:(BOOL)deleteButtonsVisible
{
  if (deleteButtonsVisible == _deleteButtonsVisible) return;
  
  _deleteButtonsVisible = deleteButtonsVisible;
  [self setNeedsDisplay];
}


@end
