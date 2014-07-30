//
//  DFPeanutSearchObject.m
//  Duffy
//
//  Created by Henry Bridge on 6/2/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPeanutSearchObject.h"
#import <Restkit/RestKit.h>

@implementation DFPeanutSearchObject

DFSearchObjectType DFSearchObjectSection = @"section";
DFSearchObjectType DFSearchObjectPhoto = @"photo";
DFSearchObjectType DFSearchObjectCluster = @"cluster";
DFSearchObjectType DFSearchObjectDocstack = @"docstack";



- (id)initWithJSONDict:(NSDictionary *)jsonDict
{
  self = [super init];
  if (self) {
    [self setValuesForKeysWithDictionary:jsonDict];
    
    NSMutableArray *convertedObjects = [[NSMutableArray alloc] init];
    for (NSDictionary *subJSONDict in _objects) {
      DFPeanutSearchObject *convertedObject = [[DFPeanutSearchObject alloc] initWithJSONDict:subJSONDict];
      [convertedObjects addObject:convertedObject];
    }
    _objects = convertedObjects;
    
  }
  return self;
}

+ (RKObjectMapping *)objectMapping
{
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[self class]];
  [objectMapping addAttributeMappingsFromArray:[self simpleAttributeKeys]];
  [objectMapping addRelationshipMappingWithSourceKeyPath:@"objects" mapping:objectMapping];
  [objectMapping addRelationshipMappingWithSourceKeyPath:@"actions" mapping:[DFPeanutAction objectMapping]];
  
  
  return objectMapping;
}

+ (NSArray *)simpleAttributeKeys
{
  return @[@"id",
           @"type",
           @"title",
           @"subtitle",
           @"thumb_image_path",
           @"full_image_path",
           @"time_taken",
           @"user",
           @"user_display_name",
           ];
}

- (NSDictionary *)JSONDictionary
{
  NSMutableDictionary *resultDict = [[self dictionaryWithValuesForKeys:[DFPeanutSearchObject
                                                                simpleAttributeKeys]] mutableCopy];
  if (self.objects.count > 0) {
    NSMutableArray *objectsJSONDicts = [[NSMutableArray alloc] initWithCapacity:self.objects.count];
    for (DFPeanutSearchObject *object in self.objects) {
      [objectsJSONDicts addObject:object.JSONDictionary];
    }
    
    resultDict[@"objects"] = objectsJSONDicts;
  }
  
  if (self.actions.count > 0) {
    NSMutableArray *actionsJSONDicts = [[NSMutableArray alloc] initWithCapacity:self.actions.count];
    for (DFPeanutAction *action in self.actions) {
      NSDictionary *actionDict = [action dictionaryWithValuesForKeys:[DFPeanutAction simpleAttributeKeys]];
      [actionsJSONDicts addObject:actionDict];
    }
    resultDict[@"actions"] = actionsJSONDicts;
  }
  
  return resultDict;
}

- (DFPeanutAction *)userFavoriteAction
{
  return [[self actionsOfType:DFPeanutActionFavorite
                      forUser:[[DFUser currentUser] userID]]
          firstObject];
}

- (void)setUserFavoriteAction:(DFPeanutAction *)favoriteAction
{
  NSMutableArray *mutableActions = [[NSMutableArray alloc] initWithArray:self.actions];
  DFPeanutAction *oldFavoriteAction = [self userFavoriteAction];
  [mutableActions removeObject:oldFavoriteAction];
  if (favoriteAction) {
    [mutableActions addObject:favoriteAction];
  }
  
  self.actions = mutableActions;
}

- (NSArray *)actionsOfType:(DFActionType)type forUser:(DFUserIDType)user
{
  NSMutableArray *result = [[NSMutableArray alloc] init];
  for (DFPeanutAction *action in self.actions) {
    if ([action.action_type isEqual:type] && action.user == user) {
      [result addObject:action];
    }
  }
  
  return result;
}

- (NSString *)description
{
  return [[self dictionaryWithValuesForKeys:[self.class simpleAttributeKeys]] description];
}

- (NSEnumerator *)enumeratorOfDescendents
{
  if (self.objects.count == 0) {
    return [@[] objectEnumerator];
  }
  
  NSMutableArray *allDescendendents = [NSMutableArray new];
  for (DFPeanutSearchObject *object in self.objects) {
    if (object.objects) {
      [allDescendendents addObjectsFromArray:[[object enumeratorOfDescendents] allObjects]];
    } else {
      [allDescendendents addObject:object];
    }
  }
  
  return [allDescendendents objectEnumerator];
}


@end
