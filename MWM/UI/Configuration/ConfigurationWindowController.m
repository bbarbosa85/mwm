//
//  ConfigurationWindowController.m
//  Slate
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

#import "ConfigurationWindowController.h"
#import "MWMProfiles.h"
#import "MWMAlert.h"
#import "MWMTheme.h"
#import "ConfigurationFormView.h"
#import "ConfigurationStatusBar.h"
#import "ConfigurationProfileBar.h"
#import "MWMAppDelegate.h"
#import "MWMConfigDocument.h"
#import "MWMConfigValidator.h"
#import "MWMLegacyMigration.h"
#import "MWMConfig.h"

typedef NS_ENUM(NSInteger, SaveState) {
  SaveStateSaved,       // the file on disk matches the form
  SaveStateNotCreated,  // ~/.mwm.yml doesn't exist and the defaults are untouched
  SaveStateBlocked,     // edited, but not saved because it has errors
  SaveStateUnreadable,  // the file on disk can't be shown as a form
};

@interface ConfigurationWindowController () <ConfigurationFormViewDelegate, ConfigurationProfileBarDelegate>
@property (strong) ConfigurationFormView *formView;
@property (assign) CGFloat liveResizeOriginX;   // where the window's left edge was when a resize began
@property (strong) ConfigurationProfileBar *profileBar;
// The profile the window edits when it isn't the running one (nil: the running one). It becomes the running
// profile only when Apply and Restart is pressed.
@property (copy, nullable) NSString *editingProfile;
// Tests stub this so applying doesn't restart the app.
@property (copy, nullable) void (^relaunchHandler)(void);
@property (strong) ConfigurationStatusBar *bar;
@property (strong) NSLayoutConstraint *formBottomAboveBar;
@property (strong) NSLayoutConstraint *formBottomAtWindow;
@property (strong) MWMConfigValidationResult *lastResult;
@property (assign) SaveState saveState;
// The file's text as read or last written (nil if there's no file).
@property (copy, nullable) NSString *savedText;
// The form's text as loaded or last saved; only changes from it get saved, so
// opening the window never rewrites a hand-edited file.
@property (copy) NSString *baselineText;
@property (strong, nullable) NSDate *savedModificationDate;
// The previous file goes to .bak once per editing session, not on every save.
@property (assign) BOOL backedUp;
@property (assign) BOOL resolvingConflict;
// Tests point the window at a temporary file instead of ~/.mwm.yml, and say what the running app "loaded".
@property (copy, nullable) NSString *configPathOverride;
@property (copy, nullable) NSString *appliedTextOverride;
@end

// The window is this wide, always; the pages are laid out for it.
static const CGFloat kWindowWidth = 1080;

@implementation ConfigurationWindowController

+ (instancetype)sharedController {
  static ConfigurationWindowController *shared;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ shared = [[self alloc] init]; });
  return shared;
}

- (instancetype)init {
  NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, kWindowWidth, 780)
                                                 styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                           NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                                   backing:NSBackingStoreBuffered
                                                     defer:YES];
  self = [super initWithWindow:window];
  if (self) {
    [window setTitle:@"MWM Settings"];
    // The window is always 1080 wide, and only its height changes.
    [window setContentMinSize:NSMakeSize(kWindowWidth, 520)];
    [window setContentMaxSize:NSMakeSize(kWindowWidth, CGFLOAT_MAX)];
    [window setReleasedWhenClosed:NO];
    [window setDelegate:self];
    [window center];
    // Tests run inside this app and use the same preferences: they must not save where their windows were.
    if (NSClassFromString(@"XCTestCase") == nil) [window setFrameAutosaveName:@"MWMConfiguration2"];
    [window setContentSize:NSMakeSize(kWindowWidth, NSHeight([[window contentView] frame]))];   // a width saved by an earlier version
    [self buildInterface];
  }
  return self;
}

