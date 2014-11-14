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

@end

@implementation DFProfileStackView

- (void)awakeFromNib
{
  [super awakeFromNib];
  
  if (self.maxProfilePhotos == 0)
    self.maxProfilePhotos = 4;
  if (self.profilePhotoWidth == 0.0)
    self.profilePhotoWidth = 35.0;
}

- (void)setPeanutUsers:(NSArray *)users
{
  _peanutUsers = users;

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
  newSize.width = (CGFloat)MIN(self.maxProfilePhotos + 1, self.peanutUsers.count) * self.profilePhotoWidth
  + MAX(self.peanutUsers.count - 1, 0) * 2.0;
  return newSize;
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


@end
