//
//  DFUserActionStore.h
//  Strand
//
//  Created by Henry Bridge on 7/15/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFUserActionStore : NSObject

typedef NSString *const DFUserActionType;
extern DFUserActionType UserActionTakePhoto;

+ (void)incrementCountForAction:(DFUserActionType)action;
+ (unsigned int)actionCountForAction:(DFUserActionType)action;

@end
