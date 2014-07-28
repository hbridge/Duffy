//
//  DFOverlayViewController.m
//  Strand
//
//  Created by Henry Bridge on 7/27/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFOverlayViewController.h"
#import "DFStrandConstants.h"

@interface DFOverlayViewController ()

@property (nonatomic, retain) UIView *overlayView;

@end

@implementation DFOverlayViewController

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  CGFloat statusBarHeight = [UIApplication sharedApplication].statusBarFrame.size.height;
  self.overlayView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, statusBarHeight - 1)];
  [self.overlayView setAutoresizingMask:UIViewAutoresizingFlexibleWidth];
  [self.overlayView setBackgroundColor:[DFStrandConstants defaultBackgroundColor]];
  [self.view addSubview:self.overlayView];
}

- (void)animateIn:(void(^)(BOOL finished))completion
{
  dispatch_async(dispatch_get_main_queue(), ^{
    self.overlayView.alpha = 1.0;
    [UIView animateWithDuration:1.0 animations:^{
      self.overlayView.alpha = 0.0;
    } completion:^(BOOL finished) {
      completion(finished);
    }];
  });
}

- (UIStatusBarStyle)preferredStatusBarStyle
{
  return UIStatusBarStyleLightContent;
}

@end
