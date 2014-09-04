//
//  DFSelectPhotosViewController.m
//  Strand
//
//  Created by Henry Bridge on 8/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSelectPhotosViewController.h"
#import "DFGallerySectionHeader.h"
#import "DFPhotoStore.h"
#import "DFSelectablePhotoViewCell.h"
#import "DFPeanutStrandAdapter.h"
#import "SVProgressHUD.h"
#import "DFUploadController.h"
#import "DFPeoplePickerViewController.h"
#import "NSString+DFHelpers.h"
#import "DFPhotoViewCell.h"
#import "DFImageStore.h"
#import "DFPeanutStrand.h"

CGFloat const ToFieldHeight = 44.0;

@interface DFSelectPhotosViewController ()

@property (nonatomic, retain) NSArray *suggestedPhotoObjects;
@property (nonatomic, retain) NSArray *sharedPhotoObjects;
@property (nonatomic, retain) NSMutableArray *selectedPhotoIDs;
@property (nonatomic, retain) NSArray *selectedContacts;
@property (nonatomic, retain) DFPeoplePickerViewController *peoplePicker;

@end

@implementation DFSelectPhotosViewController


- (instancetype)init
{
  return [self initWithTitle:nil showsToField:NO suggestedSectionObject:nil sharedSectionObject:nil];
}

- (instancetype)initWithTitle:(NSString *)title
                 showsToField:(BOOL)showsToField
       suggestedSectionObject:(DFPeanutSearchObject *)suggestedSectionObject
          sharedSectionObject:(DFPeanutSearchObject *)sharedSectionObject
{
  self = [super initWithNibName:[self.class description] bundle:nil];
  if (self) {
    _showsToField = showsToField;
    [self configureNavBarWithTitle:title];
    self.suggestedSectionObject = suggestedSectionObject;
    self.sharedSectionObject = sharedSectionObject;
  }
  return self;
}

- (void)viewDidLoad
{
  [super viewDidLoad];
  
  [self configureCollectionView];
  if (self.showsToField) {
    [self configurePeoplePicker];
  } else {
    [self.searchBarWrapperView removeFromSuperview];
  }
}

- (void)configureNavBarWithTitle:(NSString *)title
{
  self.navigationItem.title = title ? title : @"Select Photos";
  self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc]
                                            initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                            target:self action:@selector(donePressed:)];
}

- (void)configurePeoplePicker
{
  // configure the token field
  self.tokenField = [[VENTokenField alloc] initWithFrame:self.searchBarWrapperView.bounds];
  self.tokenField.maxHeight = ToFieldHeight;
  self.peoplePicker = [[DFPeoplePickerViewController alloc]
                       initWithTokenField:self.tokenField
                       tableView:self.tableView];
  self.peoplePicker.allowsMultipleSelection = YES;
  self.peoplePicker.delegate = self;
  [self.searchBarWrapperView addSubview:self.tokenField];
}

- (void)configureCollectionView
{
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFGallerySectionHeader" bundle:nil]
        forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
               withReuseIdentifier:@"headerView"];
  self.flowLayout.headerReferenceSize = CGSizeMake(SectionHeaderWidth, SectionHeaderHeight);
  [self.collectionView registerNib:[UINib nibWithNibName:[DFSelectablePhotoViewCell description] bundle:nil]
        forCellWithReuseIdentifier:@"selectableCell"];
  [self.collectionView registerNib:[UINib nibWithNibName:[DFPhotoViewCell description] bundle:nil]
        forCellWithReuseIdentifier:@"cell"];
  
}

- (void)setSuggestedSectionObject:(DFPeanutSearchObject *)sectionObject
{
  _suggestedSectionObject = sectionObject;
  sectionObject.title = @"Your Photos (Not Shared)";
  NSMutableArray *photos = [NSMutableArray new];
  self.selectedPhotoIDs = [NSMutableArray new];
  for (DFPeanutSearchObject *object in sectionObject.enumeratorOfDescendents.allObjects) {
    if ([object.type isEqual:DFSearchObjectPhoto]) {
      [photos addObject:object];
      // select all by default
      [self.selectedPhotoIDs addObject:@(object.id)];
    }
  }
  
  self.suggestedPhotoObjects = photos;
  dispatch_async(dispatch_get_main_queue(), ^{
    [self.tableView reloadData];
  });
}

- (void)setSharedSectionObject:(DFPeanutSearchObject *)sharedSectionObject
{
  _sharedSectionObject = sharedSectionObject;
  NSMutableArray *photos = [NSMutableArray new];
  for (DFPeanutSearchObject *object in sharedSectionObject.enumeratorOfDescendents.allObjects) {
    if ([object.type isEqual:DFSearchObjectPhoto]) {
      [photos addObject:object];
    }
  }
  
  self.sharedPhotoObjects = photos;
  dispatch_async(dispatch_get_main_queue(), ^{
    
    [self.tableView reloadData];
  });
}

