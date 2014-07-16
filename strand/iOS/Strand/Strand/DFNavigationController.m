//
//  DFNavigationController.m
//  Strand
//
//  Created by Henry Bridge on 7/16/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFNavigationController.h"
#import "DFStrandConstants.h"

@interface DFNavigationController ()

@end

@implementation DFNavigationController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
  self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
  if (self) {
    // Custom initialization
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  self.navigationBar.barTintColor = [DFStrandConstants mainColor];
  self.navigationBar.tintColor = [UIColor whiteColor];
  self.navigationBar.titleTextAttributes = @{
                                             NSForegroundColorAttributeName: [UIColor whiteColor]
                                             };
  self.navigationBar.translucent = NO;
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

-(UIStatusBarStyle)preferredStatusBarStyle{
  return UIStatusBarStyleLightContent;
}

@end
