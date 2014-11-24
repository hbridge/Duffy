//
//  DFSwapSuggestionTableViewCell.m
//  Strand
//
//  Created by Henry Bridge on 11/21/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSwapSuggestionTableViewCell.h"

@implementation DFSwapSuggestionTableViewCell

- (void)awakeFromNib {
  [super awakeFromNib];
  self.previewImageView.layer.cornerRadius = 0;
  [self.gradientView setGradientColors:@[
                                         [UIColor clearColor],
                                         [UIColor darkGrayColor]
                                         ]];
  self.gradientView.backgroundColor = [UIColor clearColor];
  self.profilePhotoStackView.maxProfilePhotos = 3;
  self.selectionStyle = UITableViewCellSelectionStyleNone;
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}

+ (CGFloat)height
{
  return 202.0;
}

+ (UIEdgeInsets)edgeInsets
{
  return UIEdgeInsetsMake(0, 15, 0, 15);
}


const CGFloat VerticalPadding = 4;


- (void)drawRect:(CGRect)rect
{
  [super drawRect:rect];
  
  CGContextRef ctx = UIGraphicsGetCurrentContext();
  CGContextSetLineWidth(ctx, 1.0);
  CGContextSetStrokeColorWithColor(ctx, [[[UIColor whiteColor] colorWithAlphaComponent:0.7] CGColor]);
  
  //horiz line at top of buttons
  CGFloat topY = floor(self.buttonBar.frame.origin.y) + 0.5;
  CGPoint topLeft = CGPointMake(0, topY);
  CGPoint topRight = CGPointMake(rect.size.width, topY);
  CGPoint topPoints[2] = {topLeft, topRight};
  CGContextStrokeLineSegments(ctx, topPoints, 2);
  
  // vertical line between buttons
  topY = floor(self.requestButton.frame.origin.y);
  CGRect buttonFrame = [self convertRect:self.requestButton.frame fromView:self.buttonBar];
  CGFloat requestBottomY = floor(CGRectGetMaxY(buttonFrame)) - VerticalPadding;
  //CGFloat requestLeftX = floor(CGRectGetMinX(self.requestButton.frame));
  CGFloat requestTop = floor(CGRectGetMinY(buttonFrame)) + VerticalPadding;
  CGFloat requestRightX = floor(CGRectGetMaxX(buttonFrame)) + 1.5;

  CGPoint rightTop = CGPointMake(requestRightX, requestTop);
  CGPoint rightBottom = CGPointMake(requestRightX, requestBottomY);
  CGPoint rightLine[2] = {rightTop, rightBottom};
  CGContextStrokeLineSegments(ctx, rightLine, 2);
}

- (void)layoutSubviews
{
  [self.profilePhotoStackView sizeToFit];
  [super layoutSubviews];
}


- (IBAction)requestButtonPressed:(id)sender {
  if (self.requestButtonHandler) self.requestButtonHandler();
}

- (IBAction)skipButtonPressed:(id)sender {
  if (self.skipButtonHandler) self.skipButtonHandler();
}
@end
