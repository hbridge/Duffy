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
#import "DFAlertController.h"

static NSMutableSet *textedPhoneNumberStrings;

@implementation DFCreateShareInstanceController

+ (void)initialize
{
  textedPhoneNumberStrings = [[NSMutableSet alloc] init];
}

+ (void)createShareInstanceWithPhotos:(NSArray *)photos
                       fromSuggestion:(DFPeanutFeedObject *)suggestion
                       inviteContacts:(NSArray *)contacts
                           addCaption:(NSString *)caption
                 parentViewController:(UIViewController *)parentViewController
                 enableOptimisticSend:(BOOL)enableOptimisticSend
                    completionHandler:(DFCreateShareInstanceCompletionBlock)completionBlock
{
  
  BOOL requireServerRoundtrip = !enableOptimisticSend;
  NSMutableArray *phoneNumbers = [NSMutableArray new];
  for (DFPeanutContact *contact in contacts) {
    [phoneNumbers addObject:contact.phone_number];
    DFPeanutUserObject *user = [[DFPeanutFeedDataManager sharedManager] userWithPhoneNumber:contact.phone_number];
    if (!user || ![user hasAuthedPhone]) {
      requireServerRoundtrip = YES;
      break;
    }
  }
  
  DDLogInfo(@"%@ create share instance, requreServerRoundtrip %@", self, @(requireServerRoundtrip));
  // Create the Share Instance
  [[DFPeanutFeedDataManager sharedManager]
   sharePhotoObjects:photos
   withPhoneNumbers:phoneNumbers
   success:^(NSArray *shareInstances, NSArray *unAuthedPhoneNumbers) {
     // Successfully create the share instance
     DDLogInfo(@"%@ created share instances: %@, unauthedPhoneNumbers:%@",
               self,
               shareInstances,
               @(unAuthedPhoneNumbers.count));
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
         // make sure we haven't texted the numbers yet this session
         NSMutableSet *numbersToText = [[NSMutableSet alloc] initWithArray:unAuthedPhoneNumbers];
         [numbersToText minusSet:textedPhoneNumberStrings];
         if (numbersToText.count == 0) {
           if (requireServerRoundtrip) {
             [SVProgressHUD showSuccessWithStatus:@"Sent!"];
             if (completionBlock) completionBlock(YES, nil);
           }
           
           return;
         }
         
         NSDate *fromDate = ((DFPeanutFeedObject *)photos.firstObject).time_taken;
         [DFSMSInviteStrandComposeViewController
          showWithParentViewController:parentViewController
          phoneNumbers:numbersToText.allObjects
          fromDate:fromDate
          warnOnCancel:YES
          completionBlock:^(MessageComposeResult result) {
            if (requireServerRoundtrip) {
              if (result == MessageComposeResultSent) {
                // The user sent the SMS to all unauthed phone numbers
                [SVProgressHUD showSuccessWithStatus:@"Sent!"];
                dispatch_async(dispatch_get_main_queue(), ^{
                  // keep track of the fact that these numbers have been sent to
                  [textedPhoneNumberStrings unionSet:numbersToText];
                  if (completionBlock) completionBlock(YES, nil);
                });
              } else {
                DDLogInfo(@"%@ invites not sent", self);
                [SVProgressHUD showErrorWithStatus:@"Invites not sent."];
                if (completionBlock) completionBlock(NO, nil);
              }
            }
          }];
       });
     } else {
       // No unauthed accounts are being sent to
       if (requireServerRoundtrip) {
         [SVProgressHUD showSuccessWithStatus:@"Sent!"];
         if (completionBlock) completionBlock(YES, nil);
       }
     }
   } failure:^(NSError *error) {
     // Failed to create the strand
     DDLogError(@"%@ send failed: %@", self.class, error);
     if (requireServerRoundtrip) {
       [SVProgressHUD showErrorWithStatus:@"Failed"];
       if (completionBlock) completionBlock(NO, error);
     }
   }];
  
  if (requireServerRoundtrip) {
    [SVProgressHUD show];
  } else {
    // This is an optimistic send, immediately return with success
    if (completionBlock) completionBlock(YES, nil);
    [SVProgressHUD showSuccessWithStatus:@"Sent!"];
  }
}

@end
