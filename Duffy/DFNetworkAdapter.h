//
//  DFNetworkAdapter.h
//  Duffy
//
//  Created by Henry Bridge on 4/30/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@protocol DFNetworkAdapter <NSObject>

+ (NSArray *)requestDescriptors;
+ (NSArray *)responseDescriptors;

@end
