//
//  DFPeanutSearchObject.h
//  Duffy
//
//  Created by Henry Bridge on 6/2/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPeanutObject.h"
#import "DFTypedefs.h"

@interface DFPeanutSearchObject : NSObject<DFPeanutObject>

typedef NSString *const DFSearchObjectType;

extern DFSearchObjectType DFSearchObjectSection;
extern DFSearchObjectType DFSearchObjectPhoto;
extern DFSearchObjectType DFSearchObjectCluster;


@property (nonatomic, retain) DFSearchObjectType type;
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSArray *objects;
@property (nonatomic) DFPhotoIDType id;

@end
