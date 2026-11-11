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
#import "ConfigurationFormView.h"
#import "ConfigurationStatusBar.h"
#import "SlateAppDelegate.h"
#import "SlateConfigDocument.h"
#import "SlateConfigValidator.h"
#import "SlateLegacyMigration.h"

typedef NS_ENUM(NSInteger, SaveState) {
  SaveStateSaved,       // the file on disk matches the form
  SaveStateNotCreated,  // ~/.mwm.yml doesn't exist and the defaults are untouched
  SaveStateBlocked,     // edited, but not saved because it has errors
  SaveStateUnreadable,  // the file on disk can't be shown as a form
};

@interface ConfigurationWindowController () <ConfigurationFormViewDelegate>
@property (strong) ConfigurationFormView *formView;
@property (strong) ConfigurationStatusBar *bar;
@property (strong) SlateConfigValidationResult *lastResult;
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
// Tests point the window at a temporary file instead of ~/.mwm.yml.
@property (copy, nullable) NSString *configPathOverride;
@end

@implementation ConfigurationWindowController

+ (instancetype)sharedController {
  static ConfigurationWindowController *shared;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ shared = [[self alloc] init]; });
  return shared;
}

- (instancetype)init {
  NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 980, 640)
                                                 styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                           NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                                   backing:NSBackingStoreBuffered
                                                     defer:YES];
  self = [super initWithWindow:window];
  if (self) {
    [window setTitle:@"MWM configuration"];
    [window setMinSize:NSMakeSize(640, 360)];
    [window setReleasedWhenClosed:NO];
    [window setDelegate:self];
    [window center];
    [window setFrameAutosaveName:@"MWMConfiguration"];
    [self buildInterface];
  }
  return self;
}

