//
//  DFSelectPhotosViewController.m
//  Strand
//
//  Created by Henry Bridge on 8/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSelectPhotosViewController.h"
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
#import "DFPeanutStrandInviteAdapter.h"
#import "Strand-Swift.h"
#import "DFPushNotificationsManager.h"
#import "DFSelectPhotosInviteSectionHeader.h"
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "DFStrandConstants.h"
#import "DFSelectPhotosInviteSectionFooter.h"
#import "AppDelegate.h"

NSUInteger const NumPhotosPerRow = 3;

@interface DFSelectPhotosViewController ()

@property (nonatomic, retain) NSArray *suggestedPhotoObjects;
@property (nonatomic, retain) NSArray *sharedPhotoObjects;
@property (nonatomic, retain) NSMutableArray *selectedPhotoIDs;
@property (nonatomic, retain) NSArray *selectedContacts;
@property (nonatomic, retain) DFPeoplePickerViewController *peoplePicker;
@property (readonly, nonatomic, retain) DFPeanutStrandInviteAdapter *inviteAdapter;
@property (readonly, nonatomic, retain) DFPeanutStrandAdapter *strandAdapter;
@property (nonatomic, retain) NSMutableDictionary *cellTemplatesByIdentifier;

@end

@implementation DFSelectPhotosViewController

@synthesize inviteAdapter = _inviteAdapter;
@synthesize strandAdapter = _strandAdapter;


- (instancetype)init
{
  return [self initWithTitle:nil
                showsToField:NO
      suggestedSectionObject:nil
          invitedStrandPosts:nil
                inviteObject:nil];
}

- (instancetype)initWithTitle:(NSString *)title
                 showsToField:(BOOL)showsToField
       suggestedSectionObject:(DFPeanutFeedObject *)suggestedSectionObject
           invitedStrandPosts:(DFPeanutFeedObject *)invitedStrandPosts
                 inviteObject:(DFPeanutFeedObject *)inviteObject
{
  self = [super initWithNibName:[self.class description] bundle:nil];
  if (self) {
    _showsToField = showsToField;
    self.cellTemplatesByIdentifier = [NSMutableDictionary new];
    [self configureNavBarWithTitle:title];
    self.suggestedSectionObject = suggestedSectionObject;
    self.invitedStrandPosts = invitedStrandPosts;
    self.inviteObject = inviteObject;
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

- (void)viewDidLayoutSubviews
{
  [super viewDidLayoutSubviews];
  
  CGFloat usableWidth = self.collectionView.frame.size.width -
  ((CGFloat)(NumPhotosPerRow - 1)  * self.flowLayout.minimumInteritemSpacing);
  CGFloat itemSize = usableWidth / (CGFloat)NumPhotosPerRow;
  self.flowLayout.itemSize = CGSizeMake(itemSize, itemSize);
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
  self.tokenField.maxHeight = self.searchBarWrapperView.bounds.size.height;
  
  NSArray *actors = nil;
  if (self.suggestedSectionObject && self.suggestedSectionObject.actors.count > 0) {
    actors = self.suggestedSectionObject.actors;
  }
  
  self.peoplePicker = [[DFPeoplePickerViewController alloc]
                       initWithTokenField:self.tokenField
                       withPeanutUsers:actors
                       tableView:self.tableView];
  self.peoplePicker.allowsMultipleSelection = YES;
  self.peoplePicker.delegate = self;
  [self.searchBarWrapperView addSubview:self.tokenField];
}

- (void)configureCollectionView
{
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFSelectPhotosInviteSectionHeader" bundle:nil]
        forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
               withReuseIdentifier:@"inviteHeaderView"];
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFSelectPhotosHeaderView" bundle:nil]
        forSupplementaryViewOfKind:UICollectionElementKindSectionHeader
               withReuseIdentifier:@"headerView"];
  [self.collectionView registerNib:[UINib nibWithNibName:@"DFSelectPhotosInviteSectionFooter" bundle:nil]
        forSupplementaryViewOfKind:UICollectionElementKindSectionFooter
               withReuseIdentifier:@"inviteFooterView"];
  
  self.flowLayout.headerReferenceSize = CGSizeMake(self.collectionView.frame.size.width,
                                                   [DFSelectPhotosHeaderView HeaderHeight]);
  
  [self.collectionView registerNib:[UINib nibWithNibName:[DFSelectablePhotoViewCell description] bundle:nil]
        forCellWithReuseIdentifier:@"selectableCell"];
  [self.collectionView registerNib:[UINib nibWithNibName:[DFPhotoViewCell description] bundle:nil]
        forCellWithReuseIdentifier:@"cell"];
  
  
}