#pragma mark - UICollectionView Data/Delegate

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
  return (self.suggestedPhotoObjects.count > 0) + (self.sharedPhotoObjects.count > 0);
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView viewForSupplementaryElementOfKind:(NSString *)kind atIndexPath:(NSIndexPath *)indexPath
{
  UICollectionReusableView *view;
  if (kind == UICollectionElementKindSectionHeader) {
    DFPeanutSearchObject *sectionObject = [self objectForSection:indexPath.section];
    DFGallerySectionHeader *headerView = [self.collectionView
                                          dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                                          withReuseIdentifier:@"headerView"
                                          forIndexPath:indexPath];
    headerView.titleLabel.text = sectionObject.title;
    headerView.subtitleLabel.text = sectionObject.subtitle;
    
    
    view = headerView;
  }
  return view;
}

- (DFPeanutSearchObject *)objectForSection:(NSUInteger)section
{
  if (section == 0 && self.suggestedPhotoObjects.count > 0) return self.suggestedSectionObject;
 return self.sharedSectionObject;
}

- (NSArray *)photosForSection:(NSUInteger)section
{
  if (section == 0 && self.suggestedPhotoObjects.count > 0) return self.suggestedPhotoObjects;
  
  return self.sharedPhotoObjects;
}

- (BOOL)areImagesForSectionRemote:(NSUInteger)section
{
  return ([self photosForSection:section] == self.sharedPhotoObjects);
}


- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  return [[self photosForSection:section] count];
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  UICollectionViewCell *cell;
  
  DFPeanutSearchObject *object = [self photosForSection:indexPath.section][indexPath.row];
  if (![self areImagesForSectionRemote:indexPath.section]) {
    cell = [self cellForLocalPhoto:object atIndexPath:indexPath];
  } else {
    cell = [self cellForRemotePhoto:object atIndexPath:indexPath];
  }
  
  return cell;
}

- (UICollectionViewCell *)cellForLocalPhoto:(DFPeanutSearchObject *)object
                                atIndexPath:(NSIndexPath *)indexPath
{
  DFSelectablePhotoViewCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"selectableCell"
                                                                                   forIndexPath:indexPath];
  
  DFPhoto *photo = [[DFPhotoStore sharedStore] photoWithPhotoID:object.id];
  
  // show the selected status
  cell.showTickMark = [self.selectedPhotoIDs containsObject:@(object.id)];
  
  // set the image
  cell.imageView.image = nil;
  [photo.asset loadUIImageForThumbnail:^(UIImage *image) {
    //if ([self.collectionView.visibleCells containsObject:cell]) {
    dispatch_async(dispatch_get_main_queue(), ^{
      cell.imageView.image = image;
      [cell setNeedsLayout];
    });
    //}
  } failureBlock:^(NSError *error) {
    DDLogError(@"%@ couldn't load image for asset: %@", self.class, error);
  }];

  return cell;
}

- (UICollectionViewCell *)cellForRemotePhoto:(DFPeanutSearchObject *)object
                                 atIndexPath:(NSIndexPath *)indexPath
{
  DFPhotoViewCell *cell = [self.collectionView dequeueReusableCellWithReuseIdentifier:@"cell"
                                                                         forIndexPath:indexPath];
  // set the image
  cell.imageView.image = nil;
  
  [[DFImageStore sharedStore]
   imageForID:object.id
   preferredType:DFImageThumbnail
   thumbnailPath:object.thumb_image_path
   fullPath:object.full_image_path
   completion:^(UIImage *image) {
     //if (![self.collectionView.visibleCells containsObject:cell]) return ;
     dispatch_async(dispatch_get_main_queue(), ^{
       cell.imageView.image = image;
       [cell setNeedsLayout];
     });
   }];
  
  return cell;
}



- (void)collectionView:(UICollectionView *)collectionView
didSelectItemAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutSearchObject *photoObject = self.suggestedPhotoObjects[indexPath.row];
  NSUInteger index = [self.selectedPhotoIDs indexOfObject:@(photoObject.id)];
  if (index != NSNotFound) {
    [self.selectedPhotoIDs removeObjectAtIndex:index];
  } else {
    [self.selectedPhotoIDs addObject:@(photoObject.id)];
  }
  
  DDLogVerbose(@"selectedIndex:%@ photoID:%@ selectedPhotoIDs:%@",
               indexPath.description,
               @(photoObject.id),
               self.selectedPhotoIDs);
  
  [self.collectionView reloadItemsAtIndexPaths:@[indexPath]];
  [self.collectionView deselectItemAtIndexPath:indexPath animated:YES];
}

#pragma mark - Actions

- (void)donePressed:(id)sender
{
  if (self.sharedSectionObject.id) {
    [self updateStrandWithID:@(self.sharedSectionObject.id)];
  } else {
    [self createNewStrandWithSelection];
  }
}

