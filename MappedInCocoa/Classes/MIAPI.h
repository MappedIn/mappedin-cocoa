//
//  MIAPI.h
//  MappedInCocoa
//
//  Created by Dan Lichty on 2013-10-21.
//  Copyright (c) 2013 MappedIn, Inc. All rights reserved.
//

#import <Foundation/Foundation.h>

@class AFHTTPRequestOperationManager;

typedef void (^MIAPIFailureCallback)(NSError *error);
typedef void (^MIAPISuccessCallback)(id result);

typedef NS_ENUM(NSInteger, MIAPIErrorCode)
{
  MIAPIErrorAlreadyInitializing,
  MIAPIErrorMalformedResponse,
  MIAPIErrorManifest,
  MIAPIErrorMethodName,
  MIAPIErrorInternal
};

@interface MIAPI : NSObject

- (id)initWithVersion:(NSString *)version;
- (void)connectWithCallback:(void (^)(void))success failure:(MIAPIFailureCallback)failure;
- (NSString *)fetchMethod:(NSString *)name args:(NSDictionary *)args success:(MIAPISuccessCallback)success failure:(MIAPIFailureCallback)failure;
- (void)cancelRequest:(NSString *)requestID;

@property (nonatomic) BOOL loggingEnabled;
@property (nonatomic, readonly) BOOL ready;

@end
