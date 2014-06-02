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
#import "DFUser.h"
#import "DFPhoto.h"
#import "DFAnalytics.h"
#import "DFNotificationSharedConstants.h"

NSString *const AllSectionName = @"All";

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
      
        self.navigationController.navigationItem.title = @"Camera Roll";
        self.tabBarItem.title = @"Camera Roll";
        self.tabBarItem.image = [UIImage imageNamed:@"Icons/Timeline"];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(cameraRollPhotoChanged:)
                                                     name:DFPhotoChangedNotificationName
                                                   object:nil];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(cameraRollUpdated)
                                                     name:DFPhotoStoreCameraRollUpdated
                                                   object:nil];
      
      [self setSectionNames:@[AllSectionName]
            photosBySection:@{AllSectionName : [[[DFPhotoStore sharedStore] cameraRoll]
                                        photosByDateAscending:YES]}];
    }
    return self;
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


- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [DFAnalytics logViewController:self appearedWithParameters:nil];
    
    
    if (self.isMovingToParentViewController) {
        NSInteger section = 0;
        NSInteger item = [self collectionView:self.collectionView numberOfItemsInSection:section] - 1;
        NSIndexPath *lastIndexPath = [NSIndexPath indexPathForItem:item inSection:section];
        if (lastIndexPath.section >= 0 && lastIndexPath.row >= 0) {
            [self.collectionView scrollToItemAtIndexPath:lastIndexPath atScrollPosition:UICollectionViewScrollPositionBottom animated:NO];
        }
    }
    
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
  
  NSArray *allPhotos = [[[DFPhotoStore sharedStore] cameraRoll]
                        photosByDateAscending:YES];
  [self setSectionNames:@[AllSectionName]
        photosBySection:@{AllSectionName : allPhotos}];
    [self.collectionView reloadData];
  if ([[DFUser currentUser] autoUploadEnabled]){
    [[DFUploadController sharedUploadController] uploadPhotos];
  }

  
    DDLogInfo(@"cameraViewController view updated. %lu photos in camera roll.", (unsigned long)allPhotos.count);
}

- (void)cameraRollScanComplete
{
    if (![NSThread isMainThread]) {
        [self performSelectorOnMainThread:@selector(cameraRollScanComplete)
                               withObject:nil
                            waitUntilDone:NO];
        return;
    }
    
    if ([[DFUser currentUser] autoUploadEnabled]){
        [[DFUploadController sharedUploadController] uploadPhotos];
    }
}


#pragma mark - Cell view customization

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
    UICollectionViewCell *cell = [super collectionView:collectionView cellForItemAtIndexPath:indexPath];
    
    DFPhoto *photo = [self.photosBySection[AllSectionName] objectAtIndex:indexPath.row];
    if (photo.upload157Date == nil) {
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
        NSUInteger photoIndex = [self.photosBySection[AllSectionName] indexOfObject:photo];
        [cellsToReload addObject:[NSIndexPath indexPathForRow:photoIndex inSection:0]];
    }
    
    [self.collectionView reloadItemsAtIndexPaths:cellsToReload];
}


@end
