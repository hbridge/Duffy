//
//  DFHomeSubViewController.h
//  Strand
//
//  Created by Derek Parham on 12/8/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFHomeSubViewController : UIViewController

@property (nonatomic) NSUInteger index;

typedef UInt64 DFHomeSubViewType;
extern DFHomeSubViewType DFSuggestionViewType;
extern DFHomeSubViewType DFIncomingViewType;

@end
