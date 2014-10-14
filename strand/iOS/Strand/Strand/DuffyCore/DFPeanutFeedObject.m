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
DFFeedObjectType DFFeedObjectStrandPost = @"strand_post";
DFFeedObjectType DFFeedObjectStrandPosts = @"strand_posts";
DFFeedObjectType DFFeedObjectFriendsList = @"friends_list";
DFFeedObjectType DFFeedObjectSuggestedPhotos = @"suggested_photos";
DFFeedObjectType DFFeedObjectStrandJoin = @"strand_join";

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
           @"location",
           @"thumb_image_path",
           @"full_image_path",
           @"time_taken",
           @"user",
           @"user_display_name",
           @"time_stamp",
           @"ready",
           @"suggestible",
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
    if (action.action_type == type && (action.user == user || user == 0)) {
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
  newObject.user_display_name =[self.user_display_name copy];
  newObject.ready = self.ready;
  newObject.suggestible = self.suggestible;
  
  return newObject;
}

/* Compares equality by looking at the object IDs */
- (BOOL)isEqual:(id)object
{
  DFPeanutFeedObject *otherObject = object;
  if (![[otherObject class] isSubclassOfClass:[self class]]) return NO;
  
  if (otherObject.id == self.id && [otherObject.type isEqual:self.type]) return YES;
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
  NSMutableOrderedSet *names = [NSMutableOrderedSet new];
  for (DFPeanutUserObject *actor in self.actors) {
    if ([actor.display_name isNotEmpty]) {
      [names addObject:actor.display_name];
    }
  }
  return names.array;
}

- (NSString *)actorsString
{
  return [self actorsStringForInvited:NO];
}

- (NSString *)actorsStringForInvited:(BOOL)invited
{
  NSMutableString *actorsText = [NSMutableString new];
  BOOL includeYou = false;
  NSUInteger numOtherMembers = 0;
  NSUInteger numUnnamed = 0;
  
  for (NSUInteger i = 0; i < self.actors.count; i++) {
    DFPeanutUserObject *actor = self.actors[i];
    if (actor.invited.boolValue != invited) continue;
    if (![actor.display_name isNotEmpty]) {
      numUnnamed++;
    } else if (actor.id != [[DFUser currentUser] userID]) {
      if (actorsText.length > 0) [actorsText appendString:@", "];
      [actorsText appendString:[actor display_name]];
      numOtherMembers++;
    } else {
      includeYou = true;
    }
  }
  if (includeYou) {
    if (numOtherMembers > 0) [actorsText appendString:@" and "];
    [actorsText appendString:@"You"];
  }
  if (numUnnamed > 0) {
    [actorsText appendString:[NSString stringWithFormat:@" + %d", (int)numUnnamed]];
  }
  
  return actorsText;
}

- (NSString *)invitedActorsStringCondensed:(BOOL)condensed
{
  if (!condensed) return [self actorsStringForInvited:YES];
  NSUInteger numInvited = 0;
  for (DFPeanutUserObject *actor in self.actors) {
    if (actor.invited.boolValue == YES) numInvited++;
  }
  
  if (numInvited == 0) return nil;
  return [NSString stringWithFormat:@"+%d invited", (int)numInvited];
}

- (NSAttributedString *)peopleSummaryString
{
  NSMutableAttributedString *peopleString = [[NSMutableAttributedString alloc] initWithString:self.actorsString];
  NSString *invitedString = [self invitedActorsStringCondensed:YES];
  if ([invitedString isNotEmpty]) {
    invitedString = [NSString stringWithFormat:@" (%@)", invitedString];
    NSAttributedString *invitedAttributedString = [[NSAttributedString alloc]
                                                   initWithString:invitedString
                                                   attributes:@{
                                                                NSForegroundColorAttributeName : [UIColor lightGrayColor]
                                                                }];
    [peopleString appendAttributedString:invitedAttributedString];
  }
  return peopleString;
}



- (NSArray *)subobjectsOfType:(DFFeedObjectType)type
{
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"type == %@", type];
  return [self.objects filteredArrayUsingPredicate:predicate];
}

@end
