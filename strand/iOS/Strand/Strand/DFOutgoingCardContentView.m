
//
//  DFSuggestionContentView.m
//  Strand
//
//  Created by Henry Bridge on 12/17/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFOutgoingCardContentView.h"
#import <MMPopLabel/MMPopLabel.h>


@interface DFOutgoingCardContentView()

@property (nonatomic) MMPopLabel *selectPeoplePopLabel;

@end

@implementation DFOutgoingCardContentView

- (void)awakeFromNib
{
  [super awakeFromNib];
  [self configurePopLabel];
  self.imageView.layer.cornerRadius = 4.0;
  self.imageView.layer.masksToBounds = YES;
}

- (IBAction)addButtonPressed:(id)sender {
  if (self.addHandler) self.addHandler();
}

- (void)configurePopLabel
{
  self.selectPeoplePopLabel = [MMPopLabel popLabelWithText:@"Select people first"];
  [self addSubview:self.selectPeoplePopLabel];
}

- (void)showAddPeoplePopup
{
  [self.selectPeoplePopLabel popAtView:self.addButton animatePopLabel:YES animateTargetView:YES];
}

- (void)dismissAddPeoplePopup
{
  [self.selectPeoplePopLabel dismiss];
}

@end
