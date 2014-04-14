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
#import "DFNotificationSharedConstants.h"

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
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(cameraRollPhotoChanged:)
                                                     name:DFPhotoChangedNotificationName
                                                   object:nil];
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


#pragma mark - Cell view customization

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [super collectionView:collectionView cellForItemAtIndexPath:indexPath];
    
    DFPhoto *photo = [self.photos objectAtIndex:indexPath.row];
    if (photo.uploadDate == nil) {
        cell.alpha = 0.2;
    }
    
    return cell;
}


- (void)cameraRollPhotoChanged:(NSNotification *)note
{
    NSDictionary *objectIDsToChangeTypes = [note userInfo];
    NSSet *objectIDsWithMetadataChange = [objectIDsToChangeTypes keysOfEntriesPassingTest:^BOOL(NSManagedObjectID *objID, NSString *changeType, BOOL *stop) {
        return [changeType isEqualToString:DFPhotoChangeTypeMetadata];
    }];
    
    NSSet *photos = [[DFPhotoStore sharedStore] photosWithObjectIDs:objectIDsWithMetadataChange];
    NSMutableArray *cellsToReload = [[NSMutableArray alloc] initWithCapacity:photos.count];
    for (DFPhoto *photo in photos) {
        NSUInteger photoIndex = [self.photos indexOfObject:photo];
        [cellsToReload addObject:[NSIndexPath indexPathForRow:photoIndex inSection:0]];
    }
    
    [self.collectionView reloadItemsAtIndexPaths:cellsToReload];
}


@end