- (void)setSuggestedSectionObject:(DFPeanutFeedObject *)sectionObject
{
  _suggestedSectionObject = sectionObject;
  sectionObject.title = @"Select Photos to Share";
  NSMutableArray *photos = [NSMutableArray new];
  self.selectedPhotoIDs = [NSMutableArray new];
  for (DFPeanutFeedObject *object in sectionObject.enumeratorOfDescendents.allObjects) {
    if ([object.type isEqual:DFFeedObjectPhoto]) {
      [photos addObject:object];
      // select all by default
      [self.selectedPhotoIDs addObject:@(object.id)];
    }
  }
  
  dispatch_async(dispatch_get_main_queue(), ^{
    self.suggestedPhotoObjects = photos;
    [self.collectionView reloadData];
  });
}

- (void)setInvitedStrandPosts:(DFPeanutFeedObject *)invitedStrandPosts
{
  _invitedStrandPosts = invitedStrandPosts;
  NSMutableArray *photos = [NSMutableArray new];
  for (DFPeanutFeedObject *object in invitedStrandPosts.enumeratorOfDescendents.allObjects) {
    if ([object.type isEqual:DFFeedObjectPhoto]) {
      [photos addObject:object];
    }
  }
  
  self.sharedPhotoObjects = photos;
  dispatch_async(dispatch_get_main_queue(), ^{
    
    [self.collectionView reloadData];
  });
}

#pragma mark - UICollectionView Data/Delegate

- (NSInteger)numberOfSectionsInCollectionView:(UICollectionView *)collectionView
{
  return (self.sharedPhotoObjects.count > 0) + 1;
}

- (UICollectionReusableView *)collectionView:(UICollectionView *)collectionView
           viewForSupplementaryElementOfKind:(NSString *)kind
                                 atIndexPath:(NSIndexPath *)indexPath
{
  if (kind == UICollectionElementKindSectionHeader) {
    return [self viewForHeaderAtIndexPath:indexPath];
  } else if (kind == UICollectionElementKindSectionFooter) {
    return [self viewForFooterAtIndexPath:indexPath];
  }

  return nil;
}

- (UICollectionReusableView *)viewForHeaderAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutFeedObject *sectionObject = [self objectForSection:indexPath.section];
  if ([sectionObject.type isEqual:DFFeedObjectInviteStrand]) {
    DFSelectPhotosInviteSectionHeader *inviteHeaderView = [self.collectionView
                                                           dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                                                           withReuseIdentifier:@"inviteHeaderView"
                                                           forIndexPath:indexPath];
    inviteHeaderView.backgroundColor = [DFStrandConstants inviteCellBackgroundColor];
    
    NSMutableString *actorsText = [[NSMutableString alloc] initWithString:@""];
    for (NSUInteger i = 0; i < sectionObject.actors.count; i++) {
      if (i > 0) [actorsText appendString:@", "];
      [actorsText appendString:[sectionObject.actors[i] display_name]];
    }
    
    inviteHeaderView.actorsLabel.text = actorsText;
    inviteHeaderView.actionLabel.text = sectionObject.title;
    
    //context
    DFPeanutFeedObject *strandPosts = sectionObject.objects.firstObject;
    NSMutableString *contextString = [NSMutableString new];
    [contextString appendString:[NSDateFormatter relativeTimeStringSinceDate:strandPosts.time_taken
                                                                  abbreviate:NO]];
    [contextString appendFormat:@" in %@", strandPosts.location];
    inviteHeaderView.contextLabel.text = contextString;
  
    return inviteHeaderView;
  } else {
    DFSelectPhotosHeaderView *headerView = [self.collectionView
                                            dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionHeader
                                            withReuseIdentifier:@"headerView"
                                            forIndexPath:indexPath];
    if (self.inviteObject) {
      NSMutableAttributedString *headerString = [[NSMutableAttributedString alloc] initWithString:@"with "];
      [headerString appendAttributedString: [self.inviteObject.objects.firstObject peopleSummaryString]];
       headerView.actorsLabel.attributedText = headerString;
    } else {
      [headerView.actorsLabel removeFromSuperview];
    }
    return headerView;
  }
}

