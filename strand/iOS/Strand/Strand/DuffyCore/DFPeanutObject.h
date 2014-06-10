//
//  DFPeanutObject.h
//  Duffy
//
//  Created by Henry Bridge on 6/2/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@class RKObjectMapping;

@protocol DFPeanutObject <NSObject>

+ (RKObjectMapping *)objectMapping;

@end
