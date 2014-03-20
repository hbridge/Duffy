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

@interface DFSettingsViewController ()

@property (nonatomic, retain) NSArray *rowLabels;

@end

@implementation DFSettingsViewController

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
                                                     name:DFUploadStatusUpdate
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

    self.deviceIDLabel.text = [DFUser deviceID];
    
    // set switches to correct values
    if ([[[NSUserDefaults standardUserDefaults] valueForKeyPath:DFPipelineEnabledUserDefaultKey] isEqualToString:DFEnabledYes]){
        self.pipelineEnabledSwitch.on = YES;
    } else {
        self.pipelineEnabledSwitch.on = NO;
    }
    
    if ([[[NSUserDefaults standardUserDefaults] valueForKeyPath:DFAutoUploadEnabledUserDefaultKey] isEqualToString:DFEnabledYes]){
        self.autoUploadEnabledSwitch.on = YES;
    } else {
        self.autoUploadEnabledSwitch.on = NO;
    }
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


- (IBAction)copyDeviceIDClicked:(UIButton *)sender {
    UIPasteboard *pb = [UIPasteboard generalPasteboard];
    [pb setString:[DFUser deviceID]];
}

- (IBAction)reUploadAllClicked:(UIButton *)sender {
    DFPhotoCollection *cameraRollPhotos = [[DFPhotoStore sharedStore] cameraRoll];
    [[DFUploadController sharedUploadController] uploadPhotosWithURLs:[cameraRollPhotos.photoURLSet allObjects]];
}

- (IBAction)pipelineEnabledSwitchChanged:(UISwitch *)sender {
    if (sender.isOn) {
        NSLog(@"Pipeline processing for new uploads now ON");
        [[ NSUserDefaults standardUserDefaults] setObject:DFEnabledYes forKey:DFPipelineEnabledUserDefaultKey];
    } else {
        NSLog(@"Pipeline processing for new uploads now OFF");
        [[ NSUserDefaults standardUserDefaults] setObject:DFEnabledNo forKey:DFPipelineEnabledUserDefaultKey];
    }
    
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
    
    self.numUploadedLabel.text = [NSString stringWithFormat:@"%d", uploadStats.numUploaded];
    self.numToUploadLabel.text = [NSString stringWithFormat:@"%d", uploadStats.numAcceptedUploads];
    self.uploadProgressView.progress = (float)uploadStats.numUploaded / (float)uploadStats.numAcceptedUploads;
}




@end
