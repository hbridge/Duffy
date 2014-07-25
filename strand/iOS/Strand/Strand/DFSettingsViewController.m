//
//  DFSettingsViewController.m
//  Strand
//
//  Created by Henry Bridge on 7/8/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSettingsViewController.h"
#import "FormKit.h"
#import "DFSettings.h"
#import "DFWebViewController.h"
#import "DFDiagnosticInfoMailComposeController.h"
#import "DFNetworkingConstants.h"
#import "DFBackgroundLocationManager.h"
#import "DFMapViewController.h"
#import "DFPeanutInviteMessageAdapter.h"
#import "DFInviteUserComposeController.h"
#import "DFAnalytics.h"
#import "DFStrandConstants.h"
#import "DFUser.h"
#import "DFImageStore.h"
#import "UIAlertView+DFHelpers.h"
#import "DFNetworkingConstants.h"
#import "DFCameraRollChangeManager.h"

@interface DFSettingsViewController ()

@property (nonatomic, retain) FKFormModel *formModel;
@property (nonatomic, retain) DFSettings *settings;
@property (nonatomic, retain) DFInviteUserComposeController *inviteController;

@end

@implementation DFSettingsViewController

- (id)initWithStyle:(UITableViewStyle)style
{
  self = [super initWithStyle:UITableViewStyleGrouped];
  if (self) {
    self.settings = [[DFSettings alloc] init];
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                             initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                             target:self
                                             action:@selector(closeButtonPressed:)];
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self configureForm];
}

