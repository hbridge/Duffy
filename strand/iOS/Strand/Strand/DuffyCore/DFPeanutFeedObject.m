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
#import "NSDateFormatter+DFPhotoDateFormatters.h"
#import "DFPeanutNotificationsManager.h"
#import "DFPeanutFeedDataManager.h"
#import "DFPeanutContact.h"
#import "EKMappingBlocks+DFMappingBlocks.h"

@implementation DFPeanutFeedObject


DFFeedObjectType DFFeedObjectSection = @"section";
DFFeedObjectType DFFeedObjectPhoto = @"photo";
DFFeedObjectType DFFeedObjectCluster = @"cluster";
DFFeedObjectType DFFeedObjectDocstack = @"docstack";
DFFeedObjectType DFFeedObjectInviteStrand = @"invite_strand";
DFFeedObjectType DFFeedObjectStrand = @"strand";
DFFeedObjectType DFFeedObjectStrandPost = @"strand_post";
DFFeedObjectType DFFeedObjectStrandPosts = @"strand_posts";
DFFeedObjectType DFFeedObjectPeopleList = @"people_list";
DFFeedObjectType DFFeedObjectSuggestedPhotos = @"suggested_photos";
DFFeedObjectType DFFeedObjectStrandJoin = @"strand_join";
DFFeedObjectType DFFeedObjectSwapSuggestion = @"section";
DFFeedObjectType DFFeedObjectActionsList = @"actions_list";

static NSArray *FeedObjectTypes;

+ (void)initialize
{
  FeedObjectTypes = @[DFFeedObjectSection, DFFeedObjectPhoto, DFFeedObjectCluster, DFFeedObjectDocstack, DFFeedObjectInviteStrand, DFFeedObjectStrand, DFFeedObjectActionsList];
}

#pragma mark - Object Mappings

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

+ (RKObjectMapping *)rkObjectMapping
{
  RKObjectMapping *objectMapping = [RKObjectMapping mappingForClass:[self class]];
  [objectMapping addAttributeMappingsFromArray:[self simpleAttributeKeys]];
  [objectMapping addAttributeMappingsFromArray:[self dateAttributeKeys]];
  [objectMapping addRelationshipMappingWithSourceKeyPath:@"objects" mapping:objectMapping];
  [objectMapping addRelationshipMappingWithSourceKeyPath:@"actions" mapping:[DFPeanutAction rkObjectMapping]];
  [objectMapping addRelationshipMappingWithSourceKeyPath:@"people" mapping:[DFPeanutUserObject rkObjectMapping]];
  
  return objectMapping;
}

+ (EKObjectMapping *)objectMapping {
  return [EKObjectMapping mappingForClass:self withBlock:^(EKObjectMapping *mapping) {
    [mapping mapPropertiesFromArray:[self simpleAttributeKeys]];
    
    for (NSString *key in [self dateAttributeKeys]) {
      [mapping mapKeyPath:key toProperty:key
           withValueBlock:[EKMappingBlocks dateMappingBlock]
             reverseBlock:[EKMappingBlocks dateReverseMappingBlock]];
    }
    
    [mapping hasMany:[DFPeanutFeedObject class] forKeyPath:@"objects"];
    [mapping hasMany:[DFPeanutAction class] forKeyPath:@"actions"];
    [mapping hasMany:[DFPeanutUserObject class] forKeyPath:@"people"];
  }];
}

+ (NSArray *)dateAttributeKeys
{
  return @[@"time_stamp",
           @"time_taken",
           @"shared_at_timestamp",
           @"last_action_timestamp",
           @"evaluated_time"];
}

