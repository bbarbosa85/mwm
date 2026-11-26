//
//  MWMSyncPlan.m
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

#import "MWMSyncPlan.h"
#import <CommonCrypto/CommonDigest.h>

static NSString *const kSnapshotsName = @"Snapshots";

@implementation MWMSyncFile

+ (NSString *)hashOfText:(NSString *)text {
  NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding] ?: [NSData data];
  unsigned char digest[CC_SHA256_DIGEST_LENGTH];
  CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
  NSMutableString *hex = [NSMutableString stringWithCapacity:2 * CC_SHA256_DIGEST_LENGTH];
  for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) [hex appendFormat:@"%02x", digest[i]];
  return hex;
}

+ (instancetype)fileNamed:(NSString *)name contentHash:(NSString *)contentHash modified:(NSDate *)modified {
  MWMSyncFile *file = [[MWMSyncFile alloc] init];
  file.name = name;
  file.contentHash = contentHash;
  file.modified = modified;
  return file;
}

+ (instancetype)fileNamed:(NSString *)name text:(NSString *)text modified:(NSDate *)modified {
  MWMSyncFile *file = [self fileNamed:name contentHash:[self hashOfText:text] modified:modified];
  file.text = text;
  return file;
}

@end

@implementation MWMSyncItem
- (BOOL)willSend { return self.status == MWMSyncStatusChangedHere || self.status == MWMSyncStatusOnlyHere; }
- (BOOL)willReceive { return self.status == MWMSyncStatusNewerInGist || self.status == MWMSyncStatusOnlyInGist; }
- (BOOL)flagged { return self.status == MWMSyncStatusDeletedHere || self.status == MWMSyncStatusDeletedInGist; }
- (NSString *)remoteName { return self.remote.name ?: self.name; }
@end

@implementation MWMSyncPlan

+ (NSString *)snapshotsName { return kSnapshotsName; }

+ (MWMSyncItem *)itemNamed:(NSString *)name local:(MWMSyncFile *)local remote:(MWMSyncFile *)remote baseHash:(NSString *)baseHash {
  MWMSyncItem *item = [[MWMSyncItem alloc] init];
  item.name = name;
  item.isSnapshots = [name caseInsensitiveCompare:kSnapshotsName] == NSOrderedSame;
  item.local = local;
  item.remote = remote;
  BOOL hadIt = baseHash != nil;

  if (local != nil && remote != nil) {
    if ([local.contentHash isEqualToString:remote.contentHash]) { item.status = MWMSyncStatusSynced; return item; }
    BOOL localChanged = !hadIt || ![local.contentHash isEqualToString:baseHash];
    BOOL remoteChanged = !hadIt || ![remote.contentHash isEqualToString:baseHash];
    if (localChanged && !remoteChanged) item.status = MWMSyncStatusChangedHere;
    else if (remoteChanged && !localChanged) item.status = MWMSyncStatusNewerInGist;
    else {
      // Both changed (or never synced and different): the newer one wins; a tie goes to this computer.
      item.conflict = YES;
      BOOL remoteNewer = local.modified != nil && remote.modified != nil && [remote.modified compare:local.modified] == NSOrderedDescending;
      if (local.modified == nil && remote.modified != nil) remoteNewer = YES;
      item.status = remoteNewer ? MWMSyncStatusNewerInGist : MWMSyncStatusChangedHere;
    }
  } else if (local != nil) {
    if (hadIt && [local.contentHash isEqualToString:baseHash] && !item.isSnapshots) item.status = MWMSyncStatusDeletedInGist;
    else item.status = MWMSyncStatusOnlyHere;
  } else {
    if (hadIt && [remote.contentHash isEqualToString:baseHash] && !item.isSnapshots) item.status = MWMSyncStatusDeletedHere;
    else item.status = MWMSyncStatusOnlyInGist;
  }
  return item;
}

+ (NSArray<MWMSyncItem *> *)planForLocal:(NSArray<MWMSyncFile *> *)local remote:(NSArray<MWMSyncFile *> *)remote base:(NSDictionary<NSString *, NSString *> *)base {
  NSMutableDictionary *localByKey = [NSMutableDictionary dictionary], *remoteByKey = [NSMutableDictionary dictionary], *baseByKey = [NSMutableDictionary dictionary];
  for (MWMSyncFile *file in local) localByKey[file.name.lowercaseString] = file;
  for (MWMSyncFile *file in remote) remoteByKey[file.name.lowercaseString] = file;
  for (NSString *name in base) baseByKey[name.lowercaseString] = base[name];
  NSMutableSet *keys = [NSMutableSet setWithArray:[localByKey allKeys]];
  [keys addObjectsFromArray:[remoteByKey allKeys]];
  NSMutableArray *items = [NSMutableArray array];
  for (NSString *key in keys) {
    MWMSyncFile *l = localByKey[key], *r = remoteByKey[key];
    [items addObject:[self itemNamed:(l ?: r).name local:l remote:r baseHash:baseByKey[key]]];
  }
  // Profiles by name, the snapshots last.
  [items sortUsingComparator:^NSComparisonResult(MWMSyncItem *a, MWMSyncItem *b) {
    if (a.isSnapshots != b.isSnapshots) return a.isSnapshots ? NSOrderedDescending : NSOrderedAscending;
    return [a.name caseInsensitiveCompare:b.name];
  }];
  return items;
}

@end
