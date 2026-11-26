//
//  MWMLegacyMigration.h
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

@class MWMConfigDocument;

NS_ASSUME_NONNULL_BEGIN

@interface MWMLegacyMigration : NSObject

// Converts legacy .slate text. config/alias/bind lines become settings, aliases
// and bindings; commented-out bind lines become disabled bindings; section
// headers become binding groups and comments directly above a binding become
// its note. Lines that couldn't be converted are described in `warnings`.
+ (MWMConfigDocument *)documentFromLegacySource:(NSString *)source warnings:(NSMutableArray<NSString *> *)warnings;

// Reads a ~/.slate.js written by the earlier configuration window, evaluating
// it once in a bare JSContext (no Slate API, files or shell). Fails for any
// other JavaScript. Custom code after the marker isn't carried over.
+ (nullable MWMConfigDocument *)documentFromJavaScript:(NSString *)javaScript
                                                warnings:(NSMutableArray<NSString *> *)warnings
                                                   error:(NSError **)error;

// Adds `lower` into `higher`, with `higher` winning where both set something.
+ (MWMConfigDocument *)documentByMerging:(MWMConfigDocument *)lower
                                      into:(MWMConfigDocument *)higher
                                 lowerName:(NSString *)lowerName
                                higherName:(NSString *)higherName
                                  warnings:(NSMutableArray<NSString *> *)warnings;

// Converts whichever of these exist into one document, merging them in the order the older generations
// loaded them (~/.slate, then ~/.slate.js, then ~/.slate.yml). Nothing on disk changes. A ~/.slate.js that
// can't be converted is left out and reported in `warnings`. nil when none exist or one can't be converted.
+ (nullable MWMConfigDocument *)documentByConvertingLegacyFile:(nullable NSString *)legacyPath
                                                 javaScriptFile:(nullable NSString *)jsPath
                                                    oldYAMLFile:(nullable NSString *)oldYAMLPath
                                                       warnings:(NSMutableArray<NSString *> *)warnings
                                                          error:(NSError **)error;

// First launch with the ~/.mwm folder (it doesn't exist yet): moves an existing ~/.mwm.yml to
// ~/.mwm/default.mwm.yaml, and converts any Slate files into a configuration ("default", or "slate-import"
// next to a moved ~/.mwm.yml). The Slate files are only read: never renamed, moved or loaded again.
// Answers nil when there's nothing to do; else a summary (moved, importedName, slateFiles, slateProblem,
// warnings, error) for the alert. Uses MWMProfiles' home folder.
+ (nullable NSDictionary *)importFirstRunProfiles;

// Startup entry point: the step above, then an alert saying what happened.
+ (void)runStartupMigration;

// Startup entry point, after the one above: rewrites an older-format active configuration in the
// current format (keeping the old file as a backup) and says so once.
+ (void)runFormatMigration;

@end

NS_ASSUME_NONNULL_END
