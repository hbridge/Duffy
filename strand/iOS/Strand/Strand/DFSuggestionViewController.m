//
//  DFSuggestionViewController.m
//  Strand
//
//  Created by Henry Bridge on 11/25/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSuggestionViewController.h"
#import "DFPeanutFeedObject.h"
#import "DFImageManager.h"

@interface DFSuggestionViewController ()

@end

@implementation DFSuggestionViewController

@synthesize suggestionFeedObject = _suggestionFeedObject;

- (void)viewDidLoad {
  [super viewDidLoad];
  if (!CGRectEqualToRect(self.frame, CGRectZero)) {
    self.view.frame = self.frame;
    [self.view layoutIfNeeded];
  }
  // Do any additional setup after loading the view from its nib.
  [self configureWithSuggestion:self.suggestionFeedObject];
}

- (void)setFrame:(CGRect)frame
{
  _frame = frame;
  self.view.frame = frame;
  [self.view layoutIfNeeded];
}

- (void)didReceiveMemoryWarning {
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (void)setSuggestionFeedObject:(DFPeanutFeedObject *)suggestionFeedObject
{
  _suggestionFeedObject = suggestionFeedObject;
  if (self.view) {
    [self configureWithSuggestion:suggestionFeedObject];
  }
}

- (void)configureWithSuggestion:(DFPeanutFeedObject *)suggestion
{
  if (suggestion.actors.count == 0) self.profileWithContextView.hidden = YES;
  self.profileWithContextView.profileStackView.peanutUsers = suggestion.actors;
  self.profileWithContextView.titleLabel.text = [NSString stringWithFormat:@"%@ %@ photos",
                                                 suggestion.actorsString,
                                                 suggestion.actors.count > 1 ? @"have" : @"has"];
  [self.profileWithContextView.subtitleLabel removeFromSuperview];
  self.topLabel.text = suggestion.placeAndRelativeTimeString;
  
  DFPeanutFeedObject *firstSuggestedPhoto = [[suggestion leafNodesFromObjectOfType:DFFeedObjectPhoto] firstObject];
  [[DFImageManager sharedManager] imageForID:firstSuggestedPhoto.id
                                   pointSize:self.imageView.frame.size
                                 contentMode:DFImageRequestContentModeAspectFill
                                deliveryMode:DFImageRequestOptionsDeliveryModeOpportunistic completion:^(UIImage *image) {
                                  dispatch_async(dispatch_get_main_queue(), ^{
                                    self.imageView.image = image;
                                    [self.imageView setNeedsDisplay];
                                  });
                                }];
  [self.view setNeedsLayout];
}

- (IBAction)requestButtonPressed:(id)sender {
  if (self.requestButtonHandler) self.requestButtonHandler();
}
@end
