//
//  DFHomeSubViewController.h
//  Strand
//
//  Created by Derek Parham on 12/8/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "DFPeanutFeedObject.h"

@interface DFCardViewController : UIViewController

@property (nonatomic, retain) id<NSCopying, NSObject> cardItem;


typedef UInt64 DFHomeSubViewType;
extern DFHomeSubViewType DFSuggestionViewType;
extern DFHomeSubViewType DFIncomingViewType;
extern DFHomeSubViewType DFNuxViewType;

@end