- (UICollectionReusableView *)viewForFooterAtIndexPath:(NSIndexPath *)indexPath
{
  DFPeanutFeedObject *sectionObject = [self objectForSection:indexPath.section];
  DFSelectPhotosInviteSectionFooter *footerView = [self.collectionView
                                          dequeueReusableSupplementaryViewOfKind:UICollectionElementKindSectionFooter
                                          withReuseIdentifier:@"inviteFooterView"
                                          forIndexPath:indexPath];
  if ([sectionObject.type isEqual:DFFeedObjectInviteStrand] || !self.inviteObject) {
    // the invite section for the footer view shouldn't have any thing in it
    // or if this is not an invite, don't show the footer
    footerView.textLabel.hidden = YES;
  } else if (self.suggestedSectionObject.objects.count == 0){
    // there are no suggestions, show an explanatory message
    footerView.textLabel.hidden = NO;
    footerView.textLabel.text = @"None of your photos were taken at the same time and place.";
  } else {
    // show the explanation for why we're suggesting photos
    footerView.textLabel.hidden = NO;
    footerView.textLabel.text = @"These photos were selected because they were taken at the same time and place.";
  }
  return footerView;
}

- (CGSize)collectionView:(UICollectionView *)collectionView layout:(UICollectionViewLayout *)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section
{
  DFPeanutFeedObject *feedObject = [self objectForSection:section];
  
  NSString *identifier;
  UINib *nib;
  if ([feedObject.type isEqual:DFFeedObjectInviteStrand]) {
    identifier = @"inviteHeaderView";
    nib = [UINib nibWithNibName:NSStringFromClass([DFSelectPhotosInviteSectionHeader class]) bundle:nil];
  } else {
    identifier = @"headerView";
    nib = [UINib nibWithNibName:@"DFSelectPhotosHeaderView" bundle:nil];
  }
  
  UICollectionReusableView *templateView = self.cellTemplatesByIdentifier[identifier];
  if (!templateView) {
    templateView = [[nib instantiateWithOwner:nil options:nil] firstObject];
  }
  self.cellTemplatesByIdentifier[identifier] = templateView;
  CGFloat height = [templateView systemLayoutSizeFittingSize:UILayoutFittingCompressedSize].height;
  return CGSizeMake(self.collectionView.frame.size.width, height);
}

- (CGSize)collectionView:(UICollectionView *)collectionView
                  layout:(UICollectionViewLayout *)collectionViewLayout
referenceSizeForFooterInSection:(NSInteger)section
{
  DFPeanutFeedObject *feedObject = [self objectForSection:section];
  CGFloat height;
  if ([feedObject.type isEqual:DFFeedObjectInviteStrand]) {
    height = 50.0;
  } else {
    height = 50.0;
  }
  
  return CGSizeMake(self.collectionView.frame.size.width, height);
}

- (DFPeanutFeedObject *)objectForSection:(NSUInteger)section
{
  if (section == 0 && self.inviteObject) return self.inviteObject;
  return self.suggestedSectionObject;
}

- (NSArray *)photosForSection:(NSUInteger)section
{
  if (section == 0 && self.inviteObject) return self.sharedPhotoObjects;
  return self.suggestedPhotoObjects;
}

- (BOOL)areImagesForSectionRemote:(NSUInteger)section
{
  return ([self photosForSection:section] == self.sharedPhotoObjects);
}

const NSUInteger MaxSharedPhotosDisplayed = 3;

- (NSInteger)collectionView:(UICollectionView *)collectionView numberOfItemsInSection:(NSInteger)section
{
  DFPeanutFeedObject *objectForSection = [self objectForSection:section];
  NSUInteger numPhotosForSection = [[self photosForSection:section] count];
  if ([objectForSection.type isEqual:DFFeedObjectInviteStrand]) {
    return MIN(numPhotosForSection, MaxSharedPhotosDisplayed);
  }
  
  return numPhotosForSection;
}

