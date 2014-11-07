//
//  DFPhotoPickerHeaderReusableView.m
//  Strand
//
//  Created by Henry Bridge on 10/23/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFPhotoPickerHeaderReusableView.h"

@implementation DFPhotoPickerHeaderReusableView

- (void)awakeFromNib {
  self.badgeIconText.textColor = [DFStrandConstants defaultBackgroundColor];
}

- (IBAction)shareButtonPressed:(id)sender {
  self.shareCallback();
}

- (IBAction)removeSuggestionButtonPressed:(UIButton *)sender {
  self.removeSuggestionCallback();
}

- (void)configureWithStyle:(DFPhotoPickerHeaderStyle)style
{
  if (!(style & DFPhotoPickerHeaderStyleLocation)) {
    [self.locationLabel removeFromSuperview];
  }
  
  if (!(style & DFPhotoPickerHeaderStyleBadge)) {
    [self.badgeIconText removeFromSuperview];
    [self.badgeIconView removeFromSuperview];
    [self.removeSuggestionButton removeFromSuperview];
  }
}

+ (CGFloat)heightForStyle:(DFPhotoPickerHeaderStyle)style
{
  DFPhotoPickerHeaderReusableView *reusableView = [UINib instantiateViewWithClass:[self class]];
  [reusableView configureWithStyle:style];
  CGFloat minHeight = [reusableView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
  
  return minHeight;
}


@end
