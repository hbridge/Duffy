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
@property (nonatomic, retain) NSArray *abbreviations;

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

  NSMutableArray *fillColors = [[NSMutableArray alloc] initWithCapacity:users.count];
  NSMutableArray *abbreviations = [[NSMutableArray alloc] initWithCapacity:users.count];
  NSArray *allColors = [DFStrandConstants profilePhotoStackColors];
  for (NSUInteger i = 0; i < self.peanutUsers.count; i++) {
    //fill color
    DFPeanutUserObject *user = _peanutUsers[i];
    NSInteger numberForUser = [self numberForUser:user];
    NSUInteger colorIndex = abs((int)numberForUser % (int)[allColors count]);
    UIColor *color = allColors[colorIndex];
    [fillColors addObject:color];
    
    //name
    NSString *abbreviation = @"";
    if (user.fullName.length > 0) {
      abbreviation = [user.display_name substringToIndex:1];
    }
    [abbreviations addObject:abbreviation];
  }
  _fillColors = fillColors;
  _abbreviations = abbreviations;
  
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
    UIColor *fillColor = self.fillColors[i];
    NSString *abbreviation = self.abbreviations[i];
    
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
