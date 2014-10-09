//
//  DFAcceptInviteViewController.m
//  Strand
//
//  Created by Henry Bridge on 10/6/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFAcceptInviteViewController.h"
#import "DFImageDataSource.h"
#import "DFSelectPhotosController.h"
#import "DFPeanutStrandAdapter.h"
#import "DFPeanutStrandFeedAdapter.h"
#import "DFPeanutStrandInviteAdapter.h"
#import "SVProgressHUD.h"
#import "NSArray+DFHelpers.h"
#import "AppDelegate.h"
#import "DFStrandConstants.h"
#import "DFPhotoStore.h"

@interface DFAcceptInviteViewController ()

@property (nonatomic, retain) DFPeanutFeedObject *inviteObject;
@property (nonatomic, retain) DFPeanutFeedObject *invitedStrandPosts;
@property (nonatomic, retain) DFPeanutFeedObject *suggestedPhotosPosts;

@property (nonatomic, retain) DFImageDataSource *invitedPhotosDatasource;
@property (nonatomic, retain) DFSelectPhotosController *suggestedPhotosController;

@property (readonly, nonatomic, retain) DFPeanutStrandAdapter *strandAdapter;
@property (readonly, nonatomic, retain) DFPeanutStrandInviteAdapter *inviteAdapter;
@property (readonly, nonatomic, retain) DFPeanutStrandFeedAdapter *feedAdapter;

@property (nonatomic, retain) NSTimer *refreshTimer;

@end

@implementation DFAcceptInviteViewController

@synthesize strandAdapter = _strandAdapter;
@synthesize inviteAdapter = _inviteAdapter;
@synthesize feedAdapter = _feedAdapter;

- (instancetype)initWithInviteObject:(DFPeanutFeedObject *)inviteObject
{
  self = [super init];
  if (self) {
    self.navigationItem.title = @"Swap Photos";
    
    [self setupViewWithInviteObject:inviteObject];
  }
  return self;
}

- (void)setupViewWithInviteObject:(DFPeanutFeedObject *)inviteObject
{
  _inviteObject = inviteObject;
  _invitedStrandPosts = [[inviteObject subobjectsOfType:DFFeedObjectStrandPosts]
                         firstObject];
  _suggestedPhotosPosts = [[inviteObject subobjectsOfType:DFFeedObjectSuggestedPhotos]
                           firstObject];
  
}

- (void)viewDidLoad {
  [super viewDidLoad];

  [self configureInviteArea];
  [self configureMatchedArea];
  
  if ([self.inviteObject.ready isEqual:@(NO)]) {
    DDLogVerbose(@"Invite not ready, setting up timer...");
    self.refreshTimer = [NSTimer scheduledTimerWithTimeInterval:.5
                                                         target:self
                                                       selector:@selector(refreshFromServer)
                                                       userInfo:nil
                                                        repeats:YES];
  }
}

- (BOOL)hidesBottomBarWhenPushed
{
  return YES;
}


- (void)configureInviteArea
{
  // aesthetics
  self.inviteWrapper.layer.cornerRadius = 4.0;
  self.inviteWrapper.clipsToBounds = YES;
  
  //name and title
  self.actorLabel.text = self.inviteObject.actorsString;
  self.titleLabel.text = self.invitedStrandPosts.title;
  
  //collection view
  NSMutableArray *allPhotos = [NSMutableArray new];
  for (DFPeanutFeedObject *post in self.invitedStrandPosts.objects) {
    [allPhotos addObjectsFromArray:post.objects];
  }
  self.invitedPhotosDatasource = [[DFImageDataSource alloc]
                                  initWithFeedPhotos:allPhotos
                                  collectionView:self.invitedCollectionView
                                  sourceMode:DFImageDataSourceModeRemote
                                  imageType:DFImageThumbnail];
}

