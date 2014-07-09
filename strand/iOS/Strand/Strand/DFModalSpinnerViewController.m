//
//  DFModalSpinnerViewController.m
//  Strand
//
//  Created by Henry Bridge on 7/7/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFModalSpinnerViewController.h"

@interface DFModalSpinnerViewController ()

@end

@implementation DFModalSpinnerViewController

- (id)initWithMessage:(NSString *) message {
  self = [super initWithNibName:[[self class] description] bundle:nil];
  if (self) {
    _message = message;
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  self.messageLabel.text = self.message;
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion
{
  if (!self.isBeingPresented) {
    [super dismissViewControllerAnimated:flag completion:completion];
  } else {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      [self dismissViewControllerAnimated:flag completion:completion];
    });
  }
}

@end
