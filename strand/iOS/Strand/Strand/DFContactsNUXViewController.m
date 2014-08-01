//
//  DFContactsNUXViewController.m
//  Strand
//
//  Created by Henry Bridge on 7/31/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFContactsNUXViewController.h"
#import <AddressBook/AddressBook.h>
#import "DFPeanutContact.h"
#import "DFPeanutContactAdapter.h"
#import "AppDelegate.h"
#import "RootViewController.h"
#import "DFContactSyncManager.h"
#import "UIAlertView+DFHelpers.h"
#import "DFDefaultsStore.h"
#import "MMPopLabel.h"
#import "SAMGradientView.h"
#import "DFStrandConstants.h"
#import "DFAnalytics.h"

@interface DFContactsNUXViewController ()

@property (nonatomic, retain) MMPopLabel *learnMorePopLabel;
@property (nonatomic) BOOL learnMoreWasPressed;

@end

@implementation DFContactsNUXViewController

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
  SAMGradientView *gradientView = (SAMGradientView *)self.view;
  gradientView.gradientColors = @[[DFStrandConstants defaultBackgroundColor], [DFStrandConstants strandOrange]];  [self configurePopLabel];
}

- (BOOL)prefersStatusBarHidden
{
  return YES;
}

- (void)configurePopLabel
{
  // create the labels
  self.learnMorePopLabel = [MMPopLabel popLabelWithText:
                            @"Strand determines who your friends are based on whether you "
                            "and another person have each other's phone number."];
  self.learnMorePopLabel.labelColor = [[UIColor blackColor] colorWithAlphaComponent:0.9];
  self.learnMorePopLabel.labelTextColor = [UIColor whiteColor];
  self.learnMorePopLabel.labelFont = [UIFont systemFontOfSize:14];
  
  // add add them to the view
  [self.view addSubview:self.learnMorePopLabel];
}

- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (IBAction)grantPermissionButtonPressed:(id)sender {
  CFErrorRef error;
  ABAddressBookRef addressBookRef = ABAddressBookCreateWithOptions(NULL, &error);
  ABAddressBookRequestAccessWithCompletion(addressBookRef, ^(bool granted, CFErrorRef error) {
    if (granted) {
      [[DFContactSyncManager sharedManager] sync];
      [DFDefaultsStore setState:DFPermissionStateGranted forPermission:DFPermissionContacts];
      [DFAnalytics logSetupContactsCompletedWithResult:DFAnalyticsValueResultSuccess
                                   userTappedLearnMore:self.learnMoreWasPressed];
      [self dismiss];
    } else {
      [DFDefaultsStore setState:DFPermissionStateDenied forPermission:DFPermissionContacts];
      [DFAnalytics logSetupContactsCompletedWithResult:DFAnalyticsValueResultFailure
                                   userTappedLearnMore:self.learnMoreWasPressed];
      dispatch_async(dispatch_get_main_queue(), ^{
      });
    }
  });
  
  
  
}

- (IBAction)learnMoreButtonPressed:(id)sender {
  self.learnMoreWasPressed = YES;
  if (self.learnMorePopLabel.hidden) {
    [self.learnMorePopLabel popAtView:sender animatePopLabel:YES animateTargetView:NO];
  } else {
    [self.learnMorePopLabel dismiss];
  }
}


- (void)dismiss
{
  AppDelegate *delegate = [[UIApplication sharedApplication] delegate];
  [delegate showMainView];
  dispatch_async(dispatch_get_main_queue(), ^{
    RootViewController *rootViewController = (RootViewController *)delegate.window.rootViewController;
    if ([rootViewController respondsToSelector:@selector(showGallery)]) {
      [rootViewController showGallery];
    }
  });
}



@end
