//
//  MIAppDelegate.m
//  MappedInCocoa
//
//  Created by Dan Lichty on 2013-10-18.
//  Copyright (c) 2013 MappedIn, Inc. All rights reserved.
//

#import "MIAppDelegate.h"

@implementation MIAppDelegate

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions
{
  self.window = [[UIWindow alloc] initWithFrame:[[UIScreen mainScreen] bounds]];
  [self.window makeKeyAndVisible];
  
  UIViewController *vc = [[UIViewController alloc] init];
  [self.window setRootViewController:vc];
  
  return YES;
}

@end
