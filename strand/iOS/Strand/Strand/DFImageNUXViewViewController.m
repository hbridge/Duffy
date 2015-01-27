//
//  DFImageNUXViewViewController.m
//  Strand
//
//  Created by Henry Bridge on 1/23/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFImageNUXViewViewController.h"

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
  
  self.titleLabel.text = self.titleText;
  self.imageView.image = self.image;
  self.explanationLabel.text = self.explanation;
  [self.button setTitle:self.buttonTitle forState:UIControlStateNormal];
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
  [self completedWithUserInfo:nil];
}
@end
