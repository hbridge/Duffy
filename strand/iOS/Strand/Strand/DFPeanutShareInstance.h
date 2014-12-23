//
//  DFPeanutShareInstance.h
//  Strand
//
//  Created by Henry Bridge on 12/23/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutObject.h"

@interface DFPeanutShareInstance : NSObject <DFPeanutObject>

/*
 user = models.ForeignKey(User, db_index=True)
 photo = models.ForeignKey(Photo, db_index=True)
 users = models.ManyToManyField(User, related_name = "si_users")
 shared_at_timestamp = models.DateTimeField(db_index=True, null=True)
 last_action_timestamp = models.DateTimeField(db_index=True, null=True)
 added = models.DateTimeField(auto_now_add=True)
 updated = models.DateTimeField(auto_now=True)
 */

@property (nonatomic, retain) NSNumber *id;
@property (nonatomic, retain) NSNumber *user;
@property (nonatomic, retain) NSNumber *photo;
@property (nonatomic, retain) NSArray *users;
@property (nonatomic, retain) NSDate *shared_at_timestamp;
@property (nonatomic, retain) NSDate *last_action_timestamp;
@property (nonatomic, retain) NSDate *added;
@property (nonatomic, retain) NSDate *updated;

@end
