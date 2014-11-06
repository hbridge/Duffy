//
//  DFSwapUpsell.m
//  Strand
//
//  Created by Henry Bridge on 11/4/14.
//  Copyright (c) 2014 Duffy Inc. All rights reserved.
//

#import "DFSwapUpsell.h"

@interface DFSwapUpsell()

@property (readonly, nonatomic, retain) NSDictionary *attrs;

@end

@implementation DFSwapUpsell

DFSwapUpsellType DFSwapUpsellInviteFriends = @"DFSwapUpsellInviteFriends";
DFSwapUpsellType DFSwapUpsellLocation = @"DFSwapUpsellLocation";


static NSDictionary *upsellAttrs;
+ (void)initialize {
  upsellAttrs = @{
                    DFSwapUpsellInviteFriends : @ {
                      @"title" : @"Invite Friends",
                      @"subtitle" : @"More friends = more suggestions",
                      @"imagePath" : @"Assets/Icons/FriendsUpsellIcon",
                    },
                    DFSwapUpsellLocation : @ {
                      @"title" : @"Grant Location Access",
                      @"subtitle" : @"Get suggestions without taking a photo",
                      @"imagePath" : @"Assets/Icons/LocationUpsellIcon",
                    }
                    };
}

- (NSDictionary *)attrs
{
  return upsellAttrs[self.type];
}

- (NSString *)title
{
  
  return self.attrs[@"title"];
}

- (NSString *)subtitle
{
  return self.attrs[@"subtitle"];
}

- (UIImage *)image
{
  return [UIImage imageNamed:self.attrs[@"imagePath"]];
}

@end
