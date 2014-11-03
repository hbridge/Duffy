//
//  DFSelectablePhotoViewCell.m
//  Strand
//
//  Created by Henry Bridge on 8/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSelectablePhotoViewCell.h"
#import "DFStrandConstants.h"

@implementation DFSelectablePhotoViewCell

- (void)awakeFromNib
{
  [super awakeFromNib];
  
  self.contentView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
  self.contentView.translatesAutoresizingMaskIntoConstraints = YES;
  
  self.countView.backgroundColor = [DFStrandConstants photoCellBadgeColor];
  [self setupLongPress];
}

- (void)setupLongPress
{
  UILongPressGestureRecognizer *longpressRecognizer
  = [[UILongPressGestureRecognizer alloc]
     initWithTarget:self action:@selector(selectPhotoCellLongPressed:)];
  [self.selectPhotoButton addGestureRecognizer:longpressRecognizer];
}

- (void)setCount:(NSUInteger)count
{
  _count = count;
  if (count > 0) {
    self.countView.text = [@(count) stringValue];
    self.countView.hidden = NO;
  } else {
    self.countView.hidden = YES;
  }
}

- (void)setShowTickMark:(BOOL)showTickMark
{
  self.selectPhotoButton.selected = showTickMark;
  [self setNeedsLayout];
}

- (BOOL)showTickMark
{
  return self.selectPhotoButton.selected;
}

- (IBAction)selectPhotoButtonPressed:(UIButton *)sender {
  if (self.delegate)
    [self.delegate cell:self selectPhotoButtonPressed:sender];
}

- (void)selectPhotoCellLongPressed:(UILongPressGestureRecognizer *)sender {
  if (sender.state == UIGestureRecognizerStateBegan) {
    DDLogVerbose(@"Cell longpressed");
    if ([self.delegate respondsToSelector:@selector(cellLongpressed:)]) {
      [self.delegate cellLongpressed:self];
    }
  }
  
}


@end
