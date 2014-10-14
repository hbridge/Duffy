//
//  DFAddPhotosViewController.m
//  Strand
//
//  Created by Henry Bridge on 10/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFAddPhotosViewController.h"

@interface DFAddPhotosViewController ()

@end

@implementation DFAddPhotosViewController


- (instancetype)initWithSuggestions:(NSArray *)suggestedSections invite:(DFPeanutFeedObject *)invite
{
  self = [self initWithSuggestions:suggestedSections];
  if (self) {
    _inviteObject = invite;
  }
  return self;
}

- (instancetype)initWithSuggestions:(NSArray *)suggestions
{
  self = [super initWithSuggestions:suggestions];
  if (self) {
    [self configureNavBar];
  }
  return self;
}

- (void)configureNavBar
{
  self.navigationItem.title = @"Select Photos";
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                            initWithTitle:@"Next"
                                            style:UIBarButtonItemStylePlain
                                            target:self
                                            action:@selector(nextPressed:)];
}

#pragma mark - Actions

- (void)nextPressed:(id)sender {

}


@end
