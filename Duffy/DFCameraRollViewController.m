//
//  DFCameraRollViewController.m
//  Duffy
//
//  Created by Henry Bridge on 1/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFCameraRollViewController.h"
#import "DFPhotoStore.h"
#import "DFUploadController.h"
#import "DFSettingsViewController.h"
#import "DFPhoto.h"

@interface DFCameraRollViewController ()

@end

@implementation DFCameraRollViewController

- (id)init
{
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(cameraRollScanComplete)
                                                     name:DFPhotoStoreCameraRollScanComplete
                                                   object:nil];
        self.photos = [[[DFPhotoStore sharedStore] cameraRoll] photosByDate];
        
        self.navigationController.navigationItem.title = @"Camera Roll";
        self.tabBarItem.title = @"Camera Roll";
        self.tabBarItem.image = [UIImage imageNamed:@"Timeline"];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(cameraRollUpdated)
                                                 name:DFPhotoStoreCameraRollUpdated
                                               object:nil];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)cameraRollUpdated
{
    self.photos = [[[DFPhotoStore sharedStore] cameraRoll] photosByDate];
    [self.collectionView reloadData];
}

- (void)cameraRollScanComplete
{
    if ([[[ NSUserDefaults standardUserDefaults] valueForKey:DFAutoUploadEnabledUserDefaultKey] isEqualToString:DFEnabledYes]){
        DFPhotoCollection *photosToUpload = [[DFPhotoStore sharedStore] photosWithUploadStatus:NO];
        [[DFUploadController sharedUploadController] uploadPhotosWithURLs:photosToUpload.photoURLSet.allObjects];
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
 
}




@end
