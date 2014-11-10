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

@interface DFPeanutFeedObject : NSObject<DFPeanutObject, DFJSONConvertible, NSCopying>

typedef NSString *const DFFeedObjectType;

extern DFFeedObjectType DFFeedObjectSection;
extern DFFeedObjectType DFFeedObjectPhoto;
extern DFFeedObjectType DFFeedObjectCluster;
extern DFFeedObjectType DFFeedObjectDocstack;
extern DFFeedObjectType DFFeedObjectInviteStrand;
extern DFFeedObjectType DFFeedObjectStrand;
extern DFFeedObjectType DFFeedObjectLikeAction;
extern DFFeedObjectType DFFeedObjectStrandPost;
extern DFFeedObjectType DFFeedObjectStrandPosts;
extern DFFeedObjectType DFFeedObjectFriendsList;
extern DFFeedObjectType DFFeedObjectSuggestedPhotos;
extern DFFeedObjectType DFFeedObjectStrandJoin;
extern DFFeedObjectType DFFeedObjectSwapSuggestion;

// Simple attribures
@property (nonatomic) DFPhotoIDType id;
@property (nonatomic, retain) DFFeedObjectType type;
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *subtitle;
@property (nonatomic, retain) NSString *location;
@property (nonatomic, retain) NSString *thumb_image_path;
@property (nonatomic, retain) NSString *full_image_path;
@property (nonatomic, retain) NSDate *time_taken;
@property (nonatomic) DFUserIDType user;
@property (nonatomic, retain) NSString *user_display_name;
@property (nonatomic, retain) NSDate *time_stamp;
@property (nonatomic, retain) NSNumber *ready;
@property (nonatomic, retain) NSNumber *suggestible;
@property (nonatomic, retain) NSNumber *suggestion_rank;
@property (nonatomic, retain) NSString *suggestion_type;
@property (nonatomic, retain) NSNumber *full_width;
@property (nonatomic, retain) NSNumber *full_height;


// Relationships
@property (nonatomic, retain) NSArray *objects;
@property (nonatomic, retain) NSArray *actions;
@property (nonatomic, retain) NSArray *actors;

- (DFPeanutAction *)userFavoriteAction;
- (void)setUserFavoriteAction:(DFPeanutAction *)favoriteAction;

- (NSArray *)commentActions;

- (NSArray *)actionsOfType:(DFPeanutActionType)type forUser:(DFUserIDType)user;
- (NSEnumerator *)enumeratorOfDescendents;

- (BOOL)isLockedSection;
- (NSArray *)actorAbbreviations;
- (NSArray *)actorNames;

/* 
- (NSString *)actorsString; 
 Comma separated list of actors, with the current actor replaced with "You" i.e.
 Aseem, Derek and You 
 */
- (NSString *)actorsString;
- (NSString *)invitedActorsStringCondensed:(BOOL)condensed;
- (NSAttributedString *)peopleSummaryString;

- (NSArray *)subobjectsOfType:(DFFeedObjectType)type;
- (NSArray *)descendentdsOfType:(DFFeedObjectType)type;
- (NSArray *)leafNodesFromObjectOfType:(DFFeedObjectType)type;
- (DFPeanutFeedObject *)strandPostsObject;

/* Time in Location e.g.: "1 week ago in Wiliamsburg" */
- (NSString *)placeAndRelativeTimeString;


@end
