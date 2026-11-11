//
//  SlateLegacyMigration.h
//  Slate
//
//  Converts the older configuration files (~/.slate, a ~/.slate.js written by
//  the earlier configuration window, and ~/.slate.yml) into ~/.mwm.yml on startup.
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

@class SlateConfigDocument;

NS_ASSUME_NONNULL_BEGIN

@interface SlateLegacyMigration : NSObject

// Converts legacy .slate text. config/alias/bind lines become settings, aliases
// and bindings; commented-out bind lines become disabled bindings; section
// headers become binding groups and comments directly above a binding become
// its note. Lines that couldn't be converted are described in `warnings`.
+ (SlateConfigDocument *)documentFromLegacySource:(NSString *)source warnings:(NSMutableArray<NSString *> *)warnings;

// Reads a ~/.slate.js written by the earlier configuration window, evaluating
// it once in a bare JSContext (no Slate API, files or shell). Fails for any
// other JavaScript. Custom code after the marker isn't carried over.
+ (nullable SlateConfigDocument *)documentFromJavaScript:(NSString *)javaScript
                                                warnings:(NSMutableArray<NSString *> *)warnings
                                                   error:(NSError **)error;

// Adds `lower` into `higher`, with `higher` winning where both set something.
+ (SlateConfigDocument *)documentByMerging:(SlateConfigDocument *)lower
                                      into:(SlateConfigDocument *)higher
                                 lowerName:(NSString *)lowerName
                                higherName:(NSString *)higherName
                                  warnings:(NSMutableArray<NSString *> *)warnings;

// Converts whichever of legacyPath, jsPath and oldYAMLPath exist (merging into
// ymlPath when it exists, which wins), writes ymlPath, then renames the old
// files to <path>.migrated-<timestamp> so they stop loading. Returns those
// backup paths, or nil (with nothing changed on disk) on failure.
+ (nullable NSArray<NSString *> *)migrateLegacyFile:(nullable NSString *)legacyPath
                                     javaScriptFile:(nullable NSString *)jsPath
                                        oldYAMLFile:(nullable NSString *)oldYAMLPath
                                             toFile:(NSString *)ymlPath
                                           warnings:(NSMutableArray<NSString *> *)warnings
                                              error:(NSError **)error;

// Startup entry point: converts ~/.slate, ~/.slate.js and ~/.slate.yml into ~/.mwm.yml,
// asking first if ~/.mwm.yml already exists. Shows alerts; does nothing
// when neither old file exists.
+ (void)runStartupMigration;

@end

NS_ASSUME_NONNULL_END