- (void)updateStrandWithID:(NSNumber *)strandID
{
  DFPeanutStrand *requestStrand = [[DFPeanutStrand alloc] init];
  requestStrand.id = strandID;
  
  [SVProgressHUD show];
  DFPeanutStrandAdapter *strandAdapter = [[DFPeanutStrandAdapter alloc] init];
  [strandAdapter
   performRequest:RKRequestMethodGET
   withPeanutStrand:requestStrand
   success:^(DFPeanutStrand *peanutStrand) {
     // add current user to list of users if not there
     NSNumber *userID = @([[DFUser currentUser] userID]);
     if (![peanutStrand.users containsObject:userID]) {
       peanutStrand.users = [peanutStrand.users arrayByAddingObject:userID];
     }
     
     // add any selected photos to the list of shared photos
     if (self.selectedPhotoIDs.count > 0) {
       NSMutableSet *newPhotoIDs = [[NSMutableSet alloc] initWithArray:peanutStrand.photos];
       [newPhotoIDs addObjectsFromArray:self.selectedPhotoIDs];
       peanutStrand.photos = [newPhotoIDs allObjects];
     }
     
     // Put the new peanut strand
     [strandAdapter
      performRequest:RKRequestMethodPUT withPeanutStrand:peanutStrand
      success:^(DFPeanutStrand *peanutStrand) {
        DDLogInfo(@"%@ successfully added photos to strand: %@", self.class, peanutStrand);
        [self dismissViewControllerAnimated:YES completion:^{
          [SVProgressHUD showSuccessWithStatus:@"Success!"];
        }];
        // mark the selected photos for upload
        [self markPhotosForUpload:self.selectedPhotoIDs];
      } failure:^(NSError *error) {
        [SVProgressHUD showErrorWithStatus:@"Failed."];
        DDLogError(@"%@ failed to put strand: %@, error: %@",
                   self.class, peanutStrand, error);
      }];
   } failure:^(NSError *error) {
     [SVProgressHUD showErrorWithStatus:@"Failed."];
     DDLogError(@"%@ failed to get strand: %@, error: %@",
                self.class, requestStrand, error);
   }];
}

- (void)createNewStrandWithSelection
{
  DFPeanutStrand *requestStrand = [[DFPeanutStrand alloc] init];
  requestStrand.users = @[@([[DFUser currentUser] userID])];
  requestStrand.photos = self.selectedPhotoIDs;
  requestStrand.shared = YES;
  [self setTimesForStrand:requestStrand fromPhotoObjects:self.suggestedPhotoObjects];
  
  [SVProgressHUD show];
  DFPeanutStrandAdapter *strandAdapter = [[DFPeanutStrandAdapter alloc] init];
  [strandAdapter performRequest:RKRequestMethodPOST
               withPeanutStrand:requestStrand success:^(DFPeanutStrand *peanutStrand) {
                 DDLogInfo(@"%@ successfully created strand: %@", self.class, peanutStrand);
                 [self dismissViewControllerAnimated:YES completion:^{
                   [SVProgressHUD showSuccessWithStatus:@"Success!"];
                 }];
                 [self markPhotosForUpload:peanutStrand.photos];
               } failure:^(NSError *error) {
                 [SVProgressHUD showErrorWithStatus:@"Failed."];
                 DDLogError(@"%@ failed to create strand: %@, error: %@",
                            self.class, requestStrand, error);
               }];

}

- (void)setTimesForStrand:(DFPeanutStrand *)strand fromPhotoObjects:(NSArray *)objects
{
  NSDate *minDateFound;
  NSDate *maxDateFound;
  
  for (DFPeanutSearchObject *object in objects) {
    if (!minDateFound || [object.time_taken compare:minDateFound] == NSOrderedAscending) {
      minDateFound = object.time_taken;
    }
    if (!maxDateFound || [object.time_taken compare:maxDateFound] == NSOrderedDescending) {
      maxDateFound = object.time_taken;
    }
  }
  
  strand.time_started = minDateFound;
  strand.last_photo_time = maxDateFound;
}

- (void)markPhotosForUpload:(NSArray *)photoIDs
{
  dispatch_async(dispatch_get_main_queue(), ^{
    NSArray *photos = [[DFPhotoStore sharedStore] photosWithPhotoIDs:photoIDs retainOrder:NO];
    for (DFPhoto *photo in photos) {
      photo.shouldUploadImage = YES;
    }
    [[DFPhotoStore sharedStore] saveContext];
    [[DFUploadController sharedUploadController] uploadPhotos];
  });
}

#pragma mark - DFPeoplePicker delegate

- (void)pickerController:(DFPeoplePickerViewController *)pickerController
         didPickContacts:(NSArray *)peanutContacts
{
  self.selectedContacts = peanutContacts;
}

- (void)pickerController:(DFPeoplePickerViewController *)pickerController
           textDidChange:(NSString *)text
{
  self.tableView.hidden = ![text isNotEmpty];
}

- (IBAction)collectionViewTapped:(id)sender {
  [self.tokenField resignFirstResponder];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
  [self.tokenField resignFirstResponder];
}


@end