- (UICollectionViewCell *)collectionView:(UICollectionView *)collectionView cellForItemAtIndexPath:(NSIndexPath *)indexPath
{
  UICollectionViewCell *cell;
  
  DFPeanutFeedObject *object = [self photosForSection:indexPath.section][indexPath.row];
  if (![self areImagesForSectionRemote:indexPath.section]) {
    cell = [self cellForLocalPhoto:object atIndexPath:indexPath];
  } else {
    cell = [self cellForRemotePhoto:object atIndexPath:indexPath];
  }
  
  return cell;
}

- (UICollectionViewCell *)cellForLocalPhoto:(DFPeanutFeedObject *)object
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
    });
    //}
  } failureBlock:^(NSError *error) {
    DDLogError(@"%@ couldn't load image for asset: %@", self.class, error);
  }];

  return cell;
}

- (UICollectionViewCell *)cellForRemotePhoto:(DFPeanutFeedObject *)object
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
  DFPeanutFeedObject *sectionObject = [self objectForSection:indexPath.section];
  if  (![sectionObject.type isEqual:DFFeedObjectSuggestedPhotos]) return;
  DFPeanutFeedObject *photoObject = [self photosForSection:indexPath.section][indexPath.row];
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
  [self.tokenField resignFirstResponder];
  if (self.invitedStrandPosts.id) {
    [self updateStrandWithID:@(self.invitedStrandPosts.id)];
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
        
        // mark the selected photos for upload
        [self markPhotosForUpload:self.selectedPhotoIDs];
        
        // mark the invite as used
        if (self.inviteObject) {
          DFPeanutStrandInviteAdapter *strandInviteAdapter = [[DFPeanutStrandInviteAdapter alloc] init];
          [strandInviteAdapter
           markInviteWithIDUsed:@(self.inviteObject.id)
           success:^(NSArray *resultObjects) {
             DDLogInfo(@"Marked invite used: %@", resultObjects.firstObject);
             [SVProgressHUD showSuccessWithStatus:@"Accepted"];
             dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
               // show the strand that we just accepted an invite to
               [(AppDelegate *)[[UIApplication sharedApplication] delegate]
                showStrandWithID:peanutStrand.id.longLongValue];
             });

             [[NSNotificationCenter defaultCenter]
              postNotificationName:DFStrandReloadRemoteUIRequestedNotificationName
              object:self];
             DDLogInfo(@"Marked invite used: %@", resultObjects.firstObject);
           } failure:^(NSError *error) {
             [SVProgressHUD showErrorWithStatus:@"Error."];
             DDLogWarn(@"Failed to mark invite used: %@", error);
           }];
        }
        
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
  // Create the strand
  DFPeanutStrand *requestStrand = [[DFPeanutStrand alloc] init];
  requestStrand.users = @[@([[DFUser currentUser] userID])];
  requestStrand.photos = self.selectedPhotoIDs;
  requestStrand.created_from_id = [NSNumber numberWithLongLong:self.suggestedSectionObject.id];
  requestStrand.shared = YES;
  [self setTimesForStrand:requestStrand fromPhotoObjects:self.suggestedPhotoObjects];
  
  [SVProgressHUD show];
  [self.strandAdapter
   performRequest:RKRequestMethodPOST
   withPeanutStrand:requestStrand success:^(DFPeanutStrand *peanutStrand) {
     DDLogInfo(@"%@ successfully created strand: %@", self.class, peanutStrand);
     
     [[NSNotificationCenter defaultCenter]
      postNotificationName:DFStrandReloadRemoteUIRequestedNotificationName
      object:self];
     
     // invite selected users
     [self sendInvitesForStrand:peanutStrand
               toPeanutContacts:self.peoplePicker.selectedPeanutContacts];
     
     // start uploading the photos
     [self markPhotosForUpload:peanutStrand.photos];
   } failure:^(NSError *error) {
     [SVProgressHUD showErrorWithStatus:@"Failed."];
     DDLogError(@"%@ failed to create strand: %@, error: %@",
                self.class, requestStrand, error);
   }];
}

