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

@interface DFSettingsViewController ()

@end

@implementation DFSettingsViewController

- (id)init
{
    self = [super init];
    if (self) {
        self.navigationController.navigationItem.title = @"Settings";
        self.tabBarItem.title = @"Settings";
        self.tabBarItem.image = [UIImage imageNamed:@"SettingsTab"];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // register a regular cell for reuse
    [self.settingsTableView registerClass:[UITableViewCell class] forCellReuseIdentifier:@"UITableViewCell"];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [self.settingsTableView dequeueReusableCellWithIdentifier:@"UITableViewCell"];
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    switch (indexPath.row) {
        case 0:
            cell.textLabel.text = @"Force upload camera roll";
            break;
        default:
            break;
    }
    
    return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0) {
        NSArray *cameraRollPhotos = [[DFPhotoStore sharedStore] cameraRoll];
        [[DFUploadController sharedUploadController] uploadPhotos:cameraRollPhotos];
    }
    
    [self.settingsTableView deselectRowAtIndexPath:indexPath animated:YES];
}


@end
