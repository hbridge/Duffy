//
//  DFProfileStackView.m
//  Strand
//
//  Created by Henry Bridge on 11/12/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFProfileStackView.h"

@interface DFProfileStackView()

@property (nonatomic, retain) NSArray *fillColors;

@end

@implementation DFProfileStackView

- (void)awakeFromNib
{
  [super awakeFromNib];
  
  self.maxProfilePhotos = 4;
  self.profilePhotoWidth = 35.0;
}

- (void)setNames:(NSArray *)names
{
  _names = names;
  [self setNameColors];
  [self setNeedsDisplay];
}

- (void)setNameColors
{
  NSMutableArray *fillColors = [NSMutableArray new];
  NSArray *allColors = [DFStrandConstants profilePhotoStackColors];
  for (NSUInteger i = 0; i < self.names.count; i++) {
    NSInteger numberForName = [self numberForName:self.names[i]];
    NSUInteger colorIndex = abs((int)numberForName % (int)[allColors count]);
    UIColor *color = allColors[colorIndex];
    [fillColors addObject:color];
  }
  _fillColors = fillColors;
}

- (NSInteger)numberForName:(NSString *)name {
  NSInteger result;
  for (NSUInteger i = 0; i < name.length; i++) {
    char c = [name characterAtIndex:i];
    result += (NSUInteger)c;
  }
  return result;
}

- (CGSize)sizeThatFits:(CGSize)size
{
  CGSize newSize = size;
  newSize.height = self.profilePhotoWidth;
  newSize.width = (CGFloat)MIN(self.maxProfilePhotos + 1, self.names.count) * self.profilePhotoWidth
  + MAX(self.names.count - 1, 0) * 2.0;
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
  
  for (NSUInteger i = 0; i< self.names.count; i++) {
    NSString *name = self.names[i];
    UIColor *fillColor = self.fillColors[i];
    NSString *abbreviation = @"";
    if (name.length > 0) {
      abbreviation = [name substringToIndex:1];
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
