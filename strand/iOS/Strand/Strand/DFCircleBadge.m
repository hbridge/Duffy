//
//  OFElementSquare.m
//  CocktailGuide
//
//  Created by Henry Bridge on 10/10/13.
//  Copyright (c) 2013 Old Fashioned Software. All rights reserved.
//

#import "DFCircleBadge.h"

@interface DFCircleBadge ()

@property (nonatomic) CGFloat fontSize;
@property (nonatomic, retain) UIFont *font;
@property (nonatomic) BOOL needsSizeRecalc;
@property (nonatomic) UIEdgeInsets insets;


@end

@implementation DFCircleBadge

static CGFloat const INSETS_DEFAULT = 1.0f;

- (void)awakeFromNib
{
  [self configure];
}

- (id)initWithFrame:(CGRect)frame
{
  self = [super initWithFrame:frame];
  if (self) {
    [self configure];
  }
  return self;
}

- (void)configure
{
  self.insets = UIEdgeInsetsMake(INSETS_DEFAULT, INSETS_DEFAULT, INSETS_DEFAULT, INSETS_DEFAULT);
  self.fontSize = 0.0;
  self.fontName = @"HelveticaNeue-Light";
}

- (void)setText:(NSString *)text
{
  if (![text isEqual:_text]) {
    _text = text;
    self.needsSizeRecalc = YES;
  }
}

- (void)setNeedsSizeRecalc:(BOOL)needsSizeRecalc
{
  _needsSizeRecalc = needsSizeRecalc;
  if (needsSizeRecalc) {
    [self setNeedsLayout];
    [self setNeedsDisplay];
  }
}

- (void)calculateFontSize
{
  if (self.bounds.size.width == 0 || self.bounds.size.height == 0|| !self.text || [self.text isEqualToString:@""] ) {
    self.fontSize = 0;
    return;
  }
  
  CGRect textArea = CGRectInset(self.frame, (self.insets.left + self.insets.right)/2.0, (self.insets.top + self.insets.bottom)/2.0);
  CGFloat curSize = self.maxFontSize ? self.maxFontSize : self.frame.size.height;
  NSMutableDictionary *attributes = [[NSMutableDictionary alloc] init];
  while (curSize >= 0.0) {
    [attributes setValue:[UIFont fontWithName:self.fontName size:curSize] forKey:NSFontAttributeName];
    CGSize textSize = [self.text sizeWithAttributes:attributes];
    if (textSize.width <= textArea.size.width && textSize.height <= textArea.size.height) {
      self.fontSize = curSize;
      if (curSize < 8.0) {
        DDLogWarn(@"%@ warning, fontsize: %.02f", self.class, curSize);
      }
      break;
    }
    curSize -= 1.0;
  }
}

- (void)setFrame:(CGRect)frame
{
  [super setFrame:frame];
  self.needsSizeRecalc = YES;
}

- (void)setFontSize:(CGFloat)fontSize {
  _fontSize = fontSize;
  self.font = [UIFont fontWithName:self.fontName size:self.fontSize];
  self.needsSizeRecalc = YES;
}

- (void)setFontName:(NSString *)newName
{
  _fontName = newName;
  self.font = [UIFont fontWithName:_fontName size:self.fontSize];
  self.needsSizeRecalc = YES;
}

- (void)drawRect:(CGRect)rect
{
  CGRect textRect;
  
  NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle alloc] init];
  paragraphStyle.alignment = NSTextAlignmentCenter;
  
  NSDictionary *attributes = [NSDictionary dictionaryWithObjectsAndKeys:
                              self.font, NSFontAttributeName,
                              [UIColor whiteColor], NSForegroundColorAttributeName,
                              paragraphStyle,NSParagraphStyleAttributeName,
                              nil];
  textRect.size = [self.text sizeWithAttributes:attributes];
  
  // Let's put that string in the center of the view
  CGPoint center = CGPointMake(rect.origin.x + rect.size.width/2,
                               rect.origin.y + rect.size.height/2);
  textRect.origin.x = center.x - textRect.size.width / 2.0;
  textRect.origin.y = floor(center.y - textRect.size.height / 2.0);
  [self.text drawInRect:textRect withAttributes:attributes];
}

- (void)layoutSubviews
{
  self.layer.cornerRadius = self.frame.size.width / 2.0;
  self.layer.masksToBounds = YES;
  CGFloat inset = self.frame.size.width * .125;
  self.insets = UIEdgeInsetsMake(inset, inset, inset, inset);
  
  [super layoutSubviews];
  if (self.needsSizeRecalc) {
    [self calculateFontSize];
    self.needsSizeRecalc = NO;
  }

}

@end
