//
//  MWMConfig.h
//  Slate
//
//  Created by Jigish Patel on 5/18/11.
//  Copyright 2011 Jigish Patel. All rights reserved.
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

#import <Cocoa/Cocoa.h>
#import "Snapshot.h"

@class Binding;

@interface MWMConfig : NSObject {
@private
  NSMutableDictionary *configs;
  NSMutableDictionary *configDefaults;
  NSMutableArray *bindings;
  NSMutableDictionary *modalBindings;
  NSMutableDictionary *layouts;
  NSMutableArray *defaultLayouts;
  NSMutableDictionary *aliases;
  NSMutableDictionary *snapshots;
}

@property NSMutableDictionary *configs;
@property NSMutableDictionary *configDefaults;
@property NSMutableDictionary *appConfigs; // two layer map
@property NSMutableArray *bindings;
@property NSMutableDictionary *modalBindings;
@property NSMutableDictionary *layouts;
@property NSMutableArray *defaultLayouts;
@property NSMutableDictionary *aliases;
@property NSMutableDictionary *snapshots;
// The text of ~/.mwm.yml as MWM loaded it at launch (nil if there was no file). The configuration window
// compares it with the saved file to say when changes are saved but not applied yet.
@property (copy, nullable) NSString *loadedConfigText;

+ (MWMConfig *)getInstance;
- (BOOL)load;
- (BOOL)loadConfigFileWithPath:(NSString *)file;
- (BOOL)addLayout:(NSString *)name dict:(NSDictionary *)dict;
- (void)addDefault:(id)screenConfig layout:(NSString *)layout;
- (void)addBinding:(Binding *)bind;
- (BOOL)append:(NSString *)configString;
- (BOOL)loadSnapshots;
- (BOOL)getBoolConfig:(NSString *)key;
- (void)setConfig:(NSString *)key to:(NSString *)value;
- (NSInteger)getIntegerConfig:(NSString *)key;
- (double)getDoubleConfig:(NSString *)key;
- (float)getFloatConfig:(NSString *)key;
- (NSString *)getConfig:(NSString *)key;
- (NSString *)getConfigDefault:(NSString *)key;
- (NSString *)getConfig:(NSString *)key app:(NSString *)app;
- (NSArray *)getArrayConfig:(NSString *)key;
- (void)addAlias:(NSString *)line;
- (NSString *)replaceAliases:(NSString *)line;
- (void)onScreenChange:(id)notification;
- (void)setupDefaultConfigs;
- (void)addSnapshot:(Snapshot *)snapshot name:(NSString *)name saveToDisk:(BOOL)saveToDisk isStack:(BOOL)isStack stackSize:(NSUInteger)stackSize;
- (void)deleteSnapshot:(NSString *)name pop:(BOOL)pop;
- (void)saveSnapshots;
- (Snapshot *)popSnapshot:(NSString *)name remove:(BOOL)remove;
- (void)activateLayoutOrSnapshot:(NSString *)name;
- (NSString *)stripComments:(NSString *)line;
//- (void)processNotification:(id)notification;

+ (NSURL *)snapshotsFile;

@end

void onDisplayReconfiguration (CGDirectDisplayID display, CGDisplayChangeSummaryFlags flags, void *userInfo);
