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
    
    // register a regular cell for reuse
    [self.settingsTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"UITableViewCell"];
    
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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [self.settingsTableView dequeueReusableCellWithIdentifier:@"UITableViewCell"];
    
    switch (indexPath.row) {
        case 0:
            cell.textLabel.text = self.rowLabels[0];
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
            break;
        case 1:
            cell.textLabel.text = [NSString stringWithFormat:@"%@: %@", self.rowLabels[1], [DFUser deviceID]];
            cell.textLabel.adjustsFontSizeToFitWidth = YES;
            break;
        default:
            break;
    }
    
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0) {
        NSArray *cameraRollPhotos = [[[DFPhotoStore sharedStore] cameraRoll] photosByDate];
        [[DFUploadController sharedUploadController] uploadPhotos:cameraRollPhotos];
    } else if (indexPath.row == 1) {
        UIPasteboard *pb = [UIPasteboard generalPasteboard];
        [pb setString:[DFUser deviceID]];
    }
    
    [self.settingsTableView deselectRowAtIndexPath:indexPath animated:YES];
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



@end
