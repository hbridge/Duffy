//
//  DFSettingsViewController.m
//  Duffy
//
//  Created by Henry Bridge on 3/12/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFSettingsViewController.h"
#import <CocoaLumberjack/DDFileLogger.h>
#import "DFPhotoStore.h"
#import "DFUploadController.h"
#import "DFUser.h"
#import "DFAnalytics.h"
#import "DFNotificationSharedConstants.h"
#import "DFAppInfo.h"
#import "DFDevelopmentSettingsViewController.h"

@interface DFSettingsViewController ()

@property (nonatomic, retain) UIView *lastEditedTextField;

@end

@implementation DFSettingsViewController

- (id)init
{
    self = [super init];
    if (self) {
        self.navigationItem.title = @"Settings";
        self.tabBarItem.title = @"Settings";
        self.tabBarItem.image = [UIImage imageNamed:@"SettingsTab"];
        
        [self setSettingsDefaults];
    }
    return self;
}

- (void)setSettingsDefaults
{
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    if (![defaults valueForKey:DFAutoUploadEnabledUserDefaultKey]) {
        [defaults setValue:DFEnabledYes forKey:DFAutoUploadEnabledUserDefaultKey];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];

    [self configureAppInfoView];
    [self configureUserSectionView];
  
    
    if ([[[NSUserDefaults standardUserDefaults] valueForKeyPath:DFAutoUploadEnabledUserDefaultKey] isEqualToString:DFEnabledYes]){
        self.autoUploadEnabledSwitch.on = YES;
    } else {
        self.autoUploadEnabledSwitch.on = NO;
    }
    
    
}

- (void)configureAppInfoView
{
    self.appInfoLabel.text = [DFAppInfo appInfoString];
}

- (void)configureUserSectionView
{
  self.userIDTextField.text = [NSString stringWithFormat:@"%lu", (long)[[DFUser currentUser] userID]];
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


- (IBAction)cancelUpload:(UIButton *)sender {
    [[DFUploadController sharedUploadController] cancelUploads];
}

- (IBAction)sendInfoClicked:(UIButton *)sender {
    if ([MFMailComposeViewController canSendMail]) {
        MFMailComposeViewController *mailViewController = [[MFMailComposeViewController alloc] init];
        mailViewController.mailComposeDelegate = self;
        NSMutableData *errorLogData = [NSMutableData data];
        for (NSData *errorLogFileData in [self errorLogData]) {
            [errorLogData appendData:errorLogFileData];
        }
        [mailViewController addAttachmentData:errorLogData mimeType:@"text/plain" fileName:@"DuffyLog.txt"];
        [mailViewController setSubject:[NSString stringWithFormat:@"Diagnostic info for %@", [DFAppInfo appInfoString]]];
        [mailViewController setToRecipients:[NSArray arrayWithObject:@"hbridge@gmail.com"]];

        [self presentViewController:mailViewController animated:YES completion:nil];
    }

    else {
        NSString *message = NSLocalizedString(@"Sorry, your issue can't be reported right now. This is most likely because no mail accounts are set up on your mobile device.", @"");
        [[[UIAlertView alloc] initWithTitle:nil message:message delegate:nil cancelButtonTitle:NSLocalizedString(@"OK", @"") otherButtonTitles: nil] show];
    }

}

- (IBAction)developerSettingsClicked:(UIButton *)sender {
  DFDevelopmentSettingsViewController *dsvc = [[DFDevelopmentSettingsViewController alloc] init];
  [self.navigationController pushViewController:dsvc animated:YES];
}

static const int MaxLogFiles = 10;

- (NSMutableArray *)errorLogData
{
    DDFileLogger *fileLogger = [[DDFileLogger alloc] init];
    NSArray *sortedLogFileInfos = [[[fileLogger.logFileManager sortedLogFileInfos] reverseObjectEnumerator] allObjects];
    int numFilesToUpload = MIN((unsigned int)sortedLogFileInfos.count, MaxLogFiles);
    
    NSMutableArray *errorLogFiles = [NSMutableArray arrayWithCapacity:numFilesToUpload];
    for (int i = 0; i < numFilesToUpload; i++) {
        DDLogFileInfo *logFileInfo = [sortedLogFileInfos objectAtIndex:i];
        NSData *fileData = [NSData dataWithContentsOfFile:logFileInfo.filePath];
        [errorLogFiles addObject:fileData];
    }
    
    return errorLogFiles;
}

- (void)mailComposeController:(MFMailComposeViewController*)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError*)error;
{
    if (result == MFMailComposeResultSent) {
        DDLogInfo(@"Feedback email sent.");
    }
    
    [self dismissViewControllerAnimated:YES completion:nil];
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


- (IBAction)autoUploadEnabledSwitchChanged:(UISwitch *)sender {
    if (sender.isOn) {
        DDLogInfo(@"Auto-upload now ON");
        [[ NSUserDefaults standardUserDefaults] setObject:DFEnabledYes forKey:DFAutoUploadEnabledUserDefaultKey];
    } else {
        DDLogInfo(@"Auto-upload now OFF");
        [[ NSUserDefaults standardUserDefaults] setObject:DFEnabledNo forKey:DFAutoUploadEnabledUserDefaultKey];
    }
    
    [DFAnalytics logAutoUploadSettingChanged:sender.isOn];
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
