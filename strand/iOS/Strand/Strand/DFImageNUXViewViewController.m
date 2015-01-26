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

+ (DFImageNUXViewViewController *)nuxWithTitle:(NSString *)title
                                         image:(UIImage *)image
                               explanationText:(NSString *)explanation
                                   buttonTitle:(NSString *)buttonTitle
{
  DFImageNUXViewViewController *vc = [[DFImageNUXViewViewController alloc] init];
  vc.titleLabel.text = title;
  vc.imageView.image = image;
  vc.explanationLabel.text = explanation;
  [vc.button setTitle:buttonTitle forState:UIControlStateNormal];
  return vc;
}

- (IBAction)buttonPressed:(id)sender {
  [self completedWithUserInfo:nil];
}
@end
