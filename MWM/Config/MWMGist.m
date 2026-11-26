//
//  MWMGist.m
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
//  along with this program.  If not, see http://www.gnu.org/licenses

#import "MWMGist.h"
#import <Security/Security.h>

static NSString *const kService = @"MWM backup (GitHub token)";
static NSString *const kAccount = @"github";
static NSString *const kGistKey = @"MWMBackupGistID";
static NSString *const kDescription = @"MWM backup";
static NSString *const kAPI = @"https://api.github.com";

static MWMGistTransport gTransport;
static BOOL gMemory;
static NSString *gMemoryToken;
static NSString *gMemoryGist;

@implementation MWMGist

+ (void)setTransport:(MWMGistTransport)transport { gTransport = [transport copy]; }

+ (void)useMemoryStorage:(BOOL)memory {
  gMemory = memory;
  gMemoryToken = nil;
  gMemoryGist = nil;
}

#pragma mark - Token

+ (NSDictionary *)keychainQuery {
  return @{(__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword, (__bridge id)kSecAttrService: kService, (__bridge id)kSecAttrAccount: kAccount};
}

+ (NSString *)token {
  if (gMemory) return gMemoryToken;
  NSMutableDictionary *query = [[self keychainQuery] mutableCopy];
  query[(__bridge id)kSecReturnData] = @YES;
  CFTypeRef found = NULL;
  if (SecItemCopyMatching((__bridge CFDictionaryRef)query, &found) != errSecSuccess || found == NULL) return nil;
  NSData *data = CFBridgingRelease(found);
  return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

+ (void)setToken:(NSString *)token {
  NSString *trimmed = [token stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if (gMemory) { gMemoryToken = [trimmed length] > 0 ? trimmed : nil; return; }
  SecItemDelete((__bridge CFDictionaryRef)[self keychainQuery]);
  if ([trimmed length] == 0) return;
  NSMutableDictionary *item = [[self keychainQuery] mutableCopy];
  item[(__bridge id)kSecValueData] = [trimmed dataUsingEncoding:NSUTF8StringEncoding];
  SecItemAdd((__bridge CFDictionaryRef)item, NULL);
}

+ (NSString *)rememberedGist { return gMemory ? gMemoryGist : [[NSUserDefaults standardUserDefaults] stringForKey:kGistKey]; }

+ (void)rememberGist:(NSString *)identifier {
  if (gMemory) { gMemoryGist = identifier; return; }
  if (identifier) [[NSUserDefaults standardUserDefaults] setObject:identifier forKey:kGistKey];
  else [[NSUserDefaults standardUserDefaults] removeObjectForKey:kGistKey];
}

#pragma mark - Requests

+ (NSString *)problemForStatus:(NSInteger)status error:(NSError *)error {
  if (error != nil) return [NSString stringWithFormat:@"Couldn't reach GitHub. %@", [error localizedDescription]];
  if (status == 401) return @"GitHub didn't accept the token. Check that it's current and has the gist permission.";
  if (status == 403) return @"GitHub refused the request. Check that the token has the gist permission, or try again later.";
  if (status == 404) return @"GitHub couldn't find that. Check that the token has the gist permission.";
  if (status < 200 || status >= 300) return [NSString stringWithFormat:@"GitHub answered with status %ld.", (long)status];
  return nil;
}

// Sends one request with the token and answers on the main thread with the parsed JSON.
+ (void)send:(NSString *)method path:(NSString *)path body:(NSDictionary *)body token:(NSString *)token completion:(void (^)(id json, NSInteger status, NSString *problem))done {
  if ([token length] == 0) { dispatch_async(dispatch_get_main_queue(), ^{ done(nil, 0, @"Add a GitHub token first."); }); return; }
  NSURL *url = [NSURL URLWithString:[path hasPrefix:@"http"] ? path : [kAPI stringByAppendingString:path]];
  NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:url];
  [request setHTTPMethod:method];
  [request setValue:[@"Bearer " stringByAppendingString:token] forHTTPHeaderField:@"Authorization"];
  [request setValue:@"application/vnd.github+json" forHTTPHeaderField:@"Accept"];
  [request setValue:@"2022-11-28" forHTTPHeaderField:@"X-GitHub-Api-Version"];
  [request setValue:@"MWM" forHTTPHeaderField:@"User-Agent"];
  if (body != nil) {
    [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    [request setHTTPBody:[NSJSONSerialization dataWithJSONObject:body options:0 error:nil]];
  }
  MWMGistResponse finish = ^(NSData *data, NSHTTPURLResponse *response, NSError *error) {
    NSInteger status = response.statusCode;
    NSString *problem = [self problemForStatus:status error:error];
    id json = (problem == nil && [data length] > 0) ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
    if (problem == nil && json == nil && ![method isEqualToString:@"DELETE"] && ![path hasPrefix:@"http"] && [data length] > 0) problem = @"GitHub's answer wasn't what MWM expected.";
    if (problem == nil && json == nil && [path hasPrefix:@"http"]) json = [[NSString alloc] initWithData:data ?: [NSData data] encoding:NSUTF8StringEncoding];
    dispatch_async(dispatch_get_main_queue(), ^{ done(json, status, problem); });
  };
  if (gTransport != nil) { gTransport(request, finish); return; }
  [[[NSURLSession sharedSession] dataTaskWithRequest:request completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
    finish(data, [response isKindOfClass:[NSHTTPURLResponse class]] ? (NSHTTPURLResponse *)response : nil, error);
  }] resume];
}

+ (void)checkToken:(NSString *)token completion:(void (^)(NSString *))done {
  [self send:@"GET" path:@"/gists?per_page=1" body:nil token:token completion:^(id json, NSInteger status, NSString *problem) { done(problem); }];
}

// The backup gist (a dictionary from the API), or nil when there is none yet.
+ (void)findGistWithToken:(NSString *)token completion:(void (^)(NSDictionary *gist, NSString *problem))done {
  void (^search)(void) = ^{
    [self send:@"GET" path:@"/gists?per_page=100" body:nil token:token completion:^(id json, NSInteger status, NSString *problem) {
      if (problem != nil) { done(nil, problem); return; }
      for (id gist in [json isKindOfClass:[NSArray class]] ? json : @[]) {
        if ([gist isKindOfClass:[NSDictionary class]] && [gist[@"description"] isEqual:kDescription] && ![gist[@"public"] boolValue]) {
          [self rememberGist:gist[@"id"]];
          [self send:@"GET" path:[@"/gists/" stringByAppendingString:gist[@"id"]] body:nil token:token completion:^(id full, NSInteger fullStatus, NSString *fullProblem) {
            done(fullProblem == nil && [full isKindOfClass:[NSDictionary class]] ? full : nil, fullProblem);
          }];
          return;
        }
      }
      done(nil, nil);
    }];
  };
  NSString *remembered = [self rememberedGist];
  if (remembered == nil) { search(); return; }
  [self send:@"GET" path:[@"/gists/" stringByAppendingString:remembered] body:nil token:token completion:^(id json, NSInteger status, NSString *problem) {
    if (status == 404) { [self rememberGist:nil]; search(); return; }
    done(problem == nil && [json isKindOfClass:[NSDictionary class]] ? json : nil, problem);
  }];
}

#pragma mark - Files

// Reads the text of one gist file (a truncated one is fetched from its raw_url).
+ (void)textOfFile:(NSDictionary *)file token:(NSString *)token completion:(void (^)(NSString *text, NSString *problem))done {
  if ([file[@"truncated"] boolValue] && [file[@"raw_url"] isKindOfClass:[NSString class]]) {
    [self send:@"GET" path:file[@"raw_url"] body:nil token:token completion:^(id raw, NSInteger status, NSString *problem) {
      if (problem != nil) { done(nil, problem); return; }
      if ([raw isKindOfClass:[NSString class]]) done(raw, nil);
      else if ([raw isKindOfClass:[NSDictionary class]]) done([[NSString alloc] initWithData:[NSJSONSerialization dataWithJSONObject:raw options:0 error:nil] encoding:NSUTF8StringEncoding], nil);
      else done(nil, nil);
    }];
    return;
  }
  done([file[@"content"] isKindOfClass:[NSString class]] ? file[@"content"] : nil, nil);
}

+ (void)fetchFiles:(void (^)(NSDictionary<NSString *, NSString *> *, BOOL, NSString *))done {
  NSString *token = [self token];
  [self findGistWithToken:token completion:^(NSDictionary *gist, NSString *problem) {
    if (problem != nil) { done(@{}, NO, problem); return; }
    if (gist == nil) { done(@{}, NO, nil); return; }
    NSDictionary *files = [gist[@"files"] isKindOfClass:[NSDictionary class]] ? gist[@"files"] : @{};
    NSMutableDictionary *texts = [NSMutableDictionary dictionary];
    dispatch_group_t group = dispatch_group_create();
    __block NSString *firstProblem = nil;
    for (NSString *fileName in files) {
      if (![files[fileName] isKindOfClass:[NSDictionary class]]) continue;
      dispatch_group_enter(group);
      [self textOfFile:files[fileName] token:token completion:^(NSString *text, NSString *fileProblem) {
        if (fileProblem != nil) firstProblem = firstProblem ?: fileProblem;
        else if (text != nil) texts[fileName] = text;
        dispatch_group_leave(group);
      }];
    }
    dispatch_group_notify(group, dispatch_get_main_queue(), ^{ done(firstProblem == nil ? texts : @{}, YES, firstProblem); });
  }];
}

+ (void)updateFiles:(NSDictionary<NSString *, id> *)files completion:(void (^)(NSString *))done {
  NSMutableDictionary *body = [NSMutableDictionary dictionary];
  BOOL adds = NO;
  for (NSString *name in files) {
    if ([files[name] isKindOfClass:[NSString class]]) { body[name] = @{@"content": files[name]}; adds = YES; }
    else body[name] = [NSNull null];
  }
  [self changeFiles:body createIfMissing:adds completion:done];
}

+ (void)changeFiles:(NSDictionary *)files createIfMissing:(BOOL)create completion:(void (^)(NSString *))done {
  NSString *token = [self token];
  [self findGistWithToken:token completion:^(NSDictionary *gist, NSString *problem) {
    if (problem != nil) { done(problem); return; }
    if (gist == nil) {
      if (!create) { done(nil); return; }
      [self send:@"POST" path:@"/gists" body:@{@"description": kDescription, @"public": @NO, @"files": files} token:token completion:^(id json, NSInteger status, NSString *createProblem) {
        if (createProblem == nil && [json isKindOfClass:[NSDictionary class]]) [self rememberGist:json[@"id"]];
        done(createProblem);
      }];
      return;
    }
    [self send:@"PATCH" path:[@"/gists/" stringByAppendingString:gist[@"id"]] body:@{@"files": files} token:token completion:^(id json, NSInteger status, NSString *patchProblem) { done(patchProblem); }];
  }];
}

@end
