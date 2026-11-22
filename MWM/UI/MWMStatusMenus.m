//
//  MWMStatusMenus.m
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

#import "MWMStatusMenus.h"
#import "ConfigurationFormView.h"
#import "ConfigurationWindowController.h"
#import "NSAlert+MWM.h"
#import "MWMSnapshots.h"

@interface MWMStatusMenus ()
@property (strong) NSMenu *snapshots;
@end

@implementation MWMStatusMenus

+ (instancetype)shared {
  static MWMStatusMenus *shared;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ shared = [[MWMStatusMenus alloc] init]; });
  return shared;
}

- (NSMenuItem *)item:(NSString *)title action:(SEL)action in:(NSMenu *)menu {
  NSMenuItem *item = [menu addItemWithTitle:title action:action keyEquivalent:@""];
  [item setTarget:self];
  return item;
}

#pragma mark - Snapshots

- (NSMenu *)snapshotsMenu {
  if (self.snapshots == nil) {
    self.snapshots = [[NSMenu alloc] initWithTitle:@"Snapshots"];
    [self.snapshots setDelegate:self];
    [self fillSnapshotsMenu:self.snapshots];
  }
  return self.snapshots;
}

- (void)menuNeedsUpdate:(NSMenu *)menu {
  if (menu == self.snapshots) [self fillSnapshotsMenu:menu];
}

- (void)fillSnapshotsMenu:(NSMenu *)menu {
  [menu removeAllItems];
  [[self item:@"Save Current Windows…" action:@selector(savePressed:) in:menu] setToolTip:@"Remember where every open window is"];
  [menu addItem:[NSMenuItem separatorItem]];
  NSArray<MWMSnapshotInfo *> *snapshots = [MWMSnapshots snapshots];
  for (MWMSnapshotInfo *info in snapshots) {
    NSMenuItem *entry = [menu addItemWithTitle:info.name action:nil keyEquivalent:@""];
    [entry setImage:[NSImage imageWithSystemSymbolName:info.keepAfterRestart ? @"pin.fill" : @"camera" accessibilityDescription:nil]];
    [entry setSubmenu:[self menuForSnapshotNamed:info.name keep:info.keepAfterRestart]];
  }
  if ([snapshots count] == 0) {
    NSMenuItem *none = [menu addItemWithTitle:@"No snapshots yet" action:nil keyEquivalent:@""];
    [none setEnabled:NO];
  }
  [menu addItem:[NSMenuItem separatorItem]];
  [self item:@"Manage Snapshots…" action:@selector(manageSnapshots:) in:menu];
}

- (NSMenu *)menuForSnapshotNamed:(NSString *)name keep:(BOOL)keep {
  NSMenu *menu = [[NSMenu alloc] initWithTitle:name];
  NSMenuItem *restore = [self item:@"Restore" action:@selector(restoreChosen:) in:menu];
  NSMenuItem *update = [self item:@"Update with Current Windows" action:@selector(updateChosen:) in:menu];
  [menu addItem:[NSMenuItem separatorItem]];
  NSMenuItem *kept = [self item:@"Keep after Restart" action:@selector(keepChosen:) in:menu];
  [kept setState:keep ? NSControlStateValueOn : NSControlStateValueOff];
  [menu addItem:[NSMenuItem separatorItem]];
  NSMenuItem *delete = [self item:@"Delete…" action:@selector(deleteChosen:) in:menu];
  for (NSMenuItem *item in @[restore, update, kept, delete]) [item setRepresentedObject:name];
  return menu;
}

- (BOOL)validateMenuItem:(NSMenuItem *)item { return YES; }

- (void)saveSnapshotNamed:(NSString *)name keep:(BOOL)keep {
  [MWMSnapshots saveCurrentWindowsAs:name keepAfterRestart:keep];
}