- (void)configureMatchedArea
{
  // hide the match results view until the match button is pressed and we have results
  self.matchResultsView.hidden = YES;
  
  // set the title for the match results area
  self.matchResultsTitleLabel.text = self.invitedStrandPosts.title;
  
  // set the layout attributes
  static int itemsPerRow = 2;
  static CGFloat interItemSpacing = 0.5;
  static CGFloat interItemSpacingPerRow = 0.5 * (2 - 1);
  CGFloat size1d = ([[UIScreen mainScreen] bounds].size.width - interItemSpacingPerRow)
  / (CGFloat)itemsPerRow;
  size1d = floor(size1d);
  self.matchedFlowLayout.itemSize = CGSizeMake(size1d, size1d);
  self.matchedFlowLayout.minimumInteritemSpacing = interItemSpacing;
  self.matchedFlowLayout.minimumLineSpacing = interItemSpacing;
  
  // create the suggested photos select controller to populate the data
  NSMutableArray *suggestedPhotos = [NSMutableArray new];
  for (DFPeanutFeedObject *suggestedPhotosSection in self.suggestedPhotosPosts.objects) {
    [suggestedPhotos addObjectsFromArray:suggestedPhotosSection.enumeratorOfDescendents.allObjects];
  }
  
  if (suggestedPhotos.count > 0) {
    self.suggestedPhotosController = [[DFSelectPhotosController alloc]
                                      initWithFeedPhotos:suggestedPhotos
                                      collectionView:self.matchedCollectionView
                                      sourceMode:DFImageDataSourceModeLocal
                                      imageType:DFImageFull];
    self.suggestedPhotosController.delegate = self;
    self.matchResultsHeader.hidden = NO;
  } else {
    self.matchResultsHeader.hidden = YES;
    self.noMatchingPhotosLabel.hidden = NO;
  }
  self.scrollView.contentInset = UIEdgeInsetsMake(0, 0, self.swapPhotosBar.frame.size.height + 16, 0);
}


- (IBAction)matchButtonPressed:(UIButton *)sender {
  [self.matchButtonWrapper removeFromSuperview];
  self.matchingActivityWrapper.hidden = NO;

  if ([self.inviteObject.ready isEqual:@(YES)]) {
    DDLogVerbose(@"Invite ready, showing in 1 second");
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
      [self showMatchedArea];
    });
  } else {
    // If we're not ready, the timer is running and it will show the matched area once the invite is ready
    DDLogVerbose(@"Invite not ready, relying upon timer");
  }
}

- (void)showMatchedArea
{
  [self setMatchedAreaAttributes];
  [self configureSwapPhotosButtonText];
  
  self.matchingActivityWrapper.hidden = YES;
  self.matchResultsView.hidden = NO;
  self.swapPhotosBar.hidden = NO;
}

- (void)configureSwapPhotosButtonText
{
  int selectedCount = (int)self.suggestedPhotosController.selectedPhotoIDs.count;
  NSString *buttonText;
  if (selectedCount == 0) {
    buttonText = @"View Photos";
  } else {
    buttonText = [NSString stringWithFormat:@"Swap %d Photos", selectedCount];
  }
  
  [self.swapPhotosButton setTitle:buttonText forState:UIControlStateNormal];
}

- (void)setMatchedAreaAttributes
{
  // set collection view height
  CGSize contentSize = self.matchedFlowLayout.collectionViewContentSize;
  self.matchedCollectionViewHeight.constant = contentSize.height;
}


- (void)selectPhotosController:(DFSelectPhotosController *)selectPhotosController selectedFeedObjectsChanged:(NSArray *)newSelectedFeedObjects
{
  [self configureSwapPhotosButtonText];
}

#pragma mark - Swap Photos Handler


- (IBAction)swapPhotosButtonPressed:(id)sender {
  [self acceptInvite];
}

- (void)refreshFromServer
{
  [[UIApplication sharedApplication] setNetworkActivityIndicatorVisible:YES];
  [self.feedAdapter
   fetchInboxWithCompletion:^(DFPeanutObjectsResponse *response,
                              NSData *responseHash,
                              NSError *error) {
     DDLogVerbose(@"Got back inbox...");
     for (DFPeanutFeedObject *object in response.objects) {
       if (object.id == self.inviteObject.id && [object.ready isEqual: @(YES)]) {
         DDLogVerbose(@"Invite ready.  Showing view");
         dispatch_async(dispatch_get_main_queue(), ^{
           [self setupViewWithInviteObject:object];
           [self configureMatchedArea];
           
           if (self.matchingActivityWrapper.hidden == NO) {
             [self showMatchedArea];
           }
           
         });
         [self.refreshTimer invalidate];
         self.refreshTimer = nil;
       }
     }
  }];
}

