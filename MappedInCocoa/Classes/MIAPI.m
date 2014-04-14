//
//  MIAPI.m
//  MappedInCocoa
//
//  Created by Dan Lichty on 2013-10-21.
//  Copyright (c) 2013 MappedIn, Inc. All rights reserved.
//

#import "MIAPI.h"
#import "MIMethod.h"
#import <AFHTTPRequestOperationManager.h>

@interface MIAPI ()
{
  AFHTTPRequestOperationManager *_requestManager;
  NSMutableDictionary *_methodManifest;
  NSMutableDictionary *_requestOperations;
  BOOL _initializing, _ready;
}

@property (nonatomic, strong) NSString *host, *index, *port, *version, *identifier;

@end

@implementation MIAPI

- (id)initWithVersion:(NSString *)version
{
  self = [super init];
  
  _requestManager = [AFHTTPRequestOperationManager manager];
  _methodManifest = [NSMutableDictionary dictionary];
  _requestOperations = [NSMutableDictionary dictionary];
  
  self.host = @"https://api.mappedin.com";
  self.index = @"/manifest";
  self.port = @"443";
  self.version = version;
  self.identifier = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
  
  return self;
}

- (NSString *)errorDomain
{
  static NSString *domain = @"MIAPIErrorDomain";
  return domain;
}

- (NSError *)errorForCode:(MIAPIErrorCode)code
{
  return [self errorForCode:code userInfo:nil];
}

- (NSError *)errorForCode:(MIAPIErrorCode)code userInfo:(NSDictionary *)info
{
  NSString *description = @"Unknown error.";
  
  if (code == MIAPIErrorAlreadyInitializing)
  {
    description = @"API is already initializing.";
  }
  else if (code == MIAPIErrorMalformedResponse)
  {
    description = @"API returned malformed response.";
  }
  else if (code == MIAPIErrorManifest)
  {
    description = @"API manifest could not be retrieved.";
  }
  else if (code == MIAPIErrorMethodName)
  {
    description = @"API does not include specified method.";
  }
  
  NSMutableDictionary *userInfo = info ? [NSMutableDictionary dictionaryWithDictionary:info] : [NSMutableDictionary dictionary];
  
  if (!userInfo[NSLocalizedDescriptionKey])
    [userInfo setObject:NSLocalizedString(description, nil) forKey:NSLocalizedDescriptionKey];
  
  return [NSError errorWithDomain:[self errorDomain] code:code userInfo:userInfo];
}

- (BOOL)parseManifest:(NSArray *)manifest
{
  if (!manifest)
  {
    return NO;
  }
  
  for (NSDictionary *methodInfo in manifest)
  {
    MIMethod *method = [[MIMethod alloc] initWithName:methodInfo[@"name"]
                                                 path:methodInfo[@"url"]
                                               method:methodInfo[@"method"]
                                            arguments:methodInfo[@"args"]];
    _methodManifest[method.name] = method;
  }
  
  return YES;
}

- (void)connectWithCallback:(void (^)(void))success failure:(MIAPIFailureCallback)failure
{
  if (_ready)
  {
    if (success)
      success();
    return;
  }
  
  if (_initializing)
  {
    if (failure)
      failure([self errorForCode:MIAPIErrorAlreadyInitializing]);
    return;
  }
  
  _initializing = YES;
  
  [self fetchPath:self.index
        arguments:nil
           method:@"GET"
          success:^(NSDictionary *data) {
            if ([data[@"success"] boolValue])
            {
              if ([self parseManifest:data[@"result"]])
              {
                _ready = YES;
                if (success)
                  success();
              }
              else
              {
                if (failure)
                  failure([self errorForCode:MIAPIErrorMalformedResponse]);
              }
            }
            else
            {
              if (failure)
                failure([self errorForCode:MIAPIErrorManifest]);
            }
          }
          failure:failure];
}

- (NSString *)fetchPath:(NSString *)path
              arguments:(NSDictionary *)args
                 method:(NSString *)method
                success:(MIAPISuccessCallback)success
                failure:(MIAPIFailureCallback)failure
{
  NSDate *timingDate = [NSDate date];
  
  if (self.version.length)
  {
    path = [NSString stringWithFormat:@"/%@%@", self.version, path];
  }
  
  NSString *uuid = [[NSUUID UUID] UUIDString];
  NSString *url = [NSString stringWithFormat:@"%@:%@%@", self.host, self.port, path];
  
  void(^logTime)(AFHTTPRequestOperation *) = ^(AFHTTPRequestOperation *operation)
  {
    if (!self.loggingEnabled)
      return;
    
    NSLog(@"%@ (%ld): %dms", url, (long)operation.response.statusCode, (int)(1000 * [[NSDate date] timeIntervalSinceDate:timingDate]));
  };
  
  void(^removeRequest)() = ^
  {
    [_requestOperations removeObjectForKey:uuid];
  };
  
  void (^requestSuccess)(AFHTTPRequestOperation *, id) = ^(AFHTTPRequestOperation *operation, id responseObject)
  {
    logTime(operation);
    removeRequest();
    if ([responseObject isKindOfClass:[NSDictionary class]])
    {
      if (success)
        success(responseObject);
    }
    else
    {
      if (failure)
        failure([self errorForCode:MIAPIErrorMalformedResponse]);
    }
  };
  
  void (^requestFailure)(AFHTTPRequestOperation *, NSError *) = ^(AFHTTPRequestOperation *operation, NSError *error)
  {
    logTime(operation);
    removeRequest();
    failure(error);
  };
  
  AFHTTPRequestOperation *request;
  
  if ([method isEqualToString:@"GET"])
  {
    request = [_requestManager GET:url parameters:args success:requestSuccess failure:requestFailure];
  }
  else if ([method isEqualToString:@"POST"])
  {
    request = [_requestManager POST:url parameters:args success:requestSuccess failure:requestFailure];
  }
  
  if (!request)
  {
    return nil;
  }
  
  _requestOperations[uuid] = request;
  return uuid;
}

- (NSString *)fetchMethod:(NSString *)name
                     args:(NSDictionary *)args
                  success:(MIAPISuccessCallback)success
                  failure:(MIAPIFailureCallback)failure
{
  MIMethod *method = _methodManifest[name];
  if (!method)
  {
    failure([self errorForCode:MIAPIErrorMethodName userInfo:@{@"MIAPIErrorName": name}]);
    return nil;
  }
  
  MIAPISuccessCallback fetchSuccess = ^(id data)
  {
    if (![data[@"success"] boolValue])
    {
      if (failure)
      {
        NSString *errorMessage;
        if (!(errorMessage = data[@"message"]))
        {
          errorMessage = @"Something went wrong.";
        }
        failure([NSError errorWithDomain:[self errorDomain] code:MIAPIErrorInternal userInfo:@{NSLocalizedDescriptionKey: errorMessage}]);
      }
    }
    else if (!data[@"result"])
    {
      if (failure)
        failure([self errorForCode:MIAPIErrorMalformedResponse]);
    }
    else
    {
      if (success)
        success(data[@"result"]);
    }
  };
  
  return [self fetchPath:method.path arguments:[method requestArgumentsForData:args] method:method.method success:fetchSuccess failure:failure];
}

- (void)cancelRequest:(NSString *)requestID
{
  if (!requestID)
    return;
  
  AFHTTPRequestOperation *request = _requestOperations[requestID];
  [request cancel];
  [_requestOperations removeObjectForKey:requestID];
}

@end
