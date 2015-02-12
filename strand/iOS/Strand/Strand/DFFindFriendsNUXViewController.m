//
//  DFFindFriendsNUXViewController.m
//  Strand
//
//  Created by Henry Bridge on 1/27/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFFindFriendsNUXViewController.h"
#import "DFAlertController.h"
#import "DFContactSyncManager.h"
#import "DFContactDataManager.h"
#import "DFAnalytics.h"

@interface DFFindFriendsNUXViewController ()

@end

@implementation DFFindFriendsNUXViewController

- (instancetype)init
{
  self = [super initWithTitle:@"Find Friends"
                        image:[UIImage imageNamed:@"Assets/Nux/FriendsGraphic"]
              explanationText:@"Swap can suggest people to share photos with, but first you’ll need to find some friends on Swap."
                  buttonTitle:@"Find Friends"];
  if (self) {
    
  }
  return self;
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}

- (void)buttonPressed:(id)sender
{
  DFAlertController *softAskForContacts = [DFAlertController
                                           alertControllerWithTitle:@"Contacts Access"
                                           message:@"Find all friends on Swap in your address book?"
                                           preferredStyle:DFAlertControllerStyleAlert];
  [softAskForContacts addAction:[DFAlertAction
                                 actionWithTitle:@"Not Now"
                                 style:DFAlertActionStyleCancel
                                 handler:^(DFAlertAction *action) {
                                   [self completedWithUserInfo:nil];
                                   [DFAnalytics logNux:@"Contacts" completedWithResult:@"Not Now"];
                                 }]];
  [softAskForContacts addAction:[DFAlertAction
                                 actionWithTitle:@"Yes"
                                 style:DFAlertActionStyleDefault
                                 handler:^(DFAlertAction *action) {
                                   [DFContactSyncManager askForContactsPermissionWithSuccess:^{
                                     dispatch_async(dispatch_get_main_queue(), ^{
                                       [self completedWithUserInfo:nil];
                                       [DFAnalytics logNux:@"Contacts" completedWithResult:@"Yes-Granted"];
                                       [[DFContactDataManager sharedManager] refreshCache];
                                     });
                                   } failure:^(NSError *error) {
                                     dispatch_async(dispatch_get_main_queue(), ^{
                                       [self completedWithUserInfo:nil];
                                       [DFAnalytics logNux:@"Contacts" completedWithResult:@"Yes-NotGranted"];
                                     });
                                   }];
                                 }]];
  [softAskForContacts showWithParentViewController:self animated:YES completion:nil];
}

@end
