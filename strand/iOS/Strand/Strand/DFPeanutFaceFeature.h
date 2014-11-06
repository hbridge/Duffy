//
//  DFPeanutFaceFeature.h
//  Duffy
//
//  Created by Henry Bridge on 5/8/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFJSONConvertible.h"

@class RKObjectMapping;

@interface DFPeanutFaceFeature : NSObject <DFJSONConvertible>

@property (nonatomic, retain) NSString *bounds;
@property (nonatomic) BOOL has_smile;
@property (nonatomic) BOOL has_blink;


+ (RKObjectMapping *)objectMapping;
+ (NSSet *)peanutFaceFeaturesFromDFFaceFeatures:(NSSet *)faceFeatures;
- (NSDictionary *)dictionary;

@end