- (void)sendInvitesForStrand:(DFPeanutStrand *)peanutStrand
            toPeanutContacts:(NSArray *)peanutContacts
{
  [self.inviteAdapter
   sendInvitesForStrand:peanutStrand
   toPeanutContacts:peanutContacts
   success:^(DFSMSInviteStrandComposeViewController *vc) {
     dispatch_async(dispatch_get_main_queue(), ^{
       if (vc) {
         vc.messageComposeDelegate = self;
         [self presentViewController:vc
                            animated:YES
                          completion:nil];
         [SVProgressHUD dismiss];
       } else {
         [self dismissWithErrorString:nil];
       }
     });
   } failure:^(NSError *error) {
     [self dismissWithErrorString:@"Invite failed"];
     DDLogError(@"%@ failed to invite to strand: %@, error: %@",
                self.class, peanutStrand, error);
   }];
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller
                 didFinishWithResult:(MessageComposeResult)result
{
  [self dismissWithErrorString:(result == MessageComposeResultSent ? nil : @"Cancelled")];
}

- (void)dismissWithErrorString:(NSString *)errorString
{
  void (^completion)(void) = ^{
    if (!errorString) {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [SVProgressHUD showSuccessWithStatus:@"Sent!"];
      });
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [[DFPushNotificationsManager sharedManager] promptForPushNotifsIfNecessary];
      });
    } else {
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [SVProgressHUD showErrorWithStatus:errorString];
      });
    }
  };
  
  if (self.presentedViewController) {
    [self dismissViewControllerAnimated:YES completion:completion];
    [self.navigationController popViewControllerAnimated:NO];
  } else {
    [self.navigationController popViewControllerAnimated:YES];
    completion();
  }
}

- (void)setTimesForStrand:(DFPeanutStrand *)strand fromPhotoObjects:(NSArray *)objects
{
  NSDate *minDateFound;
  NSDate *maxDateFound;
  
  for (DFPeanutFeedObject *object in objects) {
    if (!minDateFound || [object.time_taken compare:minDateFound] == NSOrderedAscending) {
      minDateFound = object.time_taken;
    }
    if (!maxDateFound || [object.time_taken compare:maxDateFound] == NSOrderedDescending) {
      maxDateFound = object.time_taken;
    }
  }
  
  strand.first_photo_time = minDateFound;
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

    [self cachePhotosInImageStore:photoIDs];
  });
}

- (void)cachePhotosInImageStore:(NSArray *)photoIDs
{
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    @autoreleasepool {
      NSManagedObjectContext *context = [DFPhotoStore createBackgroundManagedObjectContext];
      NSArray *photos = [DFPhotoStore photosWithPhotoIDs:photoIDs retainOrder:NO inContext:context];
      for (DFPhoto *photo in photos) {
        DFPhotoIDType photoID = photo.photoID;
        [photo.asset loadUIImageForThumbnail:^(UIImage *image) {
          [[DFImageStore sharedStore]
           setImage:image
           type:DFImageThumbnail
           forID:photoID
           completion:^(NSError *error) {
             if (!error)
               DDLogVerbose(@"%@ successfully cached thumnbnail for %@", self.class, @(photoID));
             else
               DDLogError(@"%@ failed to cache thumbnail:%@", self.class, error);
           }];
        } failureBlock:^(NSError *error) {
          DDLogError(@"%@ failed to cache thumbnail:%@", self.class, error);
        }];
        [photo.asset loadHighResImage:^(UIImage *image) {
          [[DFImageStore sharedStore]
           setImage:image
           type:DFImageFull
           forID:photoID
           completion:^(NSError *error) {
             if (!error)
               DDLogVerbose(@"%@ successfully cached full image for %@", self.class, @(photoID));
             else
               DDLogError(@"%@ failed to cache full image:%@", self.class, error);
             
           }];
        } failureBlock:^(NSError *error) {
          DDLogError(@"%@ failed to cache full image:%@", self.class, error);
        }];
      }
    }
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

- (DFPeanutStrandInviteAdapter *)inviteAdapter
{
  if (!_inviteAdapter) _inviteAdapter = [[DFPeanutStrandInviteAdapter alloc] init];
  return _inviteAdapter;
}

- (DFPeanutStrandAdapter *)strandAdapter
{
  if (!_strandAdapter) _strandAdapter = [[DFPeanutStrandAdapter alloc] init];
  return _strandAdapter;
}



@end
