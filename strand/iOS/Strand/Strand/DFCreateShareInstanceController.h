//
//  DFCreateShareInstanceController.h
//  Strand
//
//  Created by Henry Bridge on 1/20/15.
//  Copyright (c) 2015 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutFeedObject.h"

@interface DFCreateShareInstanceController : NSObject


typedef void (^DFCreateShareInstanceCompletionBlock)(BOOL allInvitesSent, NSError *error);

+ (void)createShareInstanceWithPhotos:(NSArray *)photos
                       fromSuggestion:(DFPeanutFeedObject *)suggestion
                       inviteContacts:(NSArray *)contacts
                           addCaption:(NSString *)caption
                 parentViewController:(UIViewController *)parentViewController
                 enableOptimisticSend:(BOOL)enableOptimisticSend
                    completionHandler:(DFCreateShareInstanceCompletionBlock)completionBlock;

@end
