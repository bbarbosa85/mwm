//
//  ConfigurationSettingsView.h
//  Slate
//
//  The General and Advanced settings pages: one full-width row per topic
//  (startup, windows, window hints, key repeat, ...) with switches, pickers and
//  sliders instead of a table.
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

@class ConfigurationSettingsView, MWMConfigDocument;

typedef NS_ENUM(NSInteger, ConfigurationSettingsPage) {
  ConfigurationSettingsPageGeneral,   // the everyday settings
  ConfigurationSettingsPageAdvanced,  // key repeat, percentages, and every other setting
};

NS_ASSUME_NONNULL_BEGIN

@protocol ConfigurationSettingsViewDelegate <NSObject>
// A setting in the document was changed; save it.
- (void)settingsViewDidChangeDocument:(ConfigurationSettingsView *)view;
- (void)settingsViewWantsTextEditor:(ConfigurationSettingsView *)view;
- (void)settingsViewWantsFinder:(ConfigurationSettingsView *)view;
// Launch at login isn't a setting in the file, so the app answers for it.
- (BOOL)settingsViewLaunchesAtLogin:(ConfigurationSettingsView *)view;
- (void)settingsView:(ConfigurationSettingsView *)view setLaunchesAtLogin:(BOOL)launches;
@end

@interface ConfigurationSettingsView : NSView

@property (weak, nullable) id<ConfigurationSettingsViewDelegate> delegate;
// Showing a document builds the rows from its settings.
@property (strong, nonatomic, nullable) MWMConfigDocument *document;
@property (assign, nonatomic) ConfigurationSettingsPage page;

- (void)reload;

@end

NS_ASSUME_NONNULL_END
