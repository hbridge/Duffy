//
//  DFAnalytics.h
//  Duffy
//
//  Created by Henry Bridge on 4/8/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface DFAnalytics : NSObject

+ (void)logViewController:(UIViewController *)viewController appearedWithParameters:(NSDictionary *)params;
+ (void)logViewController:(UIViewController *)viewController disappearedWithParameters:(NSDictionary *)params;

@end
