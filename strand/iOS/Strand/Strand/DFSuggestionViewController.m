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
#import "DFPeanutFeedDataManager.h"

@interface DFSuggestionViewController ()

@end

@implementation DFSuggestionViewController

- (void)viewDidLoad {
  [super viewDidLoad];
  if (!CGRectEqualToRect(self.frame, CGRectZero)) {
    self.view.frame = self.frame;
    [self.view layoutIfNeeded];
  }
  
  self.imageView.layer.cornerRadius = 4.0;
  self.imageView.layer.masksToBounds = YES;
  
  self.footerView.backgroundColor = [UIColor clearColor];
  self.footerView.gradientColors = @[
                                     [[UIColor whiteColor] colorWithAlphaComponent:0],
                                     [UIColor whiteColor]
                                       ];
  
  [self configureWithSuggestion:self.suggestionFeedObject withPhoto:self.photoFeedObject];
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

- (void)configureWithSuggestion:(DFPeanutFeedObject *)suggestion withPhoto:(DFPeanutFeedObject *)photo
{
  self.suggestionFeedObject = suggestion;
  if (suggestion.actors.count == 0) self.bottomLabel.hidden = YES;
  self.bottomLabel.text = [NSString stringWithFormat:@"Send %@ this photo?",
                                                 suggestion.actorsString];
  self.topLabel.text = suggestion.placeAndRelativeTimeString;
  
  [[DFImageManager sharedManager] imageForID:photo.id
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

- (IBAction)yesButtonPressed:(id)sender {
  if (self.yesButtonHandler) self.yesButtonHandler();
}

- (IBAction)noButtonPressed:(id)sender {
  if (self.noButtonHandler) self.noButtonHandler();
}

@end
