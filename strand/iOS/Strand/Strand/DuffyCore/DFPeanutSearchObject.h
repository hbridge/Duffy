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

@interface DFPeanutSearchObject : NSObject<DFPeanutObject, DFJSONConvertible>

typedef NSString *const DFSearchObjectType;

extern DFSearchObjectType DFSearchObjectSection;
extern DFSearchObjectType DFSearchObjectPhoto;
extern DFSearchObjectType DFSearchObjectCluster;
extern DFSearchObjectType DFSearchObjectDocstack;

// Simple attribures
@property (nonatomic) DFPhotoIDType id;
@property (nonatomic, retain) DFSearchObjectType type;
@property (nonatomic, retain) NSString *title;
@property (nonatomic, retain) NSString *subtitle;
@property (nonatomic, retain) NSString *thumb_image_path;
@property (nonatomic, retain) NSString *full_image_path;
@property (nonatomic, retain) NSDate *time_taken;
@property (nonatomic) DFUserIDType user;
@property (nonatomic, retain) NSString *user_display_name;

// Relationships
@property (nonatomic, retain) NSArray *objects;
@property (nonatomic, retain) NSArray *actions;

- (DFPeanutAction *)userFavoriteAction;
- (void)setUserFavoriteAction:(DFPeanutAction *)favoriteAction;
- (NSArray *)actionsOfType:(DFActionType)type forUser:(DFUserIDType)user;
- (NSEnumerator *)enumeratorOfDescendents;

- (BOOL)isLockedSection;


@end
