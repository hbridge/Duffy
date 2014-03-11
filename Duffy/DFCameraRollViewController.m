//
//  DFCameraRollViewController.m
//  Duffy
//
//  Created by Henry Bridge on 1/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFCameraRollViewController.h"
#import "DFPhotoStore.h"
#import "DFSearchController.h"
#import "DFUploadController.h"

@interface DFCameraRollViewController ()

@property (nonatomic, retain) DFSearchController *sdc;
@property (nonatomic, retain) DFUploadController *uploadController;

@end

@implementation DFCameraRollViewController

- (id)init
{
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(photoStoreReady)
                                                     name:DFPhotoStoreReadyNotification
                                                   object:nil];
        self.photos = [[DFPhotoStore sharedStore] cameraRoll];
        
        self.navigationController.navigationItem.title = @"Camera Roll";
        self.tabBarItem.title = @"Camera Roll";
        self.tabBarItem.image = [UIImage imageNamed:@"Timeline"];
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // we have to assign this to something that gets retained because there's
    // an iOS bug that doesn't retain SDC
    self.sdc = [[DFSearchController alloc] initWithSearchBar:[[UISearchBar alloc] init]
                                                                contentsController:self];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)photoStoreReady
{
    self.photos = [[DFPhotoStore sharedStore] cameraRoll];
    
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    
    // WARNING PUTTING THIS HERE IS A HACK TO CACHE THUMBNAILS, TODO MAKE THIS BETTER
    NSArray *photosToUpload = [[DFPhotoStore sharedStore] photosWithUploadStatus:NO];
    if (!self.uploadController) {
        self.uploadController = [[DFUploadController alloc] init];
    }
    
    [self.uploadController uploadPhotos:photosToUpload];
}




@end
