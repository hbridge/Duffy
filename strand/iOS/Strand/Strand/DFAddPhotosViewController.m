//
//  DFAddPhotosViewController.m
//  Strand
//
//  Created by Henry Bridge on 10/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFAddPhotosViewController.h"
#import "DFPeanutStrandAdapter.h"
#import "DFPeanutStrandInviteAdapter.h"
#import "DFPhotoStore.h"
#import "SVProgressHUD.h"
#import "DFStrandConstants.h"


@interface DFAddPhotosViewController ()

@property (readonly, nonatomic, retain) DFPeanutStrandAdapter *strandAdapter;
@property (readonly, nonatomic, retain) DFPeanutStrandInviteAdapter *inviteAdapter;

@end

@implementation DFAddPhotosViewController

@synthesize strandAdapter = _strandAdapter;
@synthesize inviteAdapter = _inviteAdapter;

- (instancetype)initWithSuggestions:(NSArray *)suggestedSections invite:(DFPeanutFeedObject *)invite
{
  self = [self initWithSuggestions:suggestedSections];
  if (self) {
    _inviteObject = invite;
  }
  return self;
}

- (instancetype)initWithSuggestions:(NSArray *)suggestions
{
  self = [super initWithSuggestions:suggestions];
  if (self) {
    [self configureNavBar];
  }
  return self;
}

- (void)configureNavBar
{
  self.navigationItem.title = @"Select Photos";
}

#pragma mark - Actions

- (void)nextPressed:(id)sender {
  if (self.inviteObject) {
    [self acceptInvite];
  }
}

- (void)acceptInvite
{
  DFPeanutFeedObject *invitedStrandPosts = [[self.inviteObject subobjectsOfType:DFFeedObjectStrandPosts] firstObject];
  DFPeanutStrand *requestStrand = [[DFPeanutStrand alloc] init];
  requestStrand.id = @(invitedStrandPosts.id);
  NSArray *selectedPhotoIDs = self.selectPhotosController.selectedPhotoIDs;
  
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
             [self dismissViewControllerAnimated:YES completion:^{
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
  for (DFPeanutFeedObject *object in self.suggestedSections) {
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

@end
