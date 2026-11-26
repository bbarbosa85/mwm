//
//  TestFakeGitHub.h
//
//  A small stand-in for the parts of the GitHub gists API that backups use, kept in memory.
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

#import <Foundation/Foundation.h>

@interface TestFakeGitHub : NSObject
@property (strong) NSMutableDictionary<NSString *, NSMutableDictionary *> *gists;
@property (strong) NSMutableArray<NSURLRequest *> *requests;
@property (assign) NSInteger status;   // when not 200, every request answers with it
- (void)install;
- (void)addFile:(NSString *)name content:(NSString *)content toGistWithDescription:(NSString *)description;
- (void)addPublicGistNamed:(NSString *)description;
// Makes the private "MWM backup" gist with these files (name → text).
- (void)addBackupGistWithFiles:(NSDictionary<NSString *, NSString *> *)files;
// The files of the private "MWM backup" gist, by name (empty when there is none).
- (NSDictionary<NSString *, NSString *> *)backupFiles;
@end
