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
    [mapping sectionWithTitle:@"Profile" footer:@"Your Display Name will be shown to other Strand users." identifier:@"profile"];
    [mapping mapAttribute:@"displayName" title:@"Display Name" type:FKFormAttributeMappingTypeLabel];
    
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

@end