// A name and whether to keep it; a message when the name can't be used.
- (void)savePressed:(id)sender {
  NSAlert *alert = [NSAlert mwm_alert];
  [alert setMessageText:@"Save current windows"];
  [alert setInformativeText:@"A snapshot remembers where every open window is, so you can put them all back later."];
  NSTextField *field = [NSTextField textFieldWithString:@""];
  NSArray *taken = [[MWMSnapshots snapshots] valueForKey:@"name"];
  NSString *suggested = @"snapshot1";
  for (NSUInteger i = 2; [taken containsObject:suggested]; i++) suggested = [NSString stringWithFormat:@"snapshot%lu", (unsigned long)i];
  [field setStringValue:suggested];
  [field setFrame:NSMakeRect(0, 0, 240, 24)];
  [alert setAccessoryView:field];
  [alert mwm_widen];
  [alert addButtonWithTitle:@"Save"];
  [alert addButtonWithTitle:@"Cancel"];
  [NSApp activateIgnoringOtherApps:YES];
  [[alert window] setInitialFirstResponder:field];
  if ([alert runModal] != NSAlertFirstButtonReturn) return;
  NSString *name = [[field stringValue] stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  NSString *problem = [MWMSnapshots problemWithName:name except:nil];
  if (problem != nil) {
    NSAlert *failed = [NSAlert mwm_alert];
    [failed setMessageText:problem];
    [failed runModal];
    return;
  }
  [self saveSnapshotNamed:name keep:YES];
}

- (void)restoreChosen:(NSMenuItem *)item { [MWMSnapshots restoreName:item.representedObject]; }
- (void)updateChosen:(NSMenuItem *)item { [MWMSnapshots updateName:item.representedObject]; }
- (void)keepChosen:(NSMenuItem *)item { [MWMSnapshots setKeepAfterRestart:[item state] != NSControlStateValueOn forName:item.representedObject]; }

- (void)deleteChosen:(NSMenuItem *)item {
  NSString *name = item.representedObject;
  NSAlert *alert = [NSAlert mwm_alert];
  [alert setMessageText:[NSString stringWithFormat:@"Delete \"%@\"?", name]];
  [alert setInformativeText:@"The saved window arrangement is removed. A shortcut that restores it will do nothing."];
  [alert addButtonWithTitle:@"Cancel"];
  [alert addButtonWithTitle:@"Delete"];
  [NSApp activateIgnoringOtherApps:YES];
  if ([alert runModal] == NSAlertFirstButtonReturn) return;
  [MWMSnapshots deleteName:name];
}

- (void)manageSnapshots:(id)sender { [[ConfigurationWindowController sharedController] showConfigurationSection:ConfigurationFormSectionSnapshots]; }

#pragma mark - Keyboard shortcuts

- (NSMenu *)keyboardMenu {
  NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Keyboard Shortcuts"];
  [self item:@"Keyboard Map" action:@selector(openMap:) in:menu];
  [self item:@"List of Shortcuts" action:@selector(openList:) in:menu];
  [menu addItem:[NSMenuItem separatorItem]];
  [self item:@"New Shortcut…" action:@selector(newShortcut:) in:menu];
  [self item:@"Modifier Groups" action:@selector(openModifiers:) in:menu];
  return menu;
}

- (void)openMap:(id)sender { [[ConfigurationWindowController sharedController] showConfigurationSection:ConfigurationFormSectionKeyboard]; [[ConfigurationWindowController sharedController].formView showKeyboardList:NO]; }
- (void)openList:(id)sender { [[ConfigurationWindowController sharedController] showKeyboardList]; }
- (void)newShortcut:(id)sender { [[ConfigurationWindowController sharedController] showNewShortcut]; }
- (void)openModifiers:(id)sender { [[ConfigurationWindowController sharedController] showConfigurationSection:ConfigurationFormSectionModifiers]; }

#pragma mark - Pages

- (NSMenu *)pagesMenu {
  NSMenu *menu = [[NSMenu alloc] initWithTitle:@"Open Page"];
  NSArray *groups = @[@[@[@"Keyboard", @(ConfigurationFormSectionKeyboard)], @[@"Modifiers", @(ConfigurationFormSectionModifiers)]],
                      @[@[@"Displays", @(ConfigurationFormSectionMonitors)], @[@"Slots", @(ConfigurationFormSectionPositions)], @[@"Snapshots", @(ConfigurationFormSectionSnapshots)]],
                      @[@[@"General", @(ConfigurationFormSectionGeneral)], @[@"Advanced", @(ConfigurationFormSectionAdvanced)], @[@"Other Aliases", @(ConfigurationFormSectionAliases)]]];
  for (NSUInteger i = 0; i < [groups count]; i++) {
    if (i > 0) [menu addItem:[NSMenuItem separatorItem]];
    for (NSArray *page in groups[i]) {
      NSMenuItem *item = [self item:page[0] action:@selector(openPage:) in:menu];
      [item setRepresentedObject:page[1]];
    }
  }
  return menu;
}

- (void)openPage:(NSMenuItem *)item {
  [[ConfigurationWindowController sharedController] showConfigurationSection:(ConfigurationFormSection)[item.representedObject integerValue]];
}

@end
