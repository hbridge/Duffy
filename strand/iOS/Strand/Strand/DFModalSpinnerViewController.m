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

@end