// Dragging an edge or the zoom button changes the height only.
- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)frameSize {
  return NSMakeSize([sender frameRectForContentRect:NSMakeRect(0, 0, kWindowWidth, 0)].size.width, frameSize.height);
}

// The width is fixed, so a corner or edge drag must not slide the window sideways.
- (void)windowWillStartLiveResize:(NSNotification *)notification { self.liveResizeOriginX = NSMinX(self.window.frame); }

- (void)windowDidResize:(NSNotification *)notification {
  NSRect frame = self.window.frame;
  if (self.window.inLiveResize && fabs(NSMinX(frame) - self.liveResizeOriginX) > 0.5) {
    frame.origin.x = self.liveResizeOriginX;
    [self.window setFrame:frame display:YES];
  }
}

- (void)buildInterface {
  NSView *content = [[self window] contentView];
  self.formView = [[ConfigurationFormView alloc] initWithFrame:NSZeroRect];
  [self.formView setTranslatesAutoresizingMaskIntoConstraints:NO];
  [self.formView setDelegate:self];
  self.profileBar = [[ConfigurationProfileBar alloc] init];
  [self.profileBar setDelegate:self];
  self.bar = [[ConfigurationStatusBar alloc] initWithTarget:self path:[[self configPath] stringByAbbreviatingWithTildeInPath]];
  [self.bar installProfileView:self.profileBar];   // the profile button, at the left of the bottom bar
  [content addSubview:self.formView];
  [content addSubview:self.bar];
  // The window is as wide as every page is laid out for, whatever a page would fit in.
  NSLayoutConstraint *width = [content.widthAnchor constraintEqualToConstant:kWindowWidth];
  width.priority = NSLayoutPriorityRequired;
  width.active = YES;
  // The form ends at the bottom bar, or at the window's edge while a sublevel page hides the bar.
  self.formBottomAboveBar = [self.formView.bottomAnchor constraintEqualToAnchor:self.bar.topAnchor];
  self.formBottomAtWindow = [self.formView.bottomAnchor constraintEqualToAnchor:content.bottomAnchor];
  [NSLayoutConstraint activateConstraints:@[
    [self.formView.topAnchor constraintEqualToAnchor:content.topAnchor],
    [self.formView.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
    [self.formView.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
    self.formBottomAboveBar,
    [self.bar.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
    [self.bar.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
    [self.bar.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
  ]];
  [self refreshProfileBar];
}

#pragma mark - Showing and loading

// MWM lives in the menu bar with no Dock icon. While the configuration window is open it is a regular
// app (Dock icon, ⌘Tab, a menu bar), so clicking another app doesn't lose the window.
- (void)useRegularActivationPolicy:(BOOL)regular {
  if (NSClassFromString(@"XCTestCase") != nil) return;  // tests don't need a Dock icon
  [NSApp setActivationPolicy:regular ? NSApplicationActivationPolicyRegular : NSApplicationActivationPolicyAccessory];
}

- (void)showConfiguration {
  if (![[self window] isVisible]) { self.editingProfile = nil; [self loadFromDisk]; }
  [self useRegularActivationPolicy:YES];
  [NSApp activateIgnoringOtherApps:YES];
  [self showWindow:self];
  [[self window] makeKeyAndOrderFront:self];
  [[self window] makeFirstResponder:self.formView.initialFirstResponder];
}

- (void)showConfigurationSection:(ConfigurationFormSection)section {
  [self showConfiguration];
  self.formView.selectedSection = section;
}

- (void)showKeyboardList {
  [self showConfiguration];
  [self.formView showKeyboardList:YES];
}

- (void)showNewShortcut {
  [self showConfiguration];
  [self.formView beginNewShortcut];
}

// The profile the window shows: the running one unless another was chosen and not applied yet.
- (NSString *)profileBeingEdited {
  NSString *name = self.editingProfile;
  return name != nil && [MWMProfiles existsNamed:name] ? name : [MWMProfiles activeName];
}

- (BOOL)choiceIsPending {
  return [[self profileBeingEdited] caseInsensitiveCompare:[MWMProfiles activeName]] != NSOrderedSame;
}

- (void)refreshProfileBar {
  NSString *editing = [self profileBeingEdited];
  [self.profileBar setEditing:editing running:[MWMProfiles activeName]];
  [self.formView setEditingProfile:editing];
}

- (NSString *)configPath {
  return self.configPathOverride ?: [MWMProfiles pathForName:[self profileBeingEdited]];
}

- (NSString *)displayPath {
  return [[self configPath] stringByAbbreviatingWithTildeInPath];
}

- (NSDate *)modificationDateOnDisk {
  NSString *target = [[self configPath] stringByResolvingSymlinksInPath];
  return [[NSFileManager defaultManager] attributesOfItemAtPath:target error:nil][NSFileModificationDate];
}

// The bundled defaults, as a document.
- (MWMConfigDocument *)defaultDocument {
  NSString *path = [[NSBundle mainBundle] pathForResource:@"default" ofType:@"slate"];
  NSString *legacy = path ? [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil] : nil;
  if (legacy == nil) return [[MWMConfigDocument alloc] init];
  return [MWMLegacyMigration documentFromLegacySource:legacy warnings:[NSMutableArray array]];
}

- (void)loadFromDisk {
  [self.bar setPath:[self displayPath]];
  [self refreshProfileBar];
  NSError *error = nil;
  NSString *text = [NSString stringWithContentsOfFile:[self configPath] encoding:NSUTF8StringEncoding error:&error];
  self.savedText = text;
  self.savedModificationDate = [self modificationDateOnDisk];
  self.backedUp = NO;

  MWMConfigDocument *document;
  if (text == nil) {
    BOOL missing = [error.domain isEqualToString:NSCocoaErrorDomain] && error.code == NSFileReadNoSuchFileError;
    if (!missing) {
      [self showUnreadable:[NSString stringWithFormat:@"%@ couldn't be read.\n\n%@", [self displayPath], [error localizedDescription]]];
      return;
    }
    document = [self defaultDocument];
  } else {
    // Lenient, so a file with an unknown alias still opens and shows the error.
    document = [MWMConfigDocument documentFromString:text lenient:YES error:&error];
    if (document == nil) {
      [self showUnreadable:[NSString stringWithFormat:
        @"%@ can't be shown here until this is fixed:\n\n%@\n\nFix it in a text editor, then choose Reload.",
        [self displayPath], [error localizedDescription]]];
      return;
    }
  }
  [self.formView setDocument:document];
  self.baselineText = [document stringRepresentation];
  [self runValidation];
  [self updateSaveState:self.savedText ? SaveStateSaved : SaveStateNotCreated];
}

- (void)showUnreadable:(NSString *)message {
  [self.formView showUnavailableMessage:message];
  self.baselineText = @"";
  self.lastResult = nil;
  [self.bar setStatusText:@"Can't be read" symbol:@"xmark.octagon.fill" color:[MWMTheme danger] tip:nil];
  [self updateSaveState:SaveStateUnreadable];
}

- (NSString *)currentText {
  return [self.formView.document stringRepresentation] ?: @"";
}

#pragma mark - Form

- (void)formViewDidChangeDocument:(ConfigurationFormView *)formView {
  [self validateAndSave];
}

- (void)formViewWantsTextEditor:(ConfigurationFormView *)formView {
  NSURL *file = [NSURL fileURLWithPath:[self configPath]];
  NSURL *textEdit = [[NSWorkspace sharedWorkspace] URLForApplicationWithBundleIdentifier:@"com.apple.TextEdit"];
  if (textEdit == nil) {
    [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[file]];
    return;
  }
  [[NSWorkspace sharedWorkspace] openURLs:@[file]
                     withApplicationAtURL:textEdit
                            configuration:[NSWorkspaceOpenConfiguration configuration]
                        completionHandler:nil];
}

// A sublevel page (editing a slot) has its own Save and Cancel, so the saved/apply/close bar steps aside.
- (void)formView:(ConfigurationFormView *)formView didChangeSublevel:(BOOL)active {
  [self.bar setHidden:active];
  if (active) { self.formBottomAboveBar.active = NO; self.formBottomAtWindow.active = YES; }
  else { self.formBottomAtWindow.active = NO; self.formBottomAboveBar.active = YES; }
}

- (void)formViewWantsFinder:(ConfigurationFormView *)formView {
  [[NSWorkspace sharedWorkspace] activateFileViewerSelectingURLs:@[[NSURL fileURLWithPath:[self configPath]]]];
}

- (BOOL)formViewLaunchesAtLogin:(ConfigurationFormView *)formView {
  return [(MWMAppDelegate *)[NSApp delegate] isInLoginItems];
}

- (void)formView:(ConfigurationFormView *)formView setLaunchesAtLogin:(BOOL)launches {
  MWMAppDelegate *delegate = (MWMAppDelegate *)[NSApp delegate];
  if (launches) [delegate addToLoginItems]; else [delegate deleteFromLoginItems];
  [delegate setLaunchOnLoginItemStatus];  // keeps the menu item in step
}

- (void)formViewWantsReload:(ConfigurationFormView *)formView {
  [self loadFromDisk];
}

#pragma mark - Saving

// Checks the form's configuration and writes it when it has no errors.
- (void)validateAndSave {
  if (self.formView.document == nil) return;
  MWMConfigValidationResult *result = [self runValidation];
  NSString *text = [self currentText];
  if ([text isEqualToString:self.baselineText]) {
    // Back to what was loaded: nothing to save (and a missing file stays missing).
    [self updateSaveState:self.savedText ? SaveStateSaved : SaveStateNotCreated];
    return;
  }
  if (result.errorCount > 0) {
    [self updateSaveState:SaveStateBlocked];
    return;
  }
  if ([self changedOnDisk]) {
    [self resolveConflict];
    return;
  }
  [self writeText:text];
}

- (BOOL)writeText:(NSString *)text {
  NSError *error = nil;
  if (![MWMConfigDocument writeString:text toFile:[self configPath] backup:!self.backedUp error:&error]) {
    [self updateSaveState:SaveStateBlocked];
    [self showError:[NSString stringWithFormat:@"Couldn't save %@", [self displayPath]] detail:[error localizedDescription]];
    return NO;
  }
  self.backedUp = YES;
  self.savedText = text;
  self.baselineText = text;
  self.savedModificationDate = [self modificationDateOnDisk];
  [self updateSaveState:SaveStateSaved];
  return YES;
}

#pragma mark - Choosing a profile

// Choosing a profile (the bar's dropdown, the Profiles page, the menu bar) only changes what the window edits:
// MWM switches to it when Apply and Restart is pressed.
- (void)formView:(ConfigurationFormView *)formView useProfileNamed:(NSString *)name { [self selectProfileNamed:name]; }
- (void)profileBar:(ConfigurationProfileBar *)bar didChooseProfileNamed:(NSString *)name { [self selectProfileNamed:name]; }
- (void)profileBarWantsManage:(ConfigurationProfileBar *)bar { self.formView.selectedSection = ConfigurationFormSectionProfiles; }

- (void)selectProfileNamed:(NSString *)name {
  if ([name caseInsensitiveCompare:[self profileBeingEdited]] == NSOrderedSame) return;
  [[self window] makeFirstResponder:nil];
  if (self.formView.document != nil) {
    [self validateAndSave];
    if (self.lastResult.errorCount > 0 || self.resolvingConflict) {
      MWMAlert *alert = [MWMAlert alert];
      [alert setKind:MWMAlertKindWarning];
      [alert setMessageText:@"Fix the errors before changing profile"];
      [alert setInformativeText:[NSString stringWithFormat:@"%@ has errors, which aren't saved. Fix them, or change profile after you've saved a version that works.", [self displayPath]]];
      [alert addButtonWithTitle:@"OK"];
      [alert beginSheetModalForWindow:[self window] completionHandler:nil];
      return;
    }
  }
  self.editingProfile = [name caseInsensitiveCompare:[MWMProfiles activeName]] == NSOrderedSame ? nil : name;
  [self loadFromDisk];
}

- (void)showSettingsOnProfileNamed:(NSString *)name {
  [self showConfiguration];
  [self selectProfileNamed:name];
}

// A profile was renamed: follow it if it's the one open.
- (void)formView:(ConfigurationFormView *)formView didRenameProfileNamed:(NSString *)name to:(NSString *)newName {
  if (self.editingProfile != nil && [self.editingProfile caseInsensitiveCompare:name] == NSOrderedSame) self.editingProfile = newName;
  [self loadFromDisk];
}

// A sync received files or cleared some: show the open configuration again from disk.
- (void)formViewDidChangeFilesBySync:(ConfigurationFormView *)formView { [self reloadAfterSync]; }
- (void)reloadAfterSync { [self loadFromDisk]; }

- (BOOL)changedOnDisk {
  NSDate *current = [self modificationDateOnDisk];
  if (current == nil && self.savedModificationDate == nil) return NO;
  return ![current isEqualToDate:self.savedModificationDate];
}

- (void)resolveConflict {
  if (self.resolvingConflict) return;
  self.resolvingConflict = YES;
  MWMAlert *alert = [MWMAlert alert];
  [alert setKind:MWMAlertKindWarning];
  [alert setMessageText:[NSString stringWithFormat:@"%@ changed on disk", [self displayPath]]];
  [alert setInformativeText:@"Another app changed the file while it was open here. Keep the changes made here and replace the file, or load the version on disk."];
  [alert addButtonWithTitle:@"Load from disk"];
  [alert addButtonWithTitle:@"Replace"];
  [alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse response) {
    self.resolvingConflict = NO;
    if (response == NSAlertFirstButtonReturn) {
      [self loadFromDisk];
    } else {
      [self writeText:[self currentText]];
    }
  }];
}

// Picks up edits made in a text editor while the window was in the background.
- (void)windowDidBecomeKey:(NSNotification *)notification {
  if (self.resolvingConflict || ![self changedOnDisk]) return;
  if (self.saveState == SaveStateBlocked) {
    [self resolveConflict];
  } else {
    [self loadFromDisk];
  }
}

// What the running MWM loaded at launch. Saved text that differs from it hasn't been applied yet.
- (NSString *)appliedText {
  if (self.configPathOverride != nil) return self.appliedTextOverride;
  return [MWMConfig getInstance].loadedConfigText;
}

// The Save button and ⌘S: commits a cell being edited and writes the file without restarting MWM.
// If there is no file yet, it creates it from the form.
- (IBAction)saveDocument:(id)sender {
  [[self window] makeFirstResponder:nil];
  if (self.formView.document == nil) return;
  [self validateAndSave];
  if (self.lastResult.errorCount > 0 || self.resolvingConflict) return;
  if (self.savedText == nil) [self writeText:[self currentText]];
}

- (void)updateSaveState:(SaveState)state {
  self.saveState = state;
  NSString *text, *symbol;
  NSColor *color;
  switch (state) {
    case SaveStateSaved:
      if (self.savedText != nil && ![self.savedText isEqualToString:[self appliedText] ?: @""] ) {
        text = @"Saved · not applied yet"; symbol = @"arrow.clockwise.circle.fill"; color = [MWMTheme warning];
      } else {
        text = @"Saved"; symbol = @"checkmark.circle.fill"; color = [MWMTheme textSecondary];
      }
      break;
    case SaveStateNotCreated:
      text = @"Not created yet"; symbol = @"doc.badge.plus"; color = [MWMTheme textSecondary]; break;
    case SaveStateBlocked:
      text = @"Not saved"; symbol = @"exclamationmark.circle.fill"; color = [MWMTheme danger]; break;
    case SaveStateUnreadable:
      text = @"Not loaded"; symbol = @"exclamationmark.circle.fill"; color = [MWMTheme danger]; break;
  }
  [self.bar setSavedText:text symbol:symbol color:color];
  [self.bar setSaved:state == SaveStateSaved enabled:state != SaveStateSaved && state != SaveStateUnreadable];
  [[self window] setDocumentEdited:state == SaveStateBlocked];
}

#pragma mark - Validation

- (NSString *)plural:(NSUInteger)count of:(NSString *)noun {
  return [NSString stringWithFormat:@"%lu %@%@", (unsigned long)count, noun, count == 1 ? @"" : @"s"];
}

- (void)setStatus:(NSString *)text symbol:(NSString *)symbol color:(NSColor *)color {
  NSUInteger count = [self.lastResult.issues count];
  NSString *title = count > 0 ? [text stringByAppendingString:@"  ▾"] : text;
  NSString *tip = count > 0 ? [NSString stringWithFormat:@"Show %@", [self plural:count of:@"issue"]] : nil;
  [self.bar setStatusText:title symbol:symbol color:color tip:tip];
}

- (MWMConfigValidationResult *)runValidation {
  MWMConfigValidationResult *result = [MWMConfigValidator validateSource:[self currentText]];
  self.lastResult = result;
  NSString *counts = [NSString stringWithFormat:@"%@, %@", [self plural:result.bindingCount of:@"binding"],
                      [self plural:result.settingCount of:@"setting"]];
  if (result.errorCount > 0) {
    [self setStatus:[NSString stringWithFormat:@"%@ · %@", [self plural:result.errorCount of:@"error"], [self messageFor:result.issues[0]]]
             symbol:@"xmark.octagon.fill" color:[MWMTheme danger]];
  } else if (result.warningCount > 0) {
    [self setStatus:[NSString stringWithFormat:@"Valid · %@ · %@", counts, [self plural:result.warningCount of:@"warning"]]
             symbol:@"exclamationmark.triangle.fill" color:[MWMTheme warning]];
  } else {
    [self setStatus:[@"Valid · " stringByAppendingString:counts] symbol:@"checkmark.circle.fill" color:[MWMTheme success]];
  }
  return result;
}

// Issues found in the form's own text: its line numbers mean nothing here.
- (NSString *)messageFor:(MWMConfigIssue *)issue {
  NSString *message = issue.message;
  NSRegularExpression *linePrefix = [NSRegularExpression regularExpressionWithPattern:@"^Line [0-9]+: " options:0 error:nil];
  return [linePrefix stringByReplacingMatchesInString:message options:0 range:NSMakeRange(0, [message length]) withTemplate:@""];
}

- (IBAction)showIssues:(NSButton *)sender {
  NSArray *issues = self.lastResult.issues;
  if ([issues count] == 0) return;
  NSMenu *menu = [[NSMenu alloc] init];
  for (MWMConfigIssue *issue in issues) {
    NSMenuItem *item = [menu addItemWithTitle:[self messageFor:issue] action:@selector(revealIssue:) keyEquivalent:@""];
    [item setTarget:self];
    [item setRepresentedObject:issue];
    [item setImage:[ConfigurationStatusBar symbol:issue.isError ? @"xmark.octagon.fill" : @"exclamationmark.triangle.fill"
                                            color:issue.isError ? [MWMTheme danger] : [MWMTheme warning]]];
  }
  [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0, NSHeight([sender bounds]) + 4) inView:sender];
}

- (IBAction)revealIssue:(NSMenuItem *)sender {
  [self reveal:[sender representedObject]];
}

// Shows the binding or entry an issue is about.
- (void)reveal:(MWMConfigIssue *)issue {
  if (issue.bindingIndex != NSNotFound) {
    [self.formView revealBindingAtIndex:issue.bindingIndex];
  } else if (issue.entryName != nil) {
    [self.formView revealEntryNamed:issue.entryName];
  }
}

#pragma mark - Apply and close

- (void)showError:(NSString *)message detail:(NSString *)detail {
  MWMAlert *alert = [MWMAlert alert];
  [alert setKind:MWMAlertKindWarning];
  [alert setMessageText:message];
  [alert setInformativeText:detail ?: @""];
  [alert beginSheetModalForWindow:[self window] completionHandler:nil];
}

// Saves, makes the profile being edited the running one, closes the window, and restarts MWM so it loads it.
- (IBAction)apply:(NSButton *)sender {
  [[self window] makeFirstResponder:nil];  // commit a cell being edited
  if (self.formView.document == nil) {
    [self showError:[NSString stringWithFormat:@"%@ can't be applied", [self displayPath]]
             detail:@"Fix the file in a text editor and choose Reload first."];
    return;
  }
  [self validateAndSave];
  if (self.lastResult.errorCount > 0) {
    MWMConfigIssue *first = self.lastResult.issues[0];
    MWMAlert *alert = [MWMAlert alert];
    [alert setKind:MWMAlertKindWarning];
    [alert setMessageText:@"Fix the errors before applying"];
    [alert setInformativeText:[NSString stringWithFormat:@"%@\n\nChanges with errors aren't saved, so MWM would restart with the last valid version.",
                               [self messageFor:first]]];
    [alert addButtonWithTitle:@"Show error"];
    [alert addButtonWithTitle:@"Cancel"];
    [alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse response) {
      if (response == NSAlertFirstButtonReturn) [self reveal:first];
    }];
    return;
  }
  if (self.resolvingConflict) return;
  // Applying the untouched defaults creates ~/.mwm.yml from them.
  if (self.savedText == nil && ![self writeText:[self currentText]]) return;
  if (![[self currentText] isEqualToString:self.baselineText]) return;
  if ([self choiceIsPending]) [MWMProfiles setActiveName:[self profileBeingEdited]];
  self.editingProfile = nil;
  [self refreshProfileBar];
  [[self window] close];
  if (self.relaunchHandler != nil) self.relaunchHandler(); else [(MWMAppDelegate *)[NSApp delegate] relaunch];
}

- (IBAction)closeWindow:(NSButton *)sender {
  [[self window] performClose:sender];
}

// A profile was chosen and not applied: ask what to do before the window goes.
- (BOOL)windowShouldClose:(NSWindow *)sender {
  if (![self choiceIsPending] || [[self window] attachedSheet] != nil) return YES;
  NSString *name = [self profileBeingEdited];
  MWMAlert *alert = [MWMAlert alert];
  [alert setKind:MWMAlertKindConfirm];
  [alert setMessageText:[NSString stringWithFormat:@"Use “%@” now?", name]];
  [alert setInformativeText:[NSString stringWithFormat:@"MWM is running “%@”. Apply and Restart makes “%@” the profile MWM uses. Your changes to it are already saved.", [MWMProfiles activeName], name]];
  [alert addButtonWithTitle:@"Apply and Restart"];
  [alert addButtonWithTitle:@"Discard choice"];
  [alert addButtonWithTitle:@"Cancel"];
  [alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse response) {
    if (response == NSAlertFirstButtonReturn) {
      [self apply:nil];
    } else if (response == NSAlertSecondButtonReturn) {
      self.editingProfile = nil;
      [self refreshProfileBar];
      [[self window] close];
    }
  }];
  return NO;
}

- (void)windowWillClose:(NSNotification *)notification {
  [self useRegularActivationPolicy:NO];
  // Commits a cell being edited, which saves it if it's valid. Changes with
  // errors are dropped, and the next open reloads the file.
  [[self window] makeFirstResponder:nil];
}

@end
