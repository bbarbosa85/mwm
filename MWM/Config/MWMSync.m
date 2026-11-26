//
//  MWMSync.m
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

#import "MWMSync.h"
#import "MWMConfig.h"
#import "MWMProfiles.h"
#import "MWMGist.h"
#import "MWMSnapshots.h"

static NSString *const kManifestFile = @"mwm-sync.json";
static NSString *const kSnapshotsFile = @"snapshots.json";
static NSString *const kStateFile = @".sync.json";
static NSDate *gSnapshotsModified;

@implementation MWMSyncReport
- (NSString *)summary {
  return [NSString stringWithFormat:@"Sent %lu, received %lu, %lu up to date", (unsigned long)self.sent, (unsigned long)self.received, (unsigned long)self.upToDate];
}
@end

#pragma mark - Dates and files

static NSDateFormatter *ISOFormatter(void) {
  static NSDateFormatter *formatter;
  static dispatch_once_t once;
  dispatch_once(&once, ^{
    formatter = [[NSDateFormatter alloc] init];
    formatter.locale = [NSLocale localeWithLocaleIdentifier:@"en_US_POSIX"];
    formatter.timeZone = [NSTimeZone timeZoneForSecondsFromGMT:0];
    formatter.dateFormat = @"yyyy-MM-dd'T'HH:mm:ss'Z'";
  });
  return formatter;
}

static NSString *GistFileNameForConfiguration(NSString *name) { return [name stringByAppendingString:@".mwm.yaml"]; }

// "desk" for desk.mwm.yaml and desk.mwm.yml, nil for any other gist file.
static NSString *ConfigurationNameForGistFile(NSString *file) {
  for (NSString *extension in @[@".mwm.yaml", @".mwm.yml"]) {
    if ([file.lowercaseString hasSuffix:extension] && [file length] > [extension length] && ![file hasPrefix:@"."]) return [file substringToIndex:[file length] - [extension length]];
  }
  return nil;
}

@implementation MWMSync

+ (void)setSnapshotsModifiedOverride:(NSDate *)date { gSnapshotsModified = date; }

#pragma mark - The state kept here

+ (NSString *)statePath { return [[MWMProfiles folder] stringByAppendingPathComponent:kStateFile]; }

+ (NSDictionary *)state {
  NSData *data = [NSData dataWithContentsOfFile:[self statePath]];
  id json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
  return [json isKindOfClass:[NSDictionary class]] ? json : @{};
}

+ (NSDictionary<NSString *, NSString *> *)base {
  id base = [self state][@"base"];
  return [base isKindOfClass:[NSDictionary class]] ? base : @{};
}

+ (void)saveBase:(NSDictionary *)base summary:(NSString *)summary {
  NSMutableDictionary *state = [NSMutableDictionary dictionaryWithDictionary:[self state]];
  state[@"version"] = @1;
  state[@"base"] = base;
  if (summary != nil) { state[@"lastSync"] = [ISOFormatter() stringFromDate:[NSDate date]]; state[@"summary"] = summary; }
  if (![MWMProfiles createFolder:nil]) return;
  NSData *data = [NSJSONSerialization dataWithJSONObject:state options:NSJSONWritingSortedKeys | NSJSONWritingPrettyPrinted error:nil];
  [data writeToFile:[self statePath] atomically:YES];
}

+ (NSDate *)lastSyncDate {
  NSString *text = [self state][@"lastSync"];
  return [text isKindOfClass:[NSString class]] ? [ISOFormatter() dateFromString:text] : nil;
}

+ (NSString *)lastSummary {
  NSString *text = [self state][@"summary"];
  return [text isKindOfClass:[NSString class]] ? text : nil;
}

#pragma mark - This computer

+ (NSString *)snapshotsText {
  NSDictionary *snapshots = [MWMSnapshots exportAll];
  if ([snapshots count] == 0) return nil;
  NSData *data = [NSJSONSerialization dataWithJSONObject:snapshots options:NSJSONWritingSortedKeys | NSJSONWritingPrettyPrinted error:nil];
  return data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
}

+ (NSDate *)snapshotsModified {
  if (gSnapshotsModified != nil) return gSnapshotsModified;
  NSURL *file = [MWMConfig snapshotsFile];
  return file ? [[NSFileManager defaultManager] attributesOfItemAtPath:file.path error:nil][NSFileModificationDate] : nil;
}

+ (NSArray<MWMSyncFile *> *)localFiles {
  NSMutableArray *files = [NSMutableArray array];
  for (NSString *name in [MWMProfiles names]) {
    NSString *text = [NSString stringWithContentsOfFile:[MWMProfiles pathForName:name] encoding:NSUTF8StringEncoding error:nil];
    if (text == nil) continue;
    [files addObject:[MWMSyncFile fileNamed:name text:text modified:[MWMProfiles modificationDateForName:name]]];
  }
  NSString *snapshots = [self snapshotsText];
  if (snapshots != nil) [files addObject:[MWMSyncFile fileNamed:[MWMSyncPlan snapshotsName] text:snapshots modified:[self snapshotsModified] ?: [NSDate distantPast]]];
  return files;
}

