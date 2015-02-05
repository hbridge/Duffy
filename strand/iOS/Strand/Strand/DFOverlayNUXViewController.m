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
  [self configureContent];
}

- (void)configureContent
{
  self.titleLabel.text = @"Swapomatic";
  self.subtitleLabel.text = @"A fast, easy way to share";
  self.topImageView.image = [UIImage imageNamed:@"Assets/Nux/NuxMatchImage"];
  
  NSError *error;
  NSString *markup = @""
  "<nuxHeaderText><strong>Your Best Photos</strong></nuxHeaderText>\n"
  "<nuxText>Swap picks fun photos to share</nuxText>"
  "\n\n"
  "<nuxHeaderText><strong>Less Work</strong></nuxHeaderText>\n"
  "<nuxText>Swap suggests friends who were nearby</nuxText>"
  ;
  self.explanatoryTextLabel.attributedText = [SLSMarkupParser
                                              attributedStringWithMarkup:markup
                                              style:[DFStrandConstants defaultTextStyle]
                                              error:&error];
  if (error) {
    DDLogError(@"%@ error parsing markup: %@", self.class, error);
  }
}


@end
