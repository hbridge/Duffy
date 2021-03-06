//
//  DFOverlayNUXViewController.m
//  Strand
//
//  Created by Henry Bridge on 2/5/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFOverlayNUXViewController.h"
#import <Slash/Slash.h>
#import "UIColor+DFHelpers.h"

@interface DFOverlayNUXViewController ()

@end

@implementation DFOverlayNUXViewController

- (instancetype)initWithOverlayNUXType:(DFOverlayNuxType)nuxType
{
  self = [super init];
  if (self) {
    _nuxType = nuxType;
  }
  return self;
}


- (void)viewDidLoad {
  [super viewDidLoad];
  
  self.view.backgroundColor = [UIColor clearColor];
  self.explanatoryGradientView.gradientColors = @[
                                                  [UIColor colorWithRedByte:228 green:228 blue:228 alpha:1.0],
                                                  [UIColor colorWithRedByte:255 green:255 blue:255 alpha:1.0]
                                                  ];
  self.topImageView.backgroundColor = [UIColor colorWithRedByte:105 green:160 blue:224 alpha:1.0];
  [self configureContent];
  [self configureFontSizes];
}

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
  for (UILabel *label in @[self.subtitleLabel, self.explanatoryTextLabel]) {
    label.preferredMaxLayoutWidth = label.frame.size.width;
  }
}

- (void)configureContent
{
  self.titleLabel.text = @"Quick Share";
  self.subtitleLabel.text = @"A fast, easy way to share";
  self.topImageView.image = [UIImage imageNamed:@"Assets/Nux/NuxMatchImage"];
  
  NSError *error;
  NSString *markup = @""
  "<nuxHeaderText><strong>Location-Aware</strong></nuxHeaderText>\n"
  "<nuxText>Swap suggests friends who were nearby</nuxText>"
  "\n\n"
  "<nuxHeaderText><strong>Your Best Photos</strong></nuxHeaderText>\n"
  "<nuxText>Swap picks fun photos to share</nuxText>"
  ;
  self.explanatoryTextLabel.attributedText = [SLSMarkupParser
                                              attributedStringWithMarkup:markup
                                              style:[DFStrandConstants defaultTextStyle]
                                              error:&error];
  if (error) {
    DDLogError(@"%@ error parsing markup: %@", self.class, error);
  }
}

- (void)configureFontSizes
{
  CGFloat scaledDefaultFontSize = [UIFont systemFontSize]*[UIScreen mainScreen].bounds.size.width/240;
  CGFloat titleFontSize = 1.2 * scaledDefaultFontSize;
  CGFloat textFontSize = 0.9 * scaledDefaultFontSize;
  self.titleLabel.font = [self.titleLabel.font fontWithSize:titleFontSize];
  self.subtitleLabel.font = [self.subtitleLabel.font fontWithSize:textFontSize];
  
  
  NSMutableAttributedString *res = [self.explanatoryTextLabel.attributedText mutableCopy];
  
  [res beginEditing];
  __block BOOL found = NO;
  [res enumerateAttribute:NSFontAttributeName inRange:NSMakeRange(0, res.length) options:0 usingBlock:^(id value, NSRange range, BOOL *stop) {
    if (value) {
      UIFont *oldFont = (UIFont *)value;
      UIFont *newFont = [oldFont fontWithSize:textFontSize];
      [res removeAttribute:NSFontAttributeName range:range];
      [res addAttribute:NSFontAttributeName value:newFont range:range];
      found = YES;
    }
  }];
  if (!found) {
    // No font was found - do something else?
  }
  [res endEditing];
  
  
  self.explanatoryTextLabel.attributedText = res;
}

- (IBAction)closeButtonPressed:(id)sender {
  [self dismissViewControllerAnimated:NO completion:nil];
}


@end
