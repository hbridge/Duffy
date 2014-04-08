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
#import "DFAnalytics.h"

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

- (void)cameraRollUpdated
{
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(cameraRollUpdated)
                               withObject:nil
                            waitUntilDone:NO];
        return;
    }
    
    self.photos = [[[DFPhotoStore sharedStore] cameraRoll] photosByDate];
    [self.collectionView reloadData];
    NSLog(@"cameraViewController view updated. %lu photos in camera roll.", (unsigned long)self.photos.count);
}

- (void)cameraRollScanComplete
{
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(cameraRollScanComplete)
                               withObject:nil
                            waitUntilDone:NO];
        return;
    }
    
    if ([[[ NSUserDefaults standardUserDefaults] valueForKey:DFAutoUploadEnabledUserDefaultKey] isEqualToString:DFEnabledYes]){
        DFPhotoCollection *photosToUpload = [[DFPhotoStore sharedStore] photosWithUploadStatus:NO];
        [[DFUploadController sharedUploadController] uploadPhotosWithURLs:photosToUpload.photoURLSet.allObjects];
    }
}






@end
