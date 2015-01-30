//
//  DFImageNUXViewViewController.m
//  Strand
//
//  Created by Henry Bridge on 1/23/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFImageNUXViewViewController.h"
#import <SAMGradientView/SAMGradientView.h>

@interface DFImageNUXViewViewController ()

@end

@implementation DFImageNUXViewViewController

- (instancetype)initWithTitle:(NSString *)title
                        image:(UIImage *)image
              explanationText:(NSString *)explanation
                  buttonTitle:(NSString *)buttonTitle
{
  self = [super initWithNibName:NSStringFromClass([DFImageNUXViewViewController class])  bundle:nil];
  if (self) {
    self.titleText = title;
    self.image = image;
    self.explanation = explanation;
    self.buttonTitle = buttonTitle;
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  SAMGradientView *gradientView = (SAMGradientView *)self.view;
  gradientView.gradientColors = @[[UIColor colorWithWhite:1.0 alpha:1.0],
                                  [UIColor colorWithWhite:0.9 alpha:1.0]];
  self.titleLabel.text = self.titleText;
  self.imageView.image = self.image;
  self.explanationLabel.text = self.explanation;
  [self.button setTitle:self.buttonTitle forState:UIControlStateNormal];
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  [self.navigationController setNavigationBarHidden:YES];
  [self setNeedsStatusBarAppearanceUpdate];
}

- (void)setTitleText:(NSString *)titleText
{
  _titleText = titleText;
  self.titleLabel.text = titleText;
}

- (void)setImage:(UIImage *)image
{
  _image = image;
  self.imageView.image = image;
}

- (void)setExplanation:(NSString *)explanation
{
  _explanation = explanation;
  self.explanationLabel.text = explanation;
}

- (void)setButtonTitle:(NSString *)buttonTitle
{
  _buttonTitle = buttonTitle;
  [self.button setTitle:buttonTitle forState:UIControlStateNormal];
}

- (IBAction)buttonPressed:(id)sender {
  self.button.enabled = NO;
  [self completedWithUserInfo:nil];
}

- (BOOL)prefersStatusBarHidden
{
  return YES;
}
@end
