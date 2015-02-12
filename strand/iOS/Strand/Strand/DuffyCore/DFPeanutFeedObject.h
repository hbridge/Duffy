//
//  DFPeanutSearchObject.h
//  Duffy
//
//  Created by Henry Bridge on 6/2/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "DFPeanutObject.h"
#import "DFJSONConvertible.h"
#import "DFPhoto.h"
#import "DFPeanutAction.h"
#import "DFPeanutUserObject.h"
#import <EKObjectMapping.h>
#import <EKMappingProtocol.h>

@interface DFPeanutFeedObject : NSObject<DFPeanutObject, DFJSONConvertible, NSCopying, EKMappingProtocol>

typedef NSString *const DFFeedObjectType;

extern DFFeedObjectType DFFeedObjectSection;
extern DFFeedObjectType DFFeedObjectPhoto;
extern DFFeedObjectType DFFeedObjectPeopleList;
extern DFFeedObjectType DFFeedObjectSuggestedPhotos;
extern DFFeedObjectType DFFeedObjectSwapSuggestion;
extern DFFeedObjectType DFFeedObjectCluster;
extern DFFeedObjectType DFFeedObjectActionsList;


// Simple attribures
@property (nonatomic) DFPhotoIDType id;
@property (nonatomic, retain) DFFeedObjectType type;
@property (nonatomic) DFUserIDType user;
@property (nonatomic, retain) NSNumber *share_instance;
@property (nonatomic, retain) NSDate *shared_at_timestamp;
@property (nonatomic, retain) NSString *title;
//@property (nonatomic, retain) NSString *subtitle;
@property (nonatomic, retain) NSString *location;
@property (nonatomic, retain) NSString *thumb_image_path;
@property (nonatomic, retain) NSString *full_image_path;
@property (nonatomic, retain) NSDate *time_taken;
//@property (nonatomic, retain) NSString *user_display_name;
@property (nonatomic, retain) NSDate *time_stamp;
@property (nonatomic, retain) NSDate *last_action_timestamp;
@property (nonatomic, retain) NSNumber *ready;
@property (readonly, nonatomic, retain) NSArray *actor_ids;
@property (nonatomic, retain) NSNumber *suggestible;
@property (nonatomic, retain) NSNumber *sort_rank;
@property (nonatomic, retain) NSString *suggestion_type;
@property (nonatomic, retain) NSNumber *full_width;
@property (nonatomic, retain) NSNumber *full_height;
@property (nonatomic, retain) NSNumber *strand_id;
@property (nonatomic, retain) NSNumber *evaluated;
@property (nonatomic, retain) NSDate *evaluated_time;

// Relationships
@property (nonatomic, retain) NSArray *objects;
@property (nonatomic, retain) NSArray *actions;
// used only in the people_list object type
@property (nonatomic, retain) NSArray *people;

// converted from actorIDs
@property (readonly, nonatomic, retain) NSArray *actors;

- (NSNumber *)getUniqueId;

- (DFPeanutAction *)userFavoriteAction;
- (void)setUserFavoriteAction:(DFPeanutAction *)favoriteAction;
- (DFPeanutAction *)mostRecentAction;
- (NSArray *)unreadActionsOfType:(DFPeanutActionType)actionType;

- (NSArray *)commentActions;

- (NSArray *)actionsOfType:(DFPeanutActionType)type forUser:(DFUserIDType)user;
- (NSEnumerator *)enumeratorOfDescendents;

- (NSArray *)actorNames;
- (NSArray *)actorPeanutContacts;

/* 
- (NSString *)actorsString; 
 Comma separated list of actors, with the current actor replaced with "You" i.e.
 Aseem, Derek and You 
 */
- (NSString *)actorsString;
- (NSString *)invitedActorsStringCondensed:(BOOL)condensed;
- (NSAttributedString *)peopleSummaryString;

- (NSArray *)subobjectsOfType:(DFFeedObjectType)type;
- (NSArray *)descendentsOfType:(DFFeedObjectType)type;
+ (NSArray *)descendentsOfType:(DFFeedObjectType)type inFeedObjects:(NSArray *)feedObjects;
- (NSArray *)leafNodesFromObjectOfType:(DFFeedObjectType)type;
- (DFPeanutFeedObject *)firstPhotoWithID:(DFPhotoIDType)photoID;
- (DFPeanutFeedObject *)strandPostsObject;

/* Time in Location e.g.: "1 week ago in Wiliamsburg" */
- (NSString *)placeAndRelativeTimeString;

+ (NSArray *)leafObjectsOfType:(DFFeedObjectType)type inArrayOfFeedObjects:(NSArray *)feedObjects;
- (DFPeanutUserObject *)actorWithID:(DFUserIDType)userID;

+ (EKObjectMapping *)objectMapping;

#pragma mark - Analytics helpers
- (NSDictionary *)suggestionAnalyticsSummary;

/* finds a feed object based on immutable properties like id and share_instance */
+ (NSUInteger)indexOfFeedObject:(DFPeanutFeedObject *)feedObject inArray:(NSArray *)array;

@end
