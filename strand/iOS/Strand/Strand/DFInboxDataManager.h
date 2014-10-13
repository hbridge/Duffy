//
//  DFInboxDataManager.h
//  Strand
//
//  Created by Derek Parham on 10/13/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFInboxDataManager : NSObject

@property (nonatomic, retain) NSArray *feedObjects;

- (void)refreshFromServer:(void(^)(void))completion;
- (BOOL)hasData;

@end
