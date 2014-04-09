//
//  DFSettingsViewController.m
//  Duffy
//
//  Created by Henry Bridge on 3/12/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFSettingsViewController.h"
#import "DFPhotoStore.h"
#import "DFUploadController.h"
#import "DFUser.h"
#import "DFAnalytics.h"
#import "DFNotificationSharedConstants.h"

@interface DFSettingsViewController ()

@property (nonatomic, retain) NSArray *rowLabels;

@property (nonatomic, retain) UIView *lastEditedTextField;

@end

@implementation DFSettingsViewController


// Network default keys
NSString *DFPipelineEnabledUserDefaultKey = @"DFPipelineEnabledUserDefaultKey";
NSString *DFAutoUploadEnabledUserDefaultKey = @"DFAutoUploadEnabledUserDefaultKey";
NSString *DFEnabledYes = @"YES";
NSString *DFEnabledNo = @"NO";


- (id)init
{
    self = [super init];
    if (self) {
        self.navigationItem.title = @"Settings";
        self.tabBarItem.title = @"Settings";
        self.tabBarItem.image = [UIImage imageNamed:@"SettingsTab"];
        
        //NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
        //NSString *appName = [infoDictionary objectForKey:@"CFBundleDisplayName"];
        
        // version
        //NSString *majorVersion = [infoDictionary objectForKey:@"CFBundleShortVersionString"];
        //NSString *minorVersion = [infoDictionary objectForKey:@"CFBundleVersion"];

        
        self.rowLabels = @[ @"Force upload camera roll",
                            @"ID",
                            ];
        
        
        [self setSettingsDefaults];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(uploadStatusChanged:)
                                                     name:DFUploadStatusNotificationName
                                                   object:nil];
        
    }
    return self;
}

- (void)setSettingsDefaults
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults valueForKeyPath:DFPipelineEnabledUserDefaultKey]) {
        [defaults setValue:DFEnabledYes forKey:DFPipelineEnabledUserDefaultKey];
    }
    if (![defaults valueForKey:DFAutoUploadEnabledUserDefaultKey]) {
        [defaults setValue:DFEnabledNo forKey:DFAutoUploadEnabledUserDefaultKey];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    self.deviceIDLabel.text = [[DFUser currentUser] hardwareDeviceID];
    self.deviceIDTextField.text = [[DFUser currentUser] userOverriddenDeviceID];
    self.deviceIDTextField.placeholder = @"Enter another device ID to override.";
    self.userIDTextField.text = [[DFUser currentUser] userID];
    self.serverURLTextField.text = [[DFUser currentUser] userOverriddenServerURLString];
    self.serverURLTextField.placeholder = [[[DFUser currentUser] defaultServerURL] absoluteString];
    self.serverPortTextField.text = [[DFUser currentUser] userOverriddenServerPortString];
    self.serverPortTextField.placeholder = [[DFUser currentUser] defaultServerPort];
    
    if ([[[NSUserDefaults standardUserDefaults] valueForKeyPath:DFAutoUploadEnabledUserDefaultKey] isEqualToString:DFEnabledYes]){
        self.autoUploadEnabledSwitch.on = YES;
    } else {
        self.autoUploadEnabledSwitch.on = NO;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardDidShow:)
                                                 name:UIKeyboardDidShowNotification
                                               object:nil];
    [DFAnalytics logViewController:self appearedWithParameters:nil];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIKeyboardDidShowNotification
                                                  object:nil];
    [DFAnalytics logViewController:self disappearedWithParameters:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.rowLabels.count;
}

- (IBAction)deviceIDEditingDidEnd:(UITextField *)sender {
    [[DFUser currentUser] setUserOverriddenDeviceID:sender.text];
}

- (IBAction)userIDEditingDidEnd:(UITextField *)sender {
    [[DFUser currentUser] setUserID:sender.text];
}

- (IBAction)serverURLEditingDidEnd:(UITextField *)sender {
    [[DFUser currentUser] setUserOverriddenServerURLString:sender.text];
}

- (IBAction)serverPortEditingDidEnd:(UITextField *)sender {
    [[DFUser currentUser] setUserOverriddenServerPortString:sender.text];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

- (BOOL)textFieldShouldEndEditing:(UITextField *)textField
{
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
    self.lastEditedTextField = textField;
}

- (IBAction)copyDeviceIDClicked:(UIButton *)sender {
    UIPasteboard *pb = [UIPasteboard generalPasteboard];
    [pb setString:[[DFUser currentUser] deviceID]];
}

- (IBAction)reUploadAllClicked:(UIButton *)sender {
    DFPhotoCollection *cameraRollPhotos = [[DFPhotoStore sharedStore] cameraRoll];
    [[DFUploadController sharedUploadController] uploadPhotosWithURLs:[cameraRollPhotos.photoURLSet allObjects]];
}

- (IBAction)autoUploadEnabledSwitchChanged:(UISwitch *)sender {
    if (sender.isOn) {
        NSLog(@"Auto-upload now ON");
        [[ NSUserDefaults standardUserDefaults] setObject:DFEnabledYes forKey:DFAutoUploadEnabledUserDefaultKey];
    } else {
        NSLog(@"Auto-upload now OFF");
        [[ NSUserDefaults standardUserDefaults] setObject:DFEnabledNo forKey:DFAutoUploadEnabledUserDefaultKey];
    }
}


- (void)uploadStatusChanged:(NSNotification *)notification
{
    DFUploadSessionStats *uploadStats = [[notification userInfo] valueForKey:DFUploadStatusUpdateSessionUserInfoKey];
    
    self.numUploadedLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)uploadStats.numUploaded];
    self.numToUploadLabel.text = [NSString stringWithFormat:@"%lu", (unsigned long)uploadStats.numAcceptedUploads];
    self.uploadProgressView.progress = (float)uploadStats.numUploaded / (float)uploadStats.numAcceptedUploads;
}


- (void)keyboardDidShow:(NSNotification *)notification {
    if (self.lastEditedTextField && self.lastEditedTextField.isFirstResponder) {
        [self scrollToView:self.lastEditedTextField];
    }
}

- (void)scrollToView:(UIView *)view
{
    CGRect rectInScrollView = [self.scrollView convertRect:view.frame fromView:view.superview];
    self.scrollView.contentOffset = rectInScrollView.origin;
}

- (IBAction)scrollViewTapped:(UITapGestureRecognizer *)sender {
    if (self.lastEditedTextField && self.lastEditedTextField.isFirstResponder) {
        [self.lastEditedTextField resignFirstResponder];
    }
    
}


@end
