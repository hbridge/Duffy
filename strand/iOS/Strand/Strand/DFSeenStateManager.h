//
//  DFSeenStateManager.h
//  Strand
//
//  Created by Henry Bridge on 10/20/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutUserObject.h"
#import "DFPeanutFeedObject.h"

@interface DFSeenStateManager : NSObject


+ (DFSeenStateManager *)sharedManager;

/* seenPrivateStrandIDsForUser 
 Returns an array of Private Strand IDs that the user has seen by browsing in the friend profile
 view
 */
 
- (NSArray *)seenPrivateStrandIDsForUser:(DFPeanutUserObject *)user;

/*addSeenPrivateStrandIDs:forUser:
 Adds the IDs in the given array as seen, so they will be returned as seen in 
 seenPrivateStrandIDsForUser
 */
- (void)addSeenPrivateStrandIDs:(NSArray *)privateStrands forUser:(DFPeanutUserObject *)user;

@end
