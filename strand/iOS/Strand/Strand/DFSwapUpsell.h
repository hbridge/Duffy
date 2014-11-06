//
//  DFSwapUpsell.h
//  Strand
//
//  Created by Henry Bridge on 11/4/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFSwapUpsell : NSObject

typedef NSString *const DFSwapUpsellType;
extern DFSwapUpsellType DFSwapUpsellInviteFriends;
extern DFSwapUpsellType DFSwapUpsellLocation;

@property (nonatomic, retain) DFSwapUpsellType type;
@property (readonly, nonatomic, retain) NSString *title;
@property (readonly, nonatomic, retain) NSString *subtitle;
@property (readonly, nonatomic, retain) UIImage *image;


@end
