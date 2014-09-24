//
//  DFCollectionTableViewCell.m
//  Strand
//
//  Created by Henry Bridge on 8/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFCreateStrandTableViewCell.h"
#import "DFStrandConstants.h"

@implementation DFCreateStrandTableViewCell

- (void)awakeFromNib
{
  [super awakeFromNib];
  
  self.selectionStyle = UITableViewCellSelectionStyleNone;
  
}

+ (DFCreateStrandTableViewCell *)cellWithStyle:(DFCreateStrandCellStyle)style
{
  DFCreateStrandTableViewCell *cell = [[[UINib nibWithNibName:[self description] bundle:nil] instantiateWithOwner:nil options:nil] firstObject];
  [cell configureWithStyle:style];
  return cell;
}

- (void)configureWithStyle:(DFCreateStrandCellStyle)style
{
  
  if (style == DFCreateStrandCellStyleInvite) {
    self.contentView.backgroundColor = [DFStrandConstants inviteCellBackgroundColor];
    self.callToActionLabel.text = @"Accept";
  }
  
  if (style == DFCreateStrandCellStyleSuggestionNoPeople) {
    [self.peopleLabel removeFromSuperview];
    [self.peopleExplanationLabel removeFromSuperview];
    self.contextLabel.font = [self.contextLabel.font fontWithSize:14.0];
  }
  
  [self layoutSubviews];
  
}


@end
