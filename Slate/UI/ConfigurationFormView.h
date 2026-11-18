//
//  ConfigurationFormView.h
//  Slate
//
//  The Form view of the configuration window: a sidebar of sections and an
//  editable table for each. It edits a SlateConfigDocument in place and tells
//  its delegate after every change, so the window can rewrite the file text.
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

@class ConfigurationFormView;
@class SlateConfigDocument;

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, ConfigurationFormSection) {
  ConfigurationFormSectionGeneral,
  ConfigurationFormSectionModifiers,
  ConfigurationFormSectionMonitors,
  ConfigurationFormSectionPositions,
  ConfigurationFormSectionAliases,
  ConfigurationFormSectionApps,
  ConfigurationFormSectionLayout,
  ConfigurationFormSectionWindowActions,
  ConfigurationFormSectionFeatures,
  // Pages of the grouped navigation: every shortcut with a kind filter, the
  // settings that aren't everyday ones, and pages still to be built.
  ConfigurationFormSectionKeyboard,
  ConfigurationFormSectionAdvanced,
  ConfigurationFormSectionSnapshots,
  ConfigurationFormSectionBackup,
  ConfigurationFormSectionCount,
};

@protocol ConfigurationFormViewDelegate <NSObject>
// The document was edited; save it.
- (void)formViewDidChangeDocument:(ConfigurationFormView *)formView;
// The file can't be shown as a form: the user wants to fix it in a text editor,
- (void)formViewWantsTextEditor:(ConfigurationFormView *)formView;
// or to read it again after fixing it.
- (void)formViewWantsReload:(ConfigurationFormView *)formView;
@optional
// A page opened a sublevel (a slot being edited) or closed it. The window hides
// its bottom bar while one is open.
- (void)formView:(ConfigurationFormView *)formView didChangeSublevel:(BOOL)active;
- (void)formViewWantsFinder:(ConfigurationFormView *)formView;
// Launch at login isn't in the file, so the app answers for it.
- (BOOL)formViewLaunchesAtLogin:(ConfigurationFormView *)formView;
- (void)formView:(ConfigurationFormView *)formView setLaunchesAtLogin:(BOOL)launches;
@end

@interface ConfigurationFormView : NSView <NSTableViewDataSource, NSTableViewDelegate>

@property (weak, nullable) id<ConfigurationFormViewDelegate> delegate;

// Setting this shows the form for the document (and reloads every table).
@property (strong, nonatomic, nullable) SlateConfigDocument *document;

@property (assign, nonatomic) ConfigurationFormSection selectedSection;

// Keyboard page only: show one kind of shortcut (a SlateBindingCategory), or -1 for all.
@property (assign, nonatomic) NSInteger keyboardFilter;

// Shown instead of the form when the file can't be edited as a form.
- (void)showUnavailableMessage:(NSString *)message;

// YES while a page has a sublevel open (the header is replaced by its back button).
@property (readonly) BOOL sublevelActive;

// Shows and selects a binding (by index in the document) or a setting/alias (by name).
- (void)revealBindingAtIndex:(NSUInteger)index;
- (void)revealEntryNamed:(NSString *)name;

// Keyboard page: show the map or the list, and open the editor for a new shortcut (as the menu bar asks).
- (void)showKeyboardList:(BOOL)list;
- (void)beginNewShortcut;

// The sidebar, to focus when the form is shown.
@property (readonly) NSView *initialFirstResponder;

@end

NS_ASSUME_NONNULL_END