#pragma mark - The gist

// The manifest: for each file, when it was last sent from a computer.
+ (NSDictionary<NSString *, NSDictionary *> *)manifestFrom:(NSDictionary<NSString *, NSString *> *)gistFiles {
  NSData *data = [gistFiles[kManifestFile] dataUsingEncoding:NSUTF8StringEncoding];
  id json = data ? [NSJSONSerialization JSONObjectWithData:data options:0 error:nil] : nil;
  id files = [json isKindOfClass:[NSDictionary class]] ? json[@"files"] : nil;
  return [files isKindOfClass:[NSDictionary class]] ? files : @{};
}

+ (NSArray<MWMSyncFile *> *)remoteFilesFrom:(NSDictionary<NSString *, NSString *> *)gistFiles {
  NSDictionary *manifest = [self manifestFrom:gistFiles];
  NSMutableArray *files = [NSMutableArray array];
  for (NSString *fileName in gistFiles) {
    NSString *name = [fileName isEqualToString:kSnapshotsFile] ? [MWMSyncPlan snapshotsName] : ConfigurationNameForGistFile(fileName);
    if (name == nil) continue;
    NSDictionary *entry = manifest[name];
    NSString *when = [entry isKindOfClass:[NSDictionary class]] ? entry[@"updatedAt"] : nil;
    [files addObject:[MWMSyncFile fileNamed:name text:gistFiles[fileName] modified:[when isKindOfClass:[NSString class]] ? [ISOFormatter() dateFromString:when] : nil]];
  }
  return files;
}

+ (NSString *)gistFileNameForItemName:(NSString *)name isSnapshots:(BOOL)isSnapshots {
  return isSnapshots ? kSnapshotsFile : GistFileNameForConfiguration(name);
}

// The gist's file name for what is already there (it may be spelled in another case than here).
+ (NSString *)remoteFileNameForItem:(MWMSyncItem *)item {
  return [self gistFileNameForItemName:item.remote ? item.remote.name : item.name isSnapshots:item.isSnapshots];
}