+ (NSArray *)simpleAttributeKeys
{
  return @[@"id",
           @"type",
           @"user",
           @"share_instance",
           @"title",
           @"location",
           @"thumb_image_path",
           @"full_image_path",
           @"ready",
           @"actor_ids",
           @"suggestible",
           @"sort_rank",
           @"suggestion_type",
           @"full_width",
           @"full_height",
           @"strand_id",
           @"evaluated",
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

#pragma mark - Custom Accessors


- (NSArray *)subobjectsOfType:(DFFeedObjectType)type
{
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"type == %@", type];
  return [self.objects filteredArrayUsingPredicate:predicate];
}

- (NSEnumerator *)enumeratorOfDescendents
{
  if (self.objects.count == 0) {
    return [@[] objectEnumerator];
  }
  
  NSMutableArray *allDescendendents = [NSMutableArray new];
  for (DFPeanutFeedObject *object in self.objects) {
    [allDescendendents addObject:object];
    if (object.objects) {
      [allDescendendents addObjectsFromArray:[[object enumeratorOfDescendents] allObjects]];
    }
  }
  
  return [allDescendendents objectEnumerator];
}

- (NSArray *)descendentsOfType:(DFFeedObjectType)type
{
  NSPredicate *predicate = [NSPredicate predicateWithFormat:@"type == %@", type];
  NSArray *allDescendents = self.enumeratorOfDescendents.allObjects;
  return [allDescendents filteredArrayUsingPredicate:predicate];
}

+ (NSArray *)descendentsOfType:(DFFeedObjectType)type inFeedObjects:(NSArray *)feedObjects
{
  NSMutableArray *result = [NSMutableArray new];
  for (DFPeanutFeedObject *feedObject in feedObjects) {
    [result addObjectsFromArray:[feedObject descendentsOfType:type]];
  }
  return result;
}

- (NSArray *)leafNodesFromObjectOfType:(DFFeedObjectType)type
{
  if (self.objects.count == 0 && [self.type isEqualToString:type]) return @[self];
  return [self descendentsOfType:type];
}

- (DFPeanutFeedObject *)firstPhotoWithID:(DFPhotoIDType)photoID;
{
  for (DFPeanutFeedObject *photo in [self leafNodesFromObjectOfType:DFFeedObjectPhoto]) {
    if (photo.id == photoID) return photo;
  }
  return nil;
}

+ (NSArray *)leafObjectsOfType:(DFFeedObjectType)type inArrayOfFeedObjects:(NSArray *)feedObjects
{
  NSMutableArray *result = [NSMutableArray new];
  for (DFPeanutFeedObject *feedObject in feedObjects) {
    [result addObjectsFromArray:[feedObject leafNodesFromObjectOfType:DFFeedObjectPhoto]];
  }
  return result;
}

- (DFPeanutFeedObject *)strandPostsObject
{
  if ([self.type isEqual:DFFeedObjectStrandPosts]) return self;
  else return [[self subobjectsOfType:DFFeedObjectStrandPosts] firstObject];
}

- (NSString *)placeAndRelativeTimeString {
  NSString *timeString = [NSDateFormatter relativeTimeStringSinceDate:self.time_taken
                                                           abbreviate:NO
                                                           inSentence:YES];
  if (self.location) {
    return [NSString stringWithFormat:@"%@ %@", self.location, timeString];
  } else {
    return timeString;
  }
}

- (DFUserIDType)user
{
  if (_user > 0 || self.objects.count == 0) return _user;
  return [(DFPeanutFeedObject *)self.objects.firstObject user];
}

- (DFPhotoIDType)id
{
  if (_id > 0 || self.objects.count == 0) return _id;
  return [(DFPeanutFeedObject *)self.objects.firstObject id];
}

#pragma mark - Action Accessors

- (NSArray *)commentActions
{
  return [self actionsOfType:DFPeanutActionComment
                      forUser:0];
}

- (DFPeanutAction *)userFavoriteAction
{
  return [[self actionsOfType:DFPeanutActionFavorite
                      forUser:[[DFUser currentUser] userID]]
          firstObject];
}

- (DFPeanutAction *)mostRecentAction
{
  DFPeanutAction *latestAction;
  for (DFPeanutAction *action in self.actions) {
    if (!latestAction || [action.time_stamp compare:latestAction.time_stamp] == NSOrderedDescending) {
      latestAction = action;
    }
  }
  return latestAction;
}

- (NSArray *)unreadActionsOfType:(DFPeanutActionType)actionType
{
  NSMutableArray *result = [NSMutableArray new];
  NSArray *unreadNotifs = [[DFPeanutNotificationsManager sharedManager] unreadNotifications];
  for (DFPeanutAction *action in self.actions) {
    if ([unreadNotifs containsObject:action] && action.action_type == actionType)
      [result addObject:action];
  }

  return result;
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

#pragma mark - Actor Accessors

- (NSArray *)actors
{
  NSMutableArray *result = [NSMutableArray new];
  for (NSNumber *userID in self.actor_ids) {
    DFPeanutUserObject *user = [[DFPeanutFeedDataManager sharedManager]
                                userWithID:userID.longLongValue];
    if (user) [result addObject:user];
  }
  return result;
}

- (NSArray *)actorPeanutContacts
{
  return [self.actors arrayByMappingObjectsWithBlock:^id(DFPeanutUserObject *user) {
    DFPeanutContact *contact = [[DFPeanutContact alloc] initWithPeanutUser:user];
    return contact;
  }];
}

- (NSArray *)actorNames
{
  NSMutableOrderedSet *names = [NSMutableOrderedSet new];
  for (DFPeanutUserObject *actor in self.actors) {
    if ([[actor firstName] isNotEmpty]) {
      [names addObject:[actor firstName]];
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

  NSArray *actors = self.actors;
  for (NSUInteger i = 0; i < actors.count; i++) {
    DFPeanutUserObject *actor = actors[i];
    if (actor.invited.boolValue != invited) continue;
    if (![[actor firstName] isNotEmpty]) {
      numUnnamed++;
    } else if (actor.id != [[DFUser currentUser] userID]) {
      if (actorsText.length > 0) [actorsText appendString:@", "];
      [actorsText appendString:[actor firstName]];
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

- (DFPeanutUserObject *)actorWithID:(DFUserIDType)userID
{
  if (userID == [[DFUser currentUser] userID]) {
    return [[DFUser currentUser] peanutUser];
  }  
  
  DFPeanutFeedObject *photoObject = self;
  if ([self.type isEqual:DFFeedObjectCluster]) {
    photoObject = [[self leafNodesFromObjectOfType:DFFeedObjectPhoto] firstObject];
  }
  for (DFPeanutUserObject *user in photoObject.actors) {
    if (user.id == userID) return user;
  }
  
  return nil;
}

#pragma mark - Analytics helpers

- (NSDictionary *)suggestionAnalyticsSummary
{
  return @{
           @"suggestionType" : self.suggestion_type ? self.suggestion_type : @"",
           @"suggestionRank" : self.sort_rank? self.sort_rank : @(0),
           @"suggestionActorsCount" : @(self.actor_ids.count),
           };
}

#pragma mark - NSObject Copying and Equality

/* Creates a shallow copy of the SearchObject */
- (id)copyWithZone:(NSZone *)zone
{
  DFPeanutFeedObject *newObject = [[DFPeanutFeedObject allocWithZone:zone] init];
  newObject.id = self.id;
  newObject.type = self.type;
  newObject.user = self.user;
  newObject.share_instance = [self.share_instance copyWithZone:zone];
  newObject.shared_at_timestamp = [self.shared_at_timestamp copyWithZone:zone];
  newObject.title = [self.title copyWithZone:zone];
  newObject.location = [self.location copyWithZone:zone];
  newObject.thumb_image_path = [self.thumb_image_path copyWithZone:zone];
  newObject.full_image_path = [self.full_image_path copyWithZone:zone];
  newObject.time_taken = [self.time_taken copyWithZone:zone];
  newObject.time_stamp = [self.time_stamp copyWithZone:zone];
  newObject.last_action_timestamp = [self.time_stamp copyWithZone:zone];
  newObject.ready = self.ready;
  newObject.suggestible = self.suggestible;
  newObject.sort_rank = [self.sort_rank copyWithZone:zone];
  newObject.suggestion_type = [self.suggestion_type copyWithZone:zone];
  newObject.full_height = [self.full_height copyWithZone:zone];
  newObject.full_width = [self.full_width copyWithZone:zone];
  newObject.evaluated = [self.evaluated copyWithZone:zone];
  newObject.evaluated_time = [self.evaluated_time copyWithZone:zone];
  
  return newObject;
}

/* Compares equality by looking at the object IDs */
- (BOOL)isEqual:(id)object
{
  DFPeanutFeedObject *otherObject = object;
  if (![[otherObject class] isSubclassOfClass:[self class]]) return NO;
  
  
  if ([self.type isEqual:DFFeedObjectSection] && [otherObject.type isEqual:DFFeedObjectSection]) {
    if ([self.objects count] != [otherObject.objects count]) return NO;
  }
  
  if ([self.type isEqual:DFFeedObjectPhoto] && [otherObject.type isEqual:DFFeedObjectPhoto]) {
    if ([self.actions count] != [otherObject.actions count]
        || !IsEqual(self.actor_ids, otherObject.actor_ids)
        || !IsEqual(self.thumb_image_path, otherObject.thumb_image_path)
        || !IsEqual(self.full_image_path, otherObject.full_image_path)
        || (self.evaluated.boolValue != otherObject.evaluated.boolValue)) return NO;
  }
  
  if ([self.type isEqual:DFFeedObjectActionsList] && [otherObject.type isEqual:DFFeedObjectActionsList]) {
    if (![self.actions isEqualToArray:otherObject.actions]) return NO;
  }
  
  if (otherObject.id == self.id
      && otherObject.share_instance.longLongValue == self.share_instance.longLongValue
      && [otherObject.type isEqual:self.type]) return YES;
  return NO;
}

- (NSNumber *)getUniqueId
{
  if ([self.type isEqualToString:@"photo"]) {
    return self.share_instance;
  } else {
    return @(self.id);
  }
}

- (NSUInteger)hash
{
  return (NSUInteger)self.id;
}


- (NSString *)description
{
  return [[self dictionaryWithValuesForKeys:[self.class simpleAttributeKeys]] description];
}

@end
