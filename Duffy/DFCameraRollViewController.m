//
//  DFCameraRollViewController.m
//  Duffy
//
//  Created by Henry Bridge on 1/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFCameraRollViewController.h"
#import "DFPhotoStore.h"

@interface DFCameraRollViewController ()

@end

@implementation DFCameraRollViewController

- (id)init
{
    self = [super init];
    if (self) {
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(photoStoreChanged)
                                                     name:DFPhotoStoreReadyNotification
                                                   object:nil];
        self.photos = [[DFPhotoStore sharedStore] cameraRoll];
        
        self.tabBarItem.title = @"Camera Roll";
        self.tabBarItem.image = [UIImage imageNamed:@"Timeline"];
        
        UINavigationItem *n = [self navigationItem];
        [n setTitle:@"Camera Roll"];
    }
    return self;
}
         
         
- (void)photoStoreChanged
{
    self.photos = [[DFPhotoStore sharedStore] cameraRoll];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
}

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
