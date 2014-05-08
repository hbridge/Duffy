//
//  DFFaceFeature.h
//  Duffy
//
//  Created by Henry Bridge on 5/7/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class DFPhoto;

@interface DFFaceFeature : NSManagedObject

@property (nonatomic) BOOL hasSmile;
@property (nonatomic) BOOL hasBlink;
@property (nonatomic, retain) NSString *boundsString;
@property (nonatomic, retain) DFPhoto *photo;

@end