- (void)acceptInvite
{
  DFPeanutStrand *requestStrand = [[DFPeanutStrand alloc] init];
  requestStrand.id = @(self.invitedStrandPosts.id);
  NSArray *selectedPhotoIDs = self.suggestedPhotosController.selectedPhotoIDs;
  
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
     if (selectedPhotoIDs.count > 0) {
       NSMutableSet *newPhotoIDs = [[NSMutableSet alloc] initWithArray:peanutStrand.photos];
       [newPhotoIDs addObjectsFromArray:selectedPhotoIDs];
       peanutStrand.photos = [newPhotoIDs allObjects];
     }
     
     // Put the new peanut strand
     [strandAdapter
      performRequest:RKRequestMethodPUT withPeanutStrand:peanutStrand
      success:^(DFPeanutStrand *peanutStrand) {
        DDLogInfo(@"%@ successfully added photos to strand: %@", self.class, peanutStrand);
        // cache the photos locally
        [[DFPhotoStore sharedStore] cachePhotoIDsInImageStore:selectedPhotoIDs];
        
        // mark the invite as used
        if (self.inviteObject) {
          DFPeanutStrandInviteAdapter *strandInviteAdapter = [[DFPeanutStrandInviteAdapter alloc] init];
          [strandInviteAdapter
           markInviteWithIDUsed:@(self.inviteObject.id)
           success:^(NSArray *resultObjects) {
             DDLogInfo(@"Marked invite used: %@", resultObjects.firstObject);
             // show the strand that we just accepted an invite to
             [[DFPhotoStore sharedStore] cachePhotoIDsInImageStore:selectedPhotoIDs];
             [(AppDelegate *)[[UIApplication sharedApplication] delegate]
              showStrandWithID:peanutStrand.id.longLongValue completion:^{
                [SVProgressHUD showSuccessWithStatus:@"Accepted"];
                [[NSNotificationCenter defaultCenter]
                 postNotificationName:DFStrandReloadRemoteUIRequestedNotificationName
                 object:self];
                // mark the selected photos for upload AFTER all other work completed to prevent
                // slowness in downloading other photos etc
                [[DFPhotoStore sharedStore] markPhotosForUpload:selectedPhotoIDs];
              }];
           } failure:^(NSError *error) {
             [SVProgressHUD showErrorWithStatus:@"Error."];
             DDLogWarn(@"Failed to mark invite used: %@", error);
             // mark photos for upload even if we fail to mark the invite used since they're
             // now part of the strand
             [[DFPhotoStore sharedStore] markPhotosForUpload:selectedPhotoIDs];
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
  
  // Now go through each of the private strands and update their visibility to NO
  //   Doing this seperate from the strand update code above so we can do it in parallel
  // For a suggestion type, the subobjects are strand objects
  for (DFPeanutFeedObject *object in self.suggestedPhotosPosts.objects) {
    DFPeanutStrand *privateStrand = [[DFPeanutStrand alloc] init];
    privateStrand.id = [NSNumber numberWithLongLong:object.id];
    
    [strandAdapter
     performRequest:RKRequestMethodGET
     withPeanutStrand:privateStrand
     success:^(DFPeanutStrand *peanutStrand) {
       peanutStrand.suggestible = @(NO);
       
       // Put the peanut strand
       [strandAdapter
        performRequest:RKRequestMethodPUT withPeanutStrand:peanutStrand
        success:^(DFPeanutStrand *peanutStrand) {
          DDLogInfo(@"%@ successfully updated private strand to set visible false: %@", self.class, peanutStrand);
        } failure:^(NSError *error) {
          DDLogError(@"%@ failed to put private strand: %@, error: %@",
                     self.class, peanutStrand, error);
        }];
     } failure:^(NSError *error) {
       DDLogError(@"%@ failed to get private strand: %@, error: %@",
                  self.class, requestStrand, error);
     }];
  }
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

- (DFPeanutStrandFeedAdapter *)feedAdapter
{
  if (!_feedAdapter) _feedAdapter = [[DFPeanutStrandFeedAdapter alloc] init];
  return _feedAdapter;
}


@end