- (void)buildInterface {
  NSView *content = [[self window] contentView];
  self.formView = [[ConfigurationFormView alloc] initWithFrame:NSZeroRect];
  [self.formView setTranslatesAutoresizingMaskIntoConstraints:NO];
  [self.formView setDelegate:self];
  self.bar = [[ConfigurationStatusBar alloc] initWithTarget:self path:[[self configPath] stringByAbbreviatingWithTildeInPath]];
  [content addSubview:self.formView];
  [content addSubview:self.bar];
  [NSLayoutConstraint activateConstraints:@[
    [self.formView.topAnchor constraintEqualToAnchor:content.topAnchor],
    [self.formView.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
    [self.formView.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
    [self.formView.bottomAnchor constraintEqualToAnchor:self.bar.topAnchor],
    [self.bar.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
    [self.bar.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
    [self.bar.bottomAnchor constraintEqualToAnchor:content.bottomAnchor],
  ]];
}

#pragma mark - Showing and loading

- (void)showConfiguration {
  if (![[self window] isVisible]) [self loadFromDisk];
  [NSApp activateIgnoringOtherApps:YES];
  [self showWindow:self];
  [[self window] makeKeyAndOrderFront:self];
  [[self window] makeFirstResponder:self.formView.initialFirstResponder];
}

- (NSString *)configPath {
  return self.configPathOverride ?: [SlateConfigDocument defaultPath];
}

- (NSString *)displayPath {
  return [[self configPath] stringByAbbreviatingWithTildeInPath];
}

- (NSDate *)modificationDateOnDisk {
  NSString *target = [[self configPath] stringByResolvingSymlinksInPath];
  return [[NSFileManager defaultManager] attributesOfItemAtPath:target error:nil][NSFileModificationDate];
}

// The bundled defaults, as a document.
- (SlateConfigDocument *)defaultDocument {
  NSString *path = [[NSBundle mainBundle] pathForResource:@"default" ofType:@"slate"];
  NSString *legacy = path ? [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil] : nil;
  if (legacy == nil) return [[SlateConfigDocument alloc] init];
  return [SlateLegacyMigration documentFromLegacySource:legacy warnings:[NSMutableArray array]];
}

- (void)loadFromDisk {
  NSError *error = nil;
  NSString *text = [NSString stringWithContentsOfFile:[self configPath] encoding:NSUTF8StringEncoding error:&error];
  self.savedText = text;
  self.savedModificationDate = [self modificationDateOnDisk];
  self.backedUp = NO;

  SlateConfigDocument *document;
  if (text == nil) {
    BOOL missing = [error.domain isEqualToString:NSCocoaErrorDomain] && error.code == NSFileReadNoSuchFileError;
    if (!missing) {
      [self showUnreadable:[NSString stringWithFormat:@"%@ couldn't be read.\n\n%@", [self displayPath], [error localizedDescription]]];
      return;
    }
    document = [self defaultDocument];
  } else {
    // Lenient, so a file with an unknown alias still opens and shows the error.
    document = [SlateConfigDocument documentFromString:text lenient:YES error:&error];
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
  [self.bar setStatusText:@"Can't be read" symbol:@"xmark.octagon.fill" color:[NSColor systemRedColor] tip:nil];
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

- (void)formViewWantsReload:(ConfigurationFormView *)formView {
  [self loadFromDisk];
}

#pragma mark - Saving

// Checks the form's configuration and writes it when it has no errors.
- (void)validateAndSave {
  if (self.formView.document == nil) return;
  SlateConfigValidationResult *result = [self runValidation];
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
  if (![SlateConfigDocument writeString:text toFile:[self configPath] backup:!self.backedUp error:&error]) {
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

- (BOOL)changedOnDisk {
  NSDate *current = [self modificationDateOnDisk];
  if (current == nil && self.savedModificationDate == nil) return NO;
  return ![current isEqualToDate:self.savedModificationDate];
}

- (void)resolveConflict {
  if (self.resolvingConflict) return;
  self.resolvingConflict = YES;
  NSAlert *alert = [[NSAlert alloc] init];
  [alert setAlertStyle:NSAlertStyleWarning];
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

// ⌘S: commits a cell being edited, which saves it.
- (IBAction)saveDocument:(id)sender {
  [[self window] makeFirstResponder:nil];
  [self validateAndSave];
}

- (void)updateSaveState:(SaveState)state {
  self.saveState = state;
  NSString *text, *symbol;
  NSColor *color;
  switch (state) {
    case SaveStateSaved:
      text = @"Saved"; symbol = @"checkmark.circle.fill"; color = [NSColor secondaryLabelColor]; break;
    case SaveStateNotCreated:
      text = @"Not created yet"; symbol = @"doc.badge.plus"; color = [NSColor secondaryLabelColor]; break;
    case SaveStateBlocked:
      text = @"Not saved"; symbol = @"exclamationmark.circle.fill"; color = [NSColor systemRedColor]; break;
    case SaveStateUnreadable:
      text = @"Not loaded"; symbol = @"exclamationmark.circle.fill"; color = [NSColor systemRedColor]; break;
  }
  [self.bar setSavedText:text symbol:symbol color:color];
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

- (SlateConfigValidationResult *)runValidation {
  SlateConfigValidationResult *result = [SlateConfigValidator validateSource:[self currentText]];
  self.lastResult = result;
  NSString *counts = [NSString stringWithFormat:@"%@, %@", [self plural:result.bindingCount of:@"binding"],
                      [self plural:result.settingCount of:@"setting"]];
  if (result.errorCount > 0) {
    [self setStatus:[NSString stringWithFormat:@"%@ · %@", [self plural:result.errorCount of:@"error"], [self messageFor:result.issues[0]]]
             symbol:@"xmark.octagon.fill" color:[NSColor systemRedColor]];
  } else if (result.warningCount > 0) {
    [self setStatus:[NSString stringWithFormat:@"Valid · %@ · %@", counts, [self plural:result.warningCount of:@"warning"]]
             symbol:@"exclamationmark.triangle.fill" color:[NSColor systemOrangeColor]];
  } else {
    [self setStatus:[@"Valid · " stringByAppendingString:counts] symbol:@"checkmark.circle.fill" color:[NSColor systemGreenColor]];
  }
  return result;
}

// Issues found in the form's own text: its line numbers mean nothing here.
- (NSString *)messageFor:(SlateConfigIssue *)issue {
  NSString *message = issue.message;
  NSRegularExpression *linePrefix = [NSRegularExpression regularExpressionWithPattern:@"^Line [0-9]+: " options:0 error:nil];
  return [linePrefix stringByReplacingMatchesInString:message options:0 range:NSMakeRange(0, [message length]) withTemplate:@""];
}

- (IBAction)showIssues:(NSButton *)sender {
  NSArray *issues = self.lastResult.issues;
  if ([issues count] == 0) return;
  NSMenu *menu = [[NSMenu alloc] init];
  for (SlateConfigIssue *issue in issues) {
    NSMenuItem *item = [menu addItemWithTitle:[self messageFor:issue] action:@selector(revealIssue:) keyEquivalent:@""];
    [item setTarget:self];
    [item setRepresentedObject:issue];
    [item setImage:[ConfigurationStatusBar symbol:issue.isError ? @"xmark.octagon.fill" : @"exclamationmark.triangle.fill"
                                            color:issue.isError ? [NSColor systemRedColor] : [NSColor systemOrangeColor]]];
  }
  [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0, NSHeight([sender bounds]) + 4) inView:sender];
}

- (IBAction)revealIssue:(NSMenuItem *)sender {
  [self reveal:[sender representedObject]];
}

// Shows the binding or entry an issue is about.
- (void)reveal:(SlateConfigIssue *)issue {
  if (issue.bindingIndex != NSNotFound) {
    [self.formView revealBindingAtIndex:issue.bindingIndex];
  } else if (issue.entryName != nil) {
    [self.formView revealEntryNamed:issue.entryName];
  }
}

#pragma mark - Apply and close

- (void)showError:(NSString *)message detail:(NSString *)detail {
  NSAlert *alert = [[NSAlert alloc] init];
  [alert setAlertStyle:NSAlertStyleWarning];
  [alert setMessageText:message];
  [alert setInformativeText:detail ?: @""];
  [alert beginSheetModalForWindow:[self window] completionHandler:nil];
}

// Saves, closes the window, and restarts MWM so it loads ~/.mwm.yml.
- (IBAction)apply:(NSButton *)sender {
  [[self window] makeFirstResponder:nil];  // commit a cell being edited
  if (self.formView.document == nil) {
    [self showError:[NSString stringWithFormat:@"%@ can't be applied", [self displayPath]]
             detail:@"Fix the file in a text editor and choose Reload first."];
    return;
  }
  [self validateAndSave];
  if (self.lastResult.errorCount > 0) {
    SlateConfigIssue *first = self.lastResult.issues[0];
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setAlertStyle:NSAlertStyleWarning];
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
  [[self window] close];
  [(SlateAppDelegate *)[NSApp delegate] relaunch];
}

- (IBAction)closeWindow:(NSButton *)sender {
  [[self window] performClose:sender];
}

- (void)windowWillClose:(NSNotification *)notification {
  // Commits a cell being edited, which saves it if it's valid. Changes with
  // errors are dropped, and the next open reloads the file.
  [[self window] makeFirstResponder:nil];
}

@end
