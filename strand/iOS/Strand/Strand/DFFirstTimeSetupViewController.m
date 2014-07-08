//
//  DFFirstTimeSetupViewController.m
//  Strand
//
//  Created by Henry Bridge on 6/10/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFFirstTimeSetupViewController.h"
#import "DFUserPeanutAdapter.h"
#import "DFUser.h"
#import "AppDelegate.h"
#import "DFModalSpinnerViewController.h"
#import "DFSMSCodeEntryViewController.h"

@interface DFFirstTimeSetupViewController ()

@end

@implementation DFFirstTimeSetupViewController

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
    // Do any additional setup after loading the view from its nib.
  self.phoneNumberField.delegate = self;
  [self.phoneNumberField becomeFirstResponder];
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                            initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                            target:self
                                            action:@selector(phoneNumberDoneButtonPressed:)];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}



- (BOOL)textField:(UITextField *)textField
shouldChangeCharactersInRange:(NSRange)range
replacementString:(NSString *)string
{
  // dash after 3 numbers
  if (range.location == 2 && ![string isEqualToString:@""]) {
    textField.text = [textField.text stringByAppendingString:[NSString stringWithFormat:@"%@-", string]];
    return  NO;
  } else if (range.location == 3 && [string isEqualToString:@""]) {
    textField.text = [textField.text substringToIndex:2];
    return NO;
  }
  
  // dash after 6 numbers
  if (range.location == 6 && ![string isEqualToString:@""]) {
    textField.text = [textField.text stringByAppendingString:[NSString stringWithFormat:@"%@-", string]];
    return NO;
  } else if (range.location == 7 && [string isEqualToString:@""]) {
    textField.text = [textField.text substringToIndex:6];
    return NO;
  }
  
  // max length
  if ([[textField.text stringByReplacingCharactersInRange:range withString:string] length] > 12) {
    return NO;
  }
  
  return YES;
}


- (void)phoneNumberDoneButtonPressed:(id)sender
{
  DFModalSpinnerViewController *msvc = [[DFModalSpinnerViewController alloc]
                                        initWithMessage:@"connecting..."];
  [self presentViewController:msvc animated:YES completion:nil];
  
  dispatch_after(
                 dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
                   [msvc dismissViewControllerAnimated:YES completion:nil];
                   [self.navigationController
                    pushViewController:[[DFSMSCodeEntryViewController alloc] init] animated:NO];
  });
  
}





@end
