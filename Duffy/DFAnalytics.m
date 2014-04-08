//
//  DFAnalytics.m
//  Duffy
//
//  Created by Henry Bridge on 4/8/14.
//  Copyright (c) 2014 Duffy Productions. All rights reserved.
//

#import "DFAnalytics.h"
#import "Flurry/Flurry.h"

@implementation DFAnalytics

static NSString *ControllerViewedEvent = @"ControllerViewed";

static NSString *ControllerClassKey = @"controllerClass";


+ (void)logViewController:(UIViewController *)viewController appearedWithParameters:(NSDictionary *)params
{
    NSMutableDictionary *allParams = [[NSMutableDictionary alloc] initWithDictionary:params];
    allParams[ControllerClassKey] = [viewController.class description];
    [Flurry logEvent:ControllerViewedEvent withParameters:allParams timed:YES];
}

+ (void)logViewController:(UIViewController *)viewController disappearedWithParameters:(NSDictionary *)params
{
    [Flurry endTimedEvent:ControllerViewedEvent withParameters:params];
}



@end
