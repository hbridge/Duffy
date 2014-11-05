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
#import "DFAnalytics.h"
#import "DFStrandConstants.h"
#import "DFUser.h"
#import "DFImageDiskCache.h"
#import "UIAlertView+DFHelpers.h"
#import "DFNetworkingConstants.h"
#import "AppDelegate.h"
#import "DFContactsViewController.h"
#import <AssetsLibrary/AssetsLibrary.h>
#import "DFSMSInviteStrandComposeViewController.h"
#import "DFNavigationController.h"
#import <Slash/Slash.h>
#import "DFLogs.h"

@interface DFSettingsViewController ()

@property (nonatomic, retain) FKFormModel *formModel;
@property (nonatomic, retain) DFSettings *settings;

@end

@implementation DFSettingsViewController

- (id)initWithStyle:(UITableViewStyle)style
{
  self = [super initWithStyle:UITableViewStyleGrouped];
  if (self) {
    self.settings = [[DFSettings alloc] init];
    self.navigationItem.title = @"Settings";
    self.tabBarItem.image = [[UIImage imageNamed:@"Assets/Icons/SettingsBarButton"]
                             imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    self.tabBarItem.selectedImage = [[UIImage imageNamed:@"Assets/Icons/SettingsBarButton"]
                             imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
  }
  return self;
}

+ (void)presentModallyInViewController:(UIViewController *)viewController
{
  DFSettingsViewController *vc = [[DFSettingsViewController alloc] init];
  DFNavigationController *navController = [[DFNavigationController alloc] initWithRootViewController:vc];
  [viewController presentViewController:navController animated:YES completion:nil];
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  if (self.presentingViewController) {
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc]
                                             initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                             target:self
                                             action:@selector(closeButtonPressed:)];
  }
  
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
//    [mapping button:@"Invite Friend"
//         identifier:@"inviteUser"
//            handler:[self inviteUserHandler]
//       accesoryType:UITableViewCellAccessoryDisclosureIndicator];
//    [mapping button:@"Add Friends"
//         identifier:@"addFriends"
//            handler:^(id object) {
//              [self.navigationController pushViewController:[[DFContactsViewController alloc] init]
//                                                   animated:YES];
//            }
//       accesoryType:UITableViewCellAccessoryDisclosureIndicator];

    [mapping mapAttribute:@"phoneNumber" title:@"Phone Number" type:FKFormAttributeMappingTypeLabel];
    [mapping mapAttribute:@"displayName" title:@"Display Name" type:FKFormAttributeMappingTypeText];
    [mapping mapAttribute:@"pushNotificationsEnabled"
                    title:@"Push Notifications"
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
      #ifndef TARGET_IPHONE_SIMULATOR
      DFDiagnosticInfoMailComposeController *mailComposer =
      [[DFDiagnosticInfoMailComposeController alloc] initWithMailType:DFMailTypeIssue];
      if (mailComposer) { // if the user hasn't setup email, this will come back nil
        [self presentViewController:mailComposer animated:YES completion:nil];
      }
      #else
      NSData *logData = [DFLogs aggregatedLogData];
      NSString *filePath;
      NSArray * paths = NSSearchPathForDirectoriesInDomains (NSDesktopDirectory, NSUserDomainMask, YES);
      if (paths.firstObject) {
        NSArray *pathComponents = [(NSString *)paths.firstObject pathComponents];
        if ([pathComponents[1] isEqualToString:@"Users"]) {
          filePath = [NSString stringWithFormat:@"/Users/%@/Desktop/%@.log",
                                     pathComponents[2], [NSDate date]];
          
        }
      }
      [logData writeToFile:filePath atomically:NO];
       [UIAlertView showSimpleAlertWithTitle:@"Copied To Desktop"
                            formatMessage:@"Log data has been copied to your desktop."];
       #endif
    } accesoryType:UITableViewCellAccessoryDisclosureIndicator];
    [mapping button:@"Send Feedback" identifier:@"sendFeedback" handler:^(id object) {
      DFDiagnosticInfoMailComposeController *mailComposer =
      [[DFDiagnosticInfoMailComposeController alloc] initWithMailType:DFMailTypeFeedback];
      if (mailComposer) {
        [self presentViewController:mailComposer animated:YES completion:nil];
      }
    } accesoryType:UITableViewCellAccessoryDisclosureIndicator];
    [mapping button:@"Location Map" identifier:@"locationMap" handler:^(id object) {
      CLLocation *location = [[DFBackgroundLocationManager sharedBackgroundLocationManager] lastLocation];
      DFMapViewController *mapViewController = [[DFMapViewController alloc] initWithLocation:location];
      [self.navigationController pushViewController:mapViewController animated:YES];
    } accesoryType:UITableViewCellAccessoryDisclosureIndicator];
    
    // Acknowledgements & Legal
    [mapping sectionWithTitle:@"Legal" footer:nil identifier:@"legal"];
    [mapping button:@"Acknowledgements"
         identifier:@"acknowledgements"
            handler:[DFSettingsViewController
                     webviewHandlerForURLString:DFAcknowledgementsPageURLString navigationController:self.navigationController]
       accesoryType:UITableViewCellAccessoryDisclosureIndicator];
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
      [self addDeveloperOptions:mapping];
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


