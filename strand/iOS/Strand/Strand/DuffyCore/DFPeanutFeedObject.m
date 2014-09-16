//
//  DFPeanutSearchObject.m
//  Duffy
//
//  Created by Henry Bridge on 6/2/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFPeanutFeedObject.h"
#import <Restkit/RestKit.h>
#import "DFPeanutUserObject.h"
#import "NSString+DFHelpers.h"

@implementation DFPeanutFeedObject

DFFeedObjectType DFFeedObjectSection = @"section";
DFFeedObjectType DFFeedObjectPhoto = @"photo";
DFFeedObjectType DFFeedObjectCluster = @"cluster";
DFFeedObjectType DFFeedObjectDocstack = @"docstack";
DFFeedObjectType DFFeedObjectInviteStrand = @"invite_strand";
DFFeedObjectType DFFeedObjectStrand = @"strand";
DFFeedObjectType DFFeedObjectLikeAction = @"like_action";

static NSArray *FeedObjectTypes;

+ (void)initialize
{
  FeedObjectTypes = @[DFFeedObjectSection, DFFeedObjectPhoto, DFFeedObjectCluster, DFFeedObjectDocstack, DFFeedObjectInviteStrand, DFFeedObjectStrand];
}

- (id)initWithJSONDict:(NSDictionary *)jsonDict
{
  self = [super init];
  if (self) {
    [self setValuesForKeysWithDictionary:jsonDict];
    
    NSMutableArray *convertedObjects = [[NSMutableArray alloc] init];
    for (NSDictionary *subJSONDict in _objects) {
      DFPeanutFeedObject *convertedObject = [[DFPeanutFeedObject alloc] initWithJSONDict:subJSONDict];
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
  [objectMapping addRelationshipMappingWithSourceKeyPath:@"actors" mapping:[DFPeanutUserObject objectMapping]];
  
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
           @"time_stamp",
           ];
}

- (NSDictionary *)JSONDictionary
{
  NSMutableDictionary *resultDict = [[self dictionaryWithValuesForKeys:[DFPeanutFeedObject
                                                                simpleAttributeKeys]] mutableCopy];
  if (self.objects.count > 0) {
    NSMutableArray *objectsJSONDicts = [[NSMutableArray alloc] initWithCapacity:self.objects.count];
    for (DFPeanutFeedObject *object in self.objects) {
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

- (NSArray *)actionsOfType:(DFPeanutActionType)type forUser:(DFUserIDType)user
{
  NSMutableArray *result = [[NSMutableArray alloc] init];
  for (DFPeanutAction *action in self.actions) {
    if ([action.action_type isEqual:type] && (action.user == user || user == 0)) {
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
  for (DFPeanutFeedObject *object in self.objects) {
    if (object.objects) {
      [allDescendendents addObjectsFromArray:[[object enumeratorOfDescendents] allObjects]];
    } else {
      [allDescendendents addObject:object];
    }
  }
  
  return [allDescendendents objectEnumerator];
}

- (BOOL)isLockedSection
{
  return ([self.type isEqual:DFFeedObjectSection] && [self.title isEqual:@"Locked"]);
}

/* Creates a shallow copy of the SearchObject */
- (id)copyWithZone:(NSZone *)zone
{
  DFPeanutFeedObject *newObject = [[DFPeanutFeedObject allocWithZone:zone] init];
  newObject.id = self.id;
  newObject.title = [self.title copyWithZone:zone];
  newObject.subtitle = [self.title copyWithZone:zone];
  newObject.thumb_image_path = [self.thumb_image_path copyWithZone:zone];
  newObject.full_image_path = [self.full_image_path copyWithZone:zone];
  newObject.time_taken = [self.time_taken copyWithZone:zone];
  newObject.user = self.user;
  newObject.user_display_name = [self.user_display_name copy];
  
  return newObject;
}

/* Compares equality by looking at the object IDs */
- (BOOL)isEqual:(id)object
{
  DFPeanutFeedObject *otherObject = object;
  if (otherObject.id == self.id) return YES;
  return NO;
}

- (NSArray *)actorAbbreviations
{
  NSMutableArray *abbreviations = [NSMutableArray new];
  for (DFPeanutUserObject *actor in self.actors) {
    if ([actor.display_name isNotEmpty]) {
      NSString *abbreviation = [[actor.display_name substringToIndex:1] uppercaseString];
      if ([abbreviations indexOfObject:abbreviation] == NSNotFound) {
        [abbreviations addObject:abbreviation];
      }
    }
  }
  return abbreviations;
}

- (NSArray *)actorNames
{
  NSMutableArray *names = [NSMutableArray new];
  for (DFPeanutUserObject *actor in self.actors) {
    if ([actor.display_name isNotEmpty]) {
      if ([names indexOfObject:actor.display_name] == NSNotFound) {
        [names addObject:actor.display_name];
      }
    }
  }
  return names;
}


@end
