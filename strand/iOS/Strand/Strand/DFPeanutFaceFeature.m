//
//  DFPeanutFaceFeature.m
//  Duffy
//
//  Created by Henry Bridge on 5/8/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPeanutFaceFeature.h"
#import "DFFaceFeature.h"
#import <Restkit.h>
#import "NSDictionary+DFJSON.h"

@implementation DFPeanutFaceFeature

+ (RKObjectMapping *)objectMapping
{
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[DFPeanutFaceFeature class]];
  [objectMapping addAttributeMappingsFromArray:[DFPeanutFaceFeature attributes]];
    
  return objectMapping;
}

+ (NSArray *)attributes
{
  return @[@"bounds", @"has_smile", @"has_blink"];
}


- (id)initWithDFFaceFeature:(DFFaceFeature *)faceFeature
{
  self = [super init];
  if (self) {
    CGRect bounds = [faceFeature.bounds CGRectValue];
    self.bounds = NSStringFromCGRect(bounds);
    self.has_smile = faceFeature.hasSmile;
    self.has_blink = faceFeature.hasBlink;
  }
  return self;
}

- (instancetype)initWithJSONDict:(NSDictionary *)jsonDict
{
  self = [super init];
  if (self) {
    self.bounds = jsonDict[@"bounds"];
    self.has_smile = [jsonDict[@"has_smile"] boolValue];
    self.has_blink = [jsonDict[@"has_blink"] boolValue];
  }
  return self;
}


- (NSDictionary *)dictionary
{
  return [self dictionaryWithValuesForKeys:[DFPeanutFaceFeature attributes]];
}

+ (NSSet *)peanutFaceFeaturesFromDFFaceFeatures:(NSSet *)faceFeatures
{
  NSMutableSet *result = [[NSMutableSet alloc] initWithCapacity:faceFeatures.count];
  for (DFFaceFeature *dfFaceFeature in faceFeatures) {
    DFPeanutFaceFeature *peanutFaceFeature = [[DFPeanutFaceFeature alloc] initWithDFFaceFeature:dfFaceFeature];
    [result addObject:peanutFaceFeature];
  }
  
  return result;
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"DFPeanutFaceFeature: %@", [[self dictionary]
                                                                 JSONStringPrettyPrinted:YES]];
}

- (NSDictionary *)JSONDictionary
{
  return [self dictionary];
}


@end
