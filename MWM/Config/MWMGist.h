//
//  MWMGist.h
//
//  Backups live in one private GitHub gist ("MWM backup"), one file per configuration. This talks to
//  the GitHub API with a token the person pastes, kept in the Keychain. Every call answers on the
//  main thread with a plain-language problem (nil when it worked).
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

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

// How a request is sent. The default is NSURLSession; tests replace it.
typedef void (^MWMGistResponse)(NSData *_Nullable data, NSHTTPURLResponse *_Nullable response, NSError *_Nullable error);
typedef void (^MWMGistTransport)(NSURLRequest *request, MWMGistResponse done);

@interface MWMGist : NSObject

+ (void)setTransport:(nullable MWMGistTransport)transport;
// Tests keep the token in memory instead of the Keychain, and forget the remembered gist.
+ (void)useMemoryStorage:(BOOL)memory;

+ (nullable NSString *)token;
+ (void)setToken:(nullable NSString *)token;

// Checks the token with GitHub.
+ (void)checkToken:(NSString *)token completion:(void (^)(NSString *_Nullable problem))done;
// Every file in the gist, by name, as text. `exists` is NO when there is no backup gist yet (then `files` is empty).
+ (void)fetchFiles:(void (^)(NSDictionary<NSString *, NSString *> *files, BOOL exists, NSString *_Nullable problem))done;
// Adds or replaces files (NSString values) and removes the ones whose value is NSNull, in one request. Creates the
// private gist when there is none and something is added.
+ (void)updateFiles:(NSDictionary<NSString *, id> *)files completion:(void (^)(NSString *_Nullable problem))done;

@end

NS_ASSUME_NONNULL_END