+ (NSString *)manifestTextFor:(NSDictionary *)entries {
  NSData *data = [NSJSONSerialization dataWithJSONObject:@{@"version": @1, @"files": entries} options:NSJSONWritingSortedKeys | NSJSONWritingPrettyPrinted error:nil];
  return [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
}

+ (NSDictionary *)manifestEntryForHash:(NSString *)hash date:(NSDate *)date {
  return @{@"hash": hash, @"updatedAt": [ISOFormatter() stringFromDate:date ?: [NSDate date]]};
}

#pragma mark - Preview

+ (void)preview:(void (^)(NSArray<MWMSyncItem *> *, NSString *))done {
  [MWMGist fetchFiles:^(NSDictionary<NSString *, NSString *> *gistFiles, BOOL exists, NSString *problem) {
    if (problem != nil) { done(@[], problem); return; }
    done([MWMSyncPlan planForLocal:[self localFiles] remote:[self remoteFilesFrom:gistFiles] base:[self base]], nil);
  }];
}

#pragma mark - Sync

+ (void)syncWithCompletion:(void (^)(MWMSyncReport *))done {
  [MWMGist fetchFiles:^(NSDictionary<NSString *, NSString *> *gistFiles, BOOL exists, NSString *problem) {
    MWMSyncReport *report = [[MWMSyncReport alloc] init];
    report.items = @[];
    report.flagged = @[];
    if (problem != nil) { report.problem = problem; done(report); return; }
    NSArray<MWMSyncItem *> *items = [MWMSyncPlan planForLocal:[self localFiles] remote:[self remoteFilesFrom:gistFiles] base:[self base]];
    report.items = items;
    NSMutableDictionary *base = [NSMutableDictionary dictionaryWithDictionary:[self base]];
    NSMutableDictionary *manifest = [NSMutableDictionary dictionaryWithDictionary:[self manifestFrom:gistFiles]];
    NSMutableDictionary *outgoing = [NSMutableDictionary dictionary];
    NSMutableArray *flagged = [NSMutableArray array];
    __block NSString *error = nil;

    for (MWMSyncItem *item in items) {
      NSString *key = item.name.lowercaseString;
      if (item.flagged) { [flagged addObject:item]; continue; }
      if (item.willReceive) {
        if (item.isSnapshots) {
          id json = [NSJSONSerialization JSONObjectWithData:[item.remote.text dataUsingEncoding:NSUTF8StringEncoding] options:0 error:nil];
          if ([json isKindOfClass:[NSDictionary class]]) [MWMSnapshots importAll:json];
          else { error = error ?: @"The snapshots in your gist couldn't be read."; continue; }
        } else {
          NSError *writeError = nil;
          if (![MWMProfiles writeText:item.remote.text named:item.name error:&writeError]) { error = error ?: [NSString stringWithFormat:@"“%@” couldn't be saved here: %@", item.name, writeError.localizedDescription]; continue; }
        }
        base[key] = item.remote.contentHash;
        report.received++;
      } else if (item.willSend) {
        NSString *fileName = [self gistFileNameForItemName:item.name isSnapshots:item.isSnapshots];
        outgoing[fileName] = item.local.text;
        // A different spelling in the gist is replaced by this one.
        NSString *old = item.remote != nil ? [self remoteFileNameForItem:item] : nil;
        if (old != nil && ![old isEqualToString:fileName]) { outgoing[old] = [NSNull null]; [manifest removeObjectForKey:item.remote.name]; }
        manifest[item.name] = [self manifestEntryForHash:item.local.contentHash date:item.local.modified];
        base[key] = item.local.contentHash;
        report.sent++;
      } else {
        base[key] = item.local.contentHash;
        report.upToDate++;
      }
    }
    report.flagged = flagged;

    void (^finish)(void) = ^{
      report.problem = error;
      report.date = [NSDate date];
      if (error == nil) [self saveBase:base summary:report.summary];
      done(report);
    };
    if ([outgoing count] == 0) { finish(); return; }
    outgoing[kManifestFile] = [self manifestTextFor:manifest];
    [MWMGist updateFiles:outgoing completion:^(NSString *updateProblem) {
      if (updateProblem != nil) { error = updateProblem; report.sent = 0; }
      finish();
    }];
  }];
}

#pragma mark - Deleted files

+ (void)resolveFlagged:(NSArray<MWMSyncItem *> *)flagged keep:(BOOL)keep completion:(void (^)(NSString *, NSString *))done {
  if ([flagged count] == 0) { done(@"", nil); return; }
  [MWMGist fetchFiles:^(NSDictionary<NSString *, NSString *> *gistFiles, BOOL exists, NSString *problem) {
    if (problem != nil) { done(@"", problem); return; }
    NSMutableDictionary *base = [NSMutableDictionary dictionaryWithDictionary:[self base]];
    NSMutableDictionary *manifest = [NSMutableDictionary dictionaryWithDictionary:[self manifestFrom:gistFiles]];
    NSMutableDictionary *outgoing = [NSMutableDictionary dictionary];
    NSMutableArray *notes = [NSMutableArray array];

    for (MWMSyncItem *item in flagged) {
      NSString *key = item.name.lowercaseString;
      BOOL deletedHere = item.status == MWMSyncStatusDeletedHere;
      if (keep) {
        if (deletedHere) {
          // Bring it back here, under a dated name if something else took the name meanwhile.
          NSString *name = [MWMProfiles existsNamed:item.name] ? [MWMProfiles datedNameFrom:item.name date:[NSDate date]] : item.name;
          if ([MWMProfiles writeText:item.remote.text named:name error:nil]) {
            [notes addObject:[NSString stringWithFormat:@"“%@” is back here%@.", item.name, [name isEqualToString:item.name] ? @"" : [NSString stringWithFormat:@" as “%@”", name]]];
            base[key] = item.remote.contentHash;
          }
        } else {
          outgoing[[self remoteFileNameForItem:item]] = item.local.text;
          manifest[item.name] = [self manifestEntryForHash:item.local.contentHash date:item.local.modified];
          [notes addObject:[NSString stringWithFormat:@"“%@” is back in your gist.", item.name]];
          base[key] = item.local.contentHash;
        }
      } else {
        if (deletedHere) {
          outgoing[[self remoteFileNameForItem:item]] = [NSNull null];
          [manifest removeObjectForKey:item.remote.name];
          [base removeObjectForKey:key];
          [notes addObject:[NSString stringWithFormat:@"“%@” was removed from your gist.", item.name]];
        } else {
          NSError *deleteError = nil;
          if ([MWMProfiles deleteNamed:item.name error:&deleteError]) {
            [base removeObjectForKey:key];
            [notes addObject:[NSString stringWithFormat:@"“%@” was moved to the Trash.", item.name]];
          } else {
            // The active or the last profile stays: send it to the gist again.
            outgoing[[self remoteFileNameForItem:item]] = item.local.text;
            manifest[item.name] = [self manifestEntryForHash:item.local.contentHash date:item.local.modified];
            base[key] = item.local.contentHash;
            [notes addObject:[NSString stringWithFormat:@"“%@” was kept: %@", item.name, deleteError.localizedDescription]];
          }
        }
      }
    }
    void (^finish)(NSString *) = ^(NSString *updateProblem) {
      if (updateProblem == nil) [self saveBase:base summary:nil];
      done([notes componentsJoinedByString:@"\n"], updateProblem);
    };
    if ([outgoing count] == 0) { finish(nil); return; }
    outgoing[kManifestFile] = [self manifestTextFor:manifest];
    [MWMGist updateFiles:outgoing completion:finish];
  }];
}

@end
