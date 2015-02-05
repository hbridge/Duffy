//
//  DFDismissableModalViewController.m
//  Strand
//
//  Created by Henry Bridge on 12/16/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFDismissableModalViewController.h"
#import "UIImageEffects.h"
#import "UIView+DFExtensions.h"

@interface DFDismissableModalViewController ()

@end

@implementation DFDismissableModalViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
  self.backgroundImageView.image = self.backgroundImage;
  [self.closeButton setImage:[[UIImage imageNamed:@"Assets/Icons/XIcon"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
                              forState:UIControlStateNormal];
}

- (void)setBackgroundImage:(UIImage *)backgroundImage
{
  _backgroundImage = backgroundImage;
  self.backgroundImageView.image = backgroundImage;
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

- (UIStatusBarStyle)preferredStatusBarStyle
{
  return [DFStrandConstants preferredStatusBarStyle];
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
  CATransition* transition = [CATransition animation];
  transition.duration = 0.3;
  transition.type = kCATransitionFade;
  [self.view.window.layer addAnimation:transition forKey:kCATransition];
  
  [self.presentingViewController dismissViewControllerAnimated:NO completion:nil];
}

+ (void)presentWithRootController:(UIViewController *)rootController
                         inParent:(UIViewController *)parent
{
  [self presentWithRootController:rootController inParent:parent animated:YES];
}

+ (void)presentWithRootController:(UIViewController *)rootController
                         inParent:(UIViewController *)parent
                         animated:(BOOL)animated
{
  [self presentWithRootController:rootController
                         inParent:parent
                  backgroundStyle:DFDismissableModalViewControllerBackgroundStyleBlur animated:animated];
}

+ (void)presentWithRootController:(UIViewController *)rootController
                         inParent:(UIViewController *)parent
                  backgroundStyle:(DFDismissableModalViewControllerBackgroundStyle)backgroundStyle
                         animated:(BOOL)animated
{
  DFDismissableModalViewController *viewController = [[DFDismissableModalViewController alloc] init];
  viewController.contentView = rootController.view;
  [viewController addChildViewController:rootController];
  
  UIView *backgroundView = parent.view;
  UIGraphicsBeginImageContextWithOptions(backgroundView.bounds.size, NO, 0);
  BOOL snapshotSuccess = [backgroundView drawViewHierarchyInRect:backgroundView.bounds afterScreenUpdates:NO];
  UIImage* backgroundImage = UIGraphicsGetImageFromCurrentImageContext();
  UIGraphicsEndImageContext();

  if (backgroundStyle == DFDismissableModalViewControllerBackgroundStyleBlur
      && snapshotSuccess) {
    viewController.backgroundImage = [UIImageEffects imageByApplyingDarkEffectToImage:backgroundImage];
    viewController.closeButton.tintColor = [UIColor lightGrayColor];
  } else if (backgroundStyle == DFDismissableModalViewControllerBackgroundStyleTranslucentBlack
             && snapshotSuccess) {
    viewController.backgroundImage = backgroundImage;
    viewController.contentView.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
    viewController.closeButton.tintColor = [UIColor whiteColor];
  } else {
    viewController.view.backgroundColor = [UIColor colorWithWhite:0 alpha:0.8];
  }
  
  if (animated) {
    CATransition* transition = [CATransition animation];
    transition.duration = 0.3;
    transition.type = kCATransitionFade;
    [parent.view.window.layer addAnimation:transition forKey:kCATransition];
  }
  [parent presentViewController:viewController animated:NO completion:nil];
}

@end
