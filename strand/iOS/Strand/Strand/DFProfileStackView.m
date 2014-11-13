//
//  DFProfileStackView.m
//  Strand
//
//  Created by Henry Bridge on 11/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFProfileStackView.h"
#import "DFPeanutUserObject.h"

@interface DFProfileStackView()

@property (nonatomic, retain) NSArray *fillColors;

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
  [self setNameColors];
  [self setNeedsDisplay];
}

- (void)setMaxProfilePhotos:(NSUInteger)maxProfilePhotos
{
  _maxProfilePhotos = maxProfilePhotos;
  [self setNeedsDisplay];
}

- (void)setProfilePhotoWidth:(CGFloat)profilePhotoWidth
{
  _profilePhotoWidth = profilePhotoWidth;
  [self setNeedsDisplay];
}

- (void)setNameColors
{
  NSMutableArray *fillColors = [NSMutableArray new];
  NSArray *allColors = [DFStrandConstants profilePhotoStackColors];
  for (NSUInteger i = 0; i < self.peanutUsers.count; i++) {
    NSInteger numberForName = [self numberForUser:self.peanutUsers[i]];
    NSUInteger colorIndex = abs((int)numberForName % (int)[allColors count]);
    DDLogVerbose(@"User: %@ colorIndex:%@", self.peanutUsers[i], @(colorIndex));
    UIColor *color = allColors[colorIndex];
    [fillColors addObject:color];
  }
  _fillColors = fillColors;
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
    UIColor *fillColor = self.fillColors[i];
    NSString *abbreviation = @"";
    if (user.fullName.length > 0) {
      abbreviation = [user.fullName substringToIndex:1];
    }
    
    CGRect abbreviationRect = [self rectForIndex:i];
    CGContextSetFillColorWithColor(context, fillColor.CGColor);
    CGContextFillEllipseInRect(context, abbreviationRect);
    
    UILabel *label = [[UILabel alloc] initWithFrame:abbreviationRect];
    label.textColor = [UIColor whiteColor];
    label.textAlignment = NSTextAlignmentCenter;
    label.text = abbreviation;
    label.font = [UIFont fontWithName:@"HelveticaNeue" size:ceil(abbreviationRect.size.height)/2.0];
    [label drawTextInRect:abbreviationRect];
  }
}


@end