#pragma mark - Developer settings

- (void)addDeveloperOptions:(FKFormMapping *)mapping
{
  [mapping sectionWithTitle:@"Developer" identifier:@"developer"];
  
  [mapping mapAttribute:@"userID" title:@"User ID" type:FKFormAttributeMappingTypeLabel];
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
            NSError *error = [[DFImageDiskCache sharedStore] clearCache];
            if (!error) {
              [UIAlertView showSimpleAlertWithTitle:@"Cache cleared." message:@"The image cache has been cleared"];
            } else {
              [UIAlertView showSimpleAlertWithTitle:@"Error" message:error.localizedDescription];
            }
            
          }
     accesoryType:UITableViewCellAccessoryDisclosureIndicator];
  [mapping button:@"Print All Fonts"
       identifier:@"printAllFonts"
          handler:^(id object) {
            NSArray *fontFamilies = [UIFont familyNames];
            
            for (int i = 0; i < [fontFamilies count]; i++)
            {
              NSString *fontFamily = [fontFamilies objectAtIndex:i];
              NSArray *fontNames = [UIFont fontNamesForFamilyName:[fontFamilies objectAtIndex:i]];
              NSLog (@"%@: %@", fontFamily, fontNames);
            }
          }
     accesoryType:UITableViewCellAccessoryDisclosureIndicator];
  [mapping button:@"Crash"
       identifier:@"crash"
          handler:^(id object) {
            [NSException raise:@"Intentional Crash" format:@"Hit crash button in Dev settings"];
          }
     accesoryType:UITableViewCellAccessoryDisclosureIndicator];
  [mapping button:@"Log Out"
       identifier:@"logOut"
          handler:^(id object) {
            [DFUser setCurrentUser:nil];
            [(AppDelegate *)[[UIApplication sharedApplication] delegate] resetApplication];
          }
     accesoryType:UITableViewCellAccessoryDisclosureIndicator];
  
  
  [mapping button:@"Test Something..."
       identifier:@"testSomething"
          handler:^(id object) {
            NSString *titleLabelMarkup = [NSString stringWithFormat:@"From <name>%@</name>",
                                          nil];
            NSError *error;
            NSAttributedString *string = [SLSMarkupParser
             attributedStringWithMarkup:titleLabelMarkup
             style:[DFStrandConstants defaultTextStyle]
             error:&error];
            DDLogVerbose(@"%@", string);
            
            
          }
     accesoryType:UITableViewCellAccessoryDisclosureIndicator];
  
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result
{
  [self dismissViewControllerAnimated:YES completion:nil];
}



@end
