//
//  MIMethod.m
//  MappedInCocoa
//
//  Created by Dan Lichty on 2013-10-21.
//  Copyright (c) 2013 MappedIn, Inc. All rights reserved.
//

#import "MIMethod.h"

@implementation MIMethod

- (id)initWithName:(NSString *)name path:(NSString *)path method:(NSString *)method arguments:(NSArray *)args
{
  self = [super init];
  
  _name = name;
  _path = path;
  _method = method;
  _arguments = args;
  
  return self;
}

- (id)initWithCoder:(NSCoder *)decoder
{
  self = [super init];
  
  _name = [decoder decodeObjectForKey:@"name"];
  _path = [decoder decodeObjectForKey:@"path"];
  _method = [decoder decodeObjectForKey:@"method"];
  _arguments = [decoder decodeObjectForKey:@"arguments"];
  
  return self;
}

- (void)encodeWithCoder:(NSCoder *)coder
{
  [coder encodeObject:_name forKey:@"name"];
  [coder encodeObject:_path forKey:@"path"];
  [coder encodeObject:_method forKey:@"method"];
  [coder encodeObject:_arguments forKey:@"arguments"];
}

- (NSString *)description
{
  return [NSString stringWithFormat:@"%@: %@ (%@)", self.name, self.path, self.method];
}

- (NSDictionary *)requestArgumentsForData:(NSDictionary *)data
{
  NSMutableDictionary *requestArgs = [NSMutableDictionary dictionary];
  
  for (NSDictionary *argument in _arguments)
  {
    NSString *argumentName = argument[@"name"];
    NSString *argumentParameter = argument[@"param"];
    
    id value = data[argumentName];
    if (value)
    {
      requestArgs[argumentParameter] = value;
    }
  }
  
  return requestArgs;
}

@end