- (void)viewDidAppear:(BOOL)animated
{
  [super viewDidAppear:animated];
  [DFAnalytics logViewController:self appearedWithParameters:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
  [super viewDidDisappear:animated];
  [DFAnalytics logViewController:self disappearedWithParameters:nil];
}


- (void)configureForm
{
  self.formModel = [FKFormModel formTableModelForTableView:self.tableView
                                      navigationController:self.navigationController];
  
  self.formModel.labelTextColor = [UIColor blackColor];
  self.formModel.valueTextColor = [UIColor lightGrayColor];
  
  [FKFormMapping mappingForClass:[DFSettings class] block:^(FKFormMapping *mapping) {
    // Info
    [mapping sectionWithTitle:@"Information" identifier:@"info"];
    [mapping mapAttribute:@"version" title:@"Version" type:FKFormAttributeMappingTypeLabel];
    
    // User profile
    [mapping sectionWithTitle:@"Profile"
                       footer:@"Your Display Name will be shown to other Strand users."
                   identifier:@"profile"];
    [mapping button:@"Invite Friend"
         identifier:@"inviteUser"
            handler:[self inviteUserHandler]
       accesoryType:UITableViewCellAccessoryDisclosureIndicator];
    [mapping mapAttribute:@"phoneNumber" title:@"Phone Number" type:FKFormAttributeMappingTypeLabel];
    [mapping mapAttribute:@"displayName" title:@"Display Name" type:FKFormAttributeMappingTypeLabel];
    
    // Photos
    [mapping sectionWithTitle:@"Photos"
                       footer:@"Automatically save photos you take in Strand to your Camera Roll"
                   identifier:@"photos"];
    [mapping mapAttribute:@"autosaveToCameraRoll" title:@"Save to Camera Roll."
                     type:FKFormAttributeMappingTypeBoolean];
    
    // Support
    [mapping sectionWithTitle:@"Support" identifier:@"support"];
    [mapping button:@"Help"
         identifier:@"helpInfo"
            handler:[DFSettingsViewController
                     webviewHandlerForURLString:DFSupportPageURLString
                     navigationController:self.navigationController]
       accesoryType:UITableViewCellAccessoryDisclosureIndicator];
    [mapping button:@"Report Issue" identifier:@"reportIssue" handler:^(id object) {
      DFDiagnosticInfoMailComposeController *mailComposer =
      [[DFDiagnosticInfoMailComposeController alloc] initWithMailType:DFMailTypeIssue];
      [self presentViewController:mailComposer animated:YES completion:nil];
    } accesoryType:UITableViewCellAccessoryDisclosureIndicator];
    [mapping button:@"Send Feedback" identifier:@"sendFeedback" handler:^(id object) {
      DFDiagnosticInfoMailComposeController *mailComposer =
      [[DFDiagnosticInfoMailComposeController alloc] initWithMailType:DFMailTypeFeedback];
      [self presentViewController:mailComposer animated:YES completion:nil];
    } accesoryType:UITableViewCellAccessoryDisclosureIndicator];
    [mapping button:@"Location Map" identifier:@"locationMap" handler:^(id object) {
      CLLocation *location = [[DFBackgroundLocationManager sharedBackgroundLocationManager] lastLocation];
      DFMapViewController *mapViewController = [[DFMapViewController alloc] initWithLocation:location];
      [self.navigationController pushViewController:mapViewController animated:YES];
    } accesoryType:UITableViewCellAccessoryDisclosureIndicator];
    
    // Legal
    [mapping sectionWithTitle:@"Legal" footer:nil identifier:@"legal"];
    [mapping button:@"Terms"
         identifier:@"terms"
            handler:[DFSettingsViewController
                     webviewHandlerForURLString:DFTermsPageURLString navigationController:self.navigationController]
       accesoryType:UITableViewCellAccessoryDisclosureIndicator];
    [mapping button:@"Privacy Policy"
         identifier:@"privacyPolicy"
            handler:[DFSettingsViewController
                     webviewHandlerForURLString:DFPrivacyPageURLString navigationController:self.navigationController]
       accesoryType:UITableViewCellAccessoryDisclosureIndicator];
    
    if ([[DFUser currentUser] isUserDeveloper]) {
      [DFSettingsViewController addDeveloperOptions:mapping];
    }
    
    [self.formModel registerMapping:mapping];
  }];
  
  [self.formModel loadFieldsWithObject:self.settings];
}

+ (FKFormMappingButtonHandlerBlock)webviewHandlerForURLString:(NSString *)urlString
                                             navigationController:(UINavigationController *)controller
{
  return ^(id object){
    DFWebViewController *webviewController =
    [[DFWebViewController alloc]
     initWithURL:[NSURL URLWithString:urlString]];
    [controller pushViewController:webviewController animated:YES];
  };
}


- (void)didReceiveMemoryWarning
{
  [super didReceiveMemoryWarning];
  // Dispose of any resources that can be recreated.
}

- (void)closeButtonPressed:(UIBarButtonItem *)sender
{
  [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Inviting

- (FKFormMappingButtonHandlerBlock)inviteUserHandler
{
  return ^(id object){
    self.inviteController = [[DFInviteUserComposeController alloc] init];
    [self.inviteController loadMessageWithCompletion:^(NSError *error) {
      [self presentViewController:self.inviteController animated:YES completion:nil];
    }];
  };
}


#pragma mark - Developer settings

+ (void)addDeveloperOptions:(FKFormMapping *)mapping
{
  // Support
  [mapping sectionWithTitle:@"Developer" identifier:@"developer"];
  [mapping mapAttribute:@"serverURL"
                  title:@"Server"
                   type:FKFormAttributeMappingTypeText
           keyboardType:UIKeyboardTypeURL
   ];
  [mapping mapAttribute:@"serverPort"
                  title:@"Port"
                   type:FKFormAttributeMappingTypeText
           keyboardType:UIKeyboardTypeNumberPad
   ];
  
  [mapping button:@"Clear Image Cache"
       identifier:@"clearImageCache"
          handler:^(id object) {
            NSError *error = [DFImageStore clearCache];
            if (!error) {
              [UIAlertView showSimpleAlertWithTitle:@"Cache cleared." message:@"The image cache has been cleared"];
            } else {
              [UIAlertView showSimpleAlertWithTitle:@"Error" message:error.localizedDescription];
            }
            
          }
     accesoryType:UITableViewCellAccessoryDisclosureIndicator];
  
  [mapping button:@"Test Something..."
       identifier:@"testSomething"
          handler:^(id object) {
            [[DFCameraRollChangeManager sharedManager]
             checkForNewCameraRollPhotosWithCompletion:^(UIBackgroundFetchResult result) {
              
            }];

          }
     accesoryType:UITableViewCellAccessoryDisclosureIndicator];
  
}


@end
