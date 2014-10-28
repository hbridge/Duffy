//
//  DFPeanutStrand.h
//  Strand
//
//  Created by Henry Bridge on 8/29/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutObject.h"

/*{
  "id": 154,
  "time_started": "2014-08-27T20:42:52Z",
  "last_photo_time": "2014-08-27T20:42:52Z",
  "shared": true,
  "added": "2014-08-27T20:53:09Z",
  "updated": "2014-08-27T20:53:09Z",
  "photos": [
             316422
             ],
  "users": [
            374
            ]
}*/

@interface DFPeanutStrand : NSObject <DFPeanutObject>

@property (nonatomic, retain) NSNumber  *id;
@property (nonatomic, retain) NSDate *first_photo_time;
@property (nonatomic, retain) NSDate *last_photo_time;
@property (nonatomic, retain) NSNumber *private;
@property (nonatomic, retain) NSDate *added;
@property (nonatomic, retain) NSDate *updated;
@property (nonatomic, retain) NSNumber *suggestible;
@property (nonatomic, retain) NSArray *photos; // array of photo IDs
@property (nonatomic, retain) NSArray *users; // array of photo IDs

@end
