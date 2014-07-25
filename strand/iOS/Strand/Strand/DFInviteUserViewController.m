//
//  DFInviteUserViewController.m
//  Strand
//
//  Created by Henry Bridge on 7/25/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFInviteUserViewController.h"
#import "DFInviteUserComposeController.h"
#import "UIAlertView+DFHelpers.h"

@interface DFInviteUserViewController ()

@property (nonatomic, retain) DFInviteUserComposeController *composeController;

@end

@implementation DFInviteUserViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
      self.composeController = [[DFInviteUserComposeController alloc] init];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)viewWillAppear:(BOOL)animated
{
  [super viewWillAppear:animated];
  if (self.composeController.isBeingDismissed) {
    // we're coming back form the child compose controller
    [self dismissViewControllerAnimated:YES completion:nil];
  }
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  if (!self.composeController || self.composeController.isBeingDismissed) {
    // the the view controller failed to load
    [self dismissViewControllerAnimated:YES completion:nil];
  } else {
    [self.composeController loadMessageWithCompletion:^(NSError *error) {
      dispatch_async(dispatch_get_main_queue(), ^{
        if (!error) {
          [self presentViewController:self.composeController animated:YES completion:nil];
        } else {
          [UIAlertView showSimpleAlertWithTitle:@"Error" message:error.localizedDescription];
          [self dismissViewControllerAnimated:YES completion:nil];
        }
      });
    }];
  }
}

- (void)dismissViewControllerAnimated:(BOOL)flag completion:(void (^)(void))completion
{
  [self.presentingViewController dismissViewControllerAnimated:flag completion:completion];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
