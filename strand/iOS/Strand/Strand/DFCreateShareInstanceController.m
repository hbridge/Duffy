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
                    uiCompleteHandler:(DFVoidBlock)uiCompleteHandler
                              success:(DFSuccessBlock)success
                              failure:(DFFailureBlock)failure
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
  
  [[DFPeanutFeedDataManager sharedManager]
   sharePhotoObjects:photos
   withPhoneNumbers:phoneNumbers
   success:^(NSArray *shareInstances, NSArray *unAuthedPhoneNumbers) {
     // the share instance has been successfully created, call success block
     if (success) success();
     
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
           }
           if (uiCompleteHandler) uiCompleteHandler();
           return;
         }
         
         NSDate *fromDate = ((DFPeanutFeedObject *)photos.firstObject).time_taken;
         [DFSMSInviteStrandComposeViewController
          showWithParentViewController:parentViewController
          phoneNumbers:numbersToText.allObjects
          fromDate:fromDate
          completionBlock:^(MessageComposeResult result) {
            if (requireServerRoundtrip) {
              if (result == MessageComposeResultSent) {
                [SVProgressHUD showSuccessWithStatus:@"Sent!"];
                dispatch_async(dispatch_get_main_queue(), ^{
                  // keep track of the fact that these numbers have been sent to
                  [textedPhoneNumberStrings unionSet:numbersToText];
                  if (uiCompleteHandler) uiCompleteHandler();
                });
              } else {
                [self showTextCancelledWithParent:parentViewController
                                     phoneNumbers:numbersToText.allObjects
                                         fromDate:fromDate
                                uiCompleteHandler:uiCompleteHandler];
              }
            }
          }];
       });
     } else {
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

+ (void)showTextCancelledWithParent:(UIViewController *)parentViewController
                       phoneNumbers:(NSArray *)phoneNumbers
                           fromDate:(NSDate *)fromDate
                  uiCompleteHandler:(DFVoidBlock)uiCompleteHandler
{
  DFAlertController *alert = [DFAlertController
                              alertControllerWithTitle:@"Not Sent"
                              message:@"Some recipients are not yet Swap members and won't be notified unless you send them a text. Send a text now?"
                              preferredStyle:DFAlertControllerStyleAlert];
  [alert
   addAction:[DFAlertAction
              actionWithTitle:@"Send Text"
              style:DFAlertActionStyleDefault
              handler:^(DFAlertAction *action) {
                [DFSMSInviteStrandComposeViewController
                 showWithParentViewController:parentViewController
                 phoneNumbers:phoneNumbers
                 fromDate:fromDate
                 completionBlock:^(MessageComposeResult result) {
                   if (result == MessageComposeResultSent) {
                     [SVProgressHUD showSuccessWithStatus:@"Sent!"];
                     dispatch_async(dispatch_get_main_queue(), ^{
                       // keep track of the fact that these numbers have been sent to
                       [textedPhoneNumberStrings addObjectsFromArray:phoneNumbers];
                     });
                   }
                   if (uiCompleteHandler) uiCompleteHandler();
                 }];
              }]];
  [alert
   addAction:[DFAlertAction
              actionWithTitle:@"Cancel"
              style:DFAlertActionStyleCancel
              handler:^(DFAlertAction *action) {
                if (uiCompleteHandler) uiCompleteHandler();
              }]];
  [alert showWithParentViewController:parentViewController animated:YES completion:nil];
}

@end
