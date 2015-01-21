//
//  DFCreateShareInstanceController.m
//  Strand
//
//  Created by Henry Bridge on 1/20/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import "DFCreateShareInstanceController.h"
#import <SVProgressHUD/SVProgressHUD.h>
#import "DFPeanutContact.h"
#import "DFPeanutFeedDataManager.h"
#import "DFPeanutShareInstance.h"
#import "DFSMSInviteStrandComposeViewController.h"

@implementation DFCreateShareInstanceController

+ (void)createShareInstanceWithPhotos:(NSArray *)photos
                       fromSuggestion:(DFPeanutFeedObject *)suggestion
                       inviteContacts:(NSArray *)contacts
                           addCaption:(NSString *)caption
                 parentViewController:(UIViewController *)parentViewController
                 enableOptimisticSend:(BOOL)enableOptimisticSend
                    uiCompleteHandler:(DFVoidBlock)uiCompleteHandler
                              success:(DFSuccessBlock)success
                              failure:(DFFailureBlock)failure
{
  
  BOOL requireServerRoundtrip = !enableOptimisticSend;
  NSMutableArray *phoneNumbers = [NSMutableArray new];
  for (DFPeanutContact *contact in contacts) {
    [phoneNumbers addObject:contact.phone_number];
    if (![[DFPeanutFeedDataManager sharedManager] userWithPhoneNumber:contact.phone_number]) {
      requireServerRoundtrip = YES;
      break;
    }
  }
  
  [[DFPeanutFeedDataManager sharedManager]
   sharePhotoObjects:photos
   withPhoneNumbers:phoneNumbers
   success:^(NSArray *shareInstances, NSArray *unAuthedPhoneNumbers) {
     DFPeanutShareInstance *shareInstance = shareInstances.firstObject;
     // add the caption if there is one, but success or failure has no bearing
     if ([caption isNotEmpty]) {
       [[DFPeanutFeedDataManager sharedManager]
        addComment:caption
        toPhotoID:shareInstance.photo.longLongValue
        shareInstance:shareInstance.id.longLongValue
        success:nil
        failure:nil];
     }
     
     // send SMS if there were any users created as part of creating the share instance
     if (unAuthedPhoneNumbers.count > 0) {
       dispatch_async(dispatch_get_main_queue(), ^{
         [DFSMSInviteStrandComposeViewController
          showWithParentViewController:parentViewController
          phoneNumbers:unAuthedPhoneNumbers
          fromDate:((DFPeanutFeedObject *)photos.firstObject).time_taken
          completionBlock:^(MessageComposeResult result) {
            if (success) success();
            
            if (requireServerRoundtrip) {
              if (result == MessageComposeResultSent) {
                [SVProgressHUD showSuccessWithStatus:@"Sent!"];
              } else {
                NSString *errorString;
                if (result == MessageComposeResultCancelled) errorString = @"Invite Text Cancelled";
                else errorString = @"Failed";
                [SVProgressHUD showErrorWithStatus:errorString];
              }
              
              if (uiCompleteHandler) uiCompleteHandler();
            }
          }];
       });
     } else {
       if (success) success();
       if (requireServerRoundtrip) {
         [SVProgressHUD showSuccessWithStatus:@"Sent!"];
         if (uiCompleteHandler) uiCompleteHandler();
       }
     }
   } failure:^(NSError *error) {
     DDLogError(@"%@ send failed: %@", self.class, error);
     if (failure) failure(error);
     if (requireServerRoundtrip) {
       [SVProgressHUD showErrorWithStatus:@"Failed"];
       if (uiCompleteHandler) uiCompleteHandler();
     }
   }];
  
  if (requireServerRoundtrip) {
    [SVProgressHUD show];
  } else {
    if (uiCompleteHandler) uiCompleteHandler();
    [SVProgressHUD showSuccessWithStatus:@"Sent!"];
  }
}



@end
