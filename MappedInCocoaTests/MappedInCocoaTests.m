//
//  MappedInCocoaTests.m
//  MappedInCocoaTests
//
//  Created by Dan Lichty on 2013-10-18.
//  Copyright (c) 2013 MappedIn, Inc. All rights reserved.
//

#import <XCTest/XCTest.h>
#import <Block-KVO/MTKObserving.h>

#import "MIAPI.h"

#define kAPIVersion @"0"
#define kAPIClientKey nil
#define kAPISecretKey nil

@interface MappedInCocoaTests : XCTestCase

@property (nonatomic, strong) MIAPI *api;

@end

@implementation MappedInCocoaTests

- (void)setUp
{
  [super setUp];
 
  [MIAPI clearCachedAccessTokenAndManifest];
  self.api = [[MIAPI alloc] initWithVersion:kAPIVersion clientKey:kAPIClientKey secretKey:kAPISecretKey];
}

- (void)tearDown
{
  [super tearDown];
}

- (void)testReadyStates
{
  XCTAssertFalse(self.api.ready, @"should not be ready immediately after initialization");
  
  __block BOOL hasCalledBack = NO;
  __block BOOL hasChangedReadyProperty = NO;
  
  [self.api observeProperty:@"ready"
                  withBlock:^(__weak id self, id old, id new) {
                    if (old != nil)
                      hasChangedReadyProperty = YES;
                  }];
  
  [self.api connectWithCallback:^{
    hasCalledBack = YES;
    XCTAssertTrue(self.api.ready, @"should be ready after connecting");
  } failure:^(NSError *error) {
    hasCalledBack = YES;
    XCTAssertFalse(self.api.ready, @"should not be ready if connection fails");
  }];
  
  XCTAssertFalse(self.api.ready, @"should not be ready immediately after beginning connection");
  
  NSDate *loopUntil = [NSDate dateWithTimeIntervalSinceNow:10];
  while (!(hasCalledBack && (!self.api.ready || hasChangedReadyProperty)) && [loopUntil timeIntervalSinceNow] > 0)
  {
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:loopUntil];
  }
  
  XCTAssertTrue(hasCalledBack, @"should have called back after connection attempt");
  XCTAssertTrue(!self.api.ready || hasChangedReadyProperty, @"should have changed ready property");
  
  [self.api removeAllObservations];
}

- (void)testSimpleCall
{
  NSString *method = @"getAllVenues";
  
  __block BOOL hasCalledBack = NO;
  
  [self.api connectWithCallback:^{
    [self.api fetchMethod:method
                     args:@{ @"deviceId": @"MappedInCocoaTestsID" }
                  success:^(id result) {
                    hasCalledBack = YES;
                  }
                  failure:^(NSError *error) {
                    hasCalledBack = YES;
                  }];
  } failure:^(NSError *error) {
    XCTFail(@"should not fail connecting");
  }];
  
  NSDate *loopUntil = [NSDate dateWithTimeIntervalSinceNow:10];
  while (!hasCalledBack && [loopUntil timeIntervalSinceNow] > 0)
  {
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:loopUntil];
  }
  
  XCTAssertTrue(hasCalledBack, @"should have called back after %@ call", method);
}

- (void)testCaching
{
  __block BOOL hasCalledBack = NO;
  
  [self.api connectWithCallback:^{
    MIAPI *secondApi = [[MIAPI alloc] initWithVersion:kAPIVersion clientKey:kAPIClientKey secretKey:kAPISecretKey];
    [secondApi connectWithCallback:nil failure:nil];
    XCTAssertTrue(secondApi.ready, @"second API should be immediately ready due to cached values");
    
    hasCalledBack = YES;
  } failure:^(NSError *error) {
    XCTFail(@"should not fail connecting");
  }];
  
  XCTAssertFalse(self.api.ready, @"first API should not be ready immediately after beginning connection");
  
  NSDate *loopUntil = [NSDate dateWithTimeIntervalSinceNow:10];
  while (!hasCalledBack && [loopUntil timeIntervalSinceNow] > 0)
  {
    [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode beforeDate:loopUntil];
  }
  
  XCTAssertTrue(hasCalledBack, @"should have called back after connecting");
}

@end
