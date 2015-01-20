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

+ (void)createShareInstanceWithPhotos:(NSArray *)photos
                       fromSuggestion:(DFPeanutFeedObject *)suggestion
                       inviteContacts:(NSArray *)contacts
                           addCaption:(NSString *)caption
                 parentViewController:(UIViewController *)parentViewController
                 enableOptimisticSend:(BOOL)enableOptimisticSend
                    uiCompleteHandler:(DFVoidBlock)uiCompleteHandler
                              success:(DFSuccessBlock)success
                              failure:(DFFailureBlock)failure;

@end
