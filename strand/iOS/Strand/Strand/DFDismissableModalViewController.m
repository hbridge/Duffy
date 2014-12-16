//
//  DFDismissableModalViewController.m
//  Strand
//
//  Created by Henry Bridge on 12/16/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFDismissableModalViewController.h"

@interface DFDismissableModalViewController ()

@end

@implementation DFDismissableModalViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)viewWillAppear:(BOOL)animated
{
  [self setNeedsStatusBarAppearanceUpdate];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (BOOL)prefersStatusBarHidden
{
  return YES;
}

- (void)setContentView:(UIView *)contentView
{
  _contentView = contentView;
  [self.view insertSubview:contentView belowSubview:self.closeButton];
}

- (void)viewWillLayoutSubviews
{
  [super viewWillLayoutSubviews];
  self.contentView.frame = self.view.bounds;
}

- (IBAction)closeButtonPressed:(id)sender {
  [self.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

+ (void)presentWithRootController:(UIViewController *)rootController
                         inParent:(UIViewController *)parent
{
  DFDismissableModalViewController *viewController = [[DFDismissableModalViewController alloc] init];
  viewController.contentView = rootController.view;
  [viewController addChildViewController:rootController];
  
  
  [parent presentViewController:viewController animated:YES completion:nil];
}


@end
