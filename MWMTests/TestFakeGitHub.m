//
//  TestFakeGitHub.m
//
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License

#import "TestFakeGitHub.h"
#import "MWMGist.h"

@implementation TestFakeGitHub

- (instancetype)init {
  self = [super init];
  if (self) { _gists = [NSMutableDictionary dictionary]; _requests = [NSMutableArray array]; _status = 200; }
  return self;
}

- (NSMutableDictionary *)makeGistWithDescription:(NSString *)description public:(BOOL)public files:(NSDictionary *)files {
  NSString *identifier = [NSString stringWithFormat:@"gist%lu", (unsigned long)[self.gists count] + 1];
  NSMutableDictionary *gist = [NSMutableDictionary dictionaryWithDictionary:@{@"id": identifier, @"description": description, @"public": @(public), @"files": [NSMutableDictionary dictionary]}];
  [self apply:files to:gist];
  self.gists[identifier] = gist;
  return gist;
}

- (void)apply:(NSDictionary *)files to:(NSMutableDictionary *)gist {
  NSMutableDictionary *stored = gist[@"files"];
  for (NSString *name in files) {
    if ([files[name] isKindOfClass:[NSNull class]]) [stored removeObjectForKey:name];
    else stored[name] = @{@"filename": name, @"content": files[name][@"content"], @"truncated": @NO};
  }
}

- (void)addFile:(NSString *)name content:(NSString *)content toGistWithDescription:(NSString *)description {
  for (NSMutableDictionary *gist in [self.gists allValues]) if ([gist[@"description"] isEqual:description]) [self apply:@{name: @{@"content": content}} to:gist];
}

- (void)addPublicGistNamed:(NSString *)description { [self makeGistWithDescription:description public:YES files:@{}]; }

- (NSData *)json:(id)object { return [NSJSONSerialization dataWithJSONObject:object options:0 error:nil]; }

- (void)install {
  __weak TestFakeGitHub *weak = self;
  [MWMGist setTransport:^(NSURLRequest *request, MWMGistResponse done) {
    TestFakeGitHub *fake = weak;
    [fake.requests addObject:request];
    NSString *path = [request.URL path];
    NSString *method = request.HTTPMethod;
    NSDictionary *body = request.HTTPBody ? [NSJSONSerialization JSONObjectWithData:request.HTTPBody options:0 error:nil] : nil;
    NSInteger status = 200;
    id answer = @{};
    if (fake.status != 200) {
      status = fake.status;
    } else if ([path isEqualToString:@"/gists"] && [method isEqualToString:@"GET"]) {
      NSMutableArray *list = [NSMutableArray array];
      for (NSDictionary *gist in [fake.gists allValues]) [list addObject:@{@"id": gist[@"id"], @"description": gist[@"description"], @"public": gist[@"public"]}];
      answer = list;
    } else if ([path isEqualToString:@"/gists"] && [method isEqualToString:@"POST"]) {
      answer = [fake makeGistWithDescription:body[@"description"] public:[body[@"public"] boolValue] files:body[@"files"]];
      status = 201;
    } else if ([path hasPrefix:@"/gists/"]) {
      NSMutableDictionary *gist = fake.gists[[path substringFromIndex:7]];
      if (gist == nil) status = 404;
      else if ([method isEqualToString:@"PATCH"]) { [fake apply:body[@"files"] to:gist]; answer = gist; }
      else answer = gist;
    }
    NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:request.URL statusCode:status HTTPVersion:@"HTTP/1.1" headerFields:nil];
    done([fake json:answer], response, nil);
  }];
}

@end
