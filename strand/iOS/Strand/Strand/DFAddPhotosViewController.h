//
//  DFAddPhotosViewController.h
//  Strand
//
//  Created by Henry Bridge on 10/14/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSelectSuggestionsViewController.h"

@interface DFAddPhotosViewController : DFSelectSuggestionsViewController

@property (nonatomic, retain) DFPeanutFeedObject *inviteObject;

- (instancetype)initWithSuggestions:(NSArray *)suggestedSections invite:(DFPeanutFeedObject *)invite;

@end
