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
#import "LineNumberGutterView.h"
#import "SlateAppDelegate.h"
#import "SlateConfigDocument.h"
#import "SlateConfigValidator.h"
#import "SlateLegacyMigration.h"

static const NSTimeInterval kValidateDelay = 0.8;
static const CGFloat kBarHeight = 44;
// Set just before Save relaunches Slate, so the new process reopens the window where it was.
static NSString *const kReopenDefaultsKey = @"SlateConfigurationReopenState";

@interface ConfigurationWindowController ()
@property (strong) NSTextView *textView;
@property (strong) LineNumberGutterView *gutter;
@property (strong) NSImageView *savedIcon;
@property (strong) NSTextField *savedLabel;
@property (strong) NSTextField *pathLabel;
@property (strong) NSButton *statusButton;
@property (strong) NSArray<SlateConfigIssue *> *issues;
@property (strong) NSDate *loadedModificationDate;
@property (assign) BOOL fileExisted;
@property (assign) BOOL dirty;
@property (assign) BOOL loading;
@end

@implementation ConfigurationWindowController

+ (instancetype)sharedController {
  static ConfigurationWindowController *shared;
  static dispatch_once_t once;
  dispatch_once(&once, ^{ shared = [[self alloc] init]; });
  return shared;
}

- (instancetype)init {
  NSWindow *window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 900, 640)
                                                 styleMask:NSWindowStyleMaskTitled | NSWindowStyleMaskClosable |
                                                           NSWindowStyleMaskMiniaturizable | NSWindowStyleMaskResizable
                                                   backing:NSBackingStoreBuffered
                                                     defer:YES];
  self = [super initWithWindow:window];
  if (self) {
    [window setTitle:@"Slate configuration"];
    [window setMinSize:NSMakeSize(620, 360)];
    [window setReleasedWhenClosed:NO];
    [window setDelegate:self];
    [window center];
    [window setFrameAutosaveName:@"SlateConfiguration"];
    self.issues = @[];
    [self buildInterface];
  }
  return self;
}

#pragma mark - Interface

- (NSImage *)symbol:(NSString *)name color:(NSColor *)color {
  NSImage *image = [NSImage imageWithSystemSymbolName:name accessibilityDescription:nil];
  return [image imageWithSymbolConfiguration:[NSImageSymbolConfiguration configurationWithHierarchicalColor:color]];
}

- (NSTextField *)barLabel {
  NSTextField *label = [NSTextField labelWithString:@""];
  [label setTranslatesAutoresizingMaskIntoConstraints:NO];
  [label setLineBreakMode:NSLineBreakByTruncatingMiddle];
  return label;
}

- (void)buildInterface {
  NSView *content = [[self window] contentView];

  NSScrollView *scroll = [[NSScrollView alloc] init];
  [scroll setTranslatesAutoresizingMaskIntoConstraints:NO];
  [scroll setHasVerticalScroller:YES];
  [scroll setHasHorizontalScroller:YES];
  [scroll setAutohidesScrollers:YES];
  [scroll setBorderType:NSNoBorder];

  NSTextView *textView = [[NSTextView alloc] initWithFrame:NSMakeRect(0, 0, 900, 560)];
  [textView setMinSize:NSMakeSize(0, 0)];
  [textView setMaxSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)];
  [textView setVerticallyResizable:YES];
  [textView setHorizontallyResizable:YES];
  [textView setAutoresizingMask:NSViewWidthSizable];
  [[textView textContainer] setContainerSize:NSMakeSize(CGFLOAT_MAX, CGFLOAT_MAX)];
  [[textView textContainer] setWidthTracksTextView:NO];
  [textView setRichText:NO];
  [textView setImportsGraphics:NO];
  [textView setAllowsUndo:YES];
  [textView setUsesFindBar:YES];
  [textView setIncrementalSearchingEnabled:YES];
  [textView setAutomaticQuoteSubstitutionEnabled:NO];
  [textView setAutomaticDashSubstitutionEnabled:NO];
  [textView setAutomaticTextReplacementEnabled:NO];
  [textView setAutomaticSpellingCorrectionEnabled:NO];
  [textView setAutomaticLinkDetectionEnabled:NO];
  [textView setContinuousSpellCheckingEnabled:NO];
  [textView setGrammarCheckingEnabled:NO];
  [textView setSmartInsertDeleteEnabled:NO];
  [textView setFont:[self editorFont]];
  [textView setTypingAttributes:@{NSFontAttributeName: [self editorFont], NSForegroundColorAttributeName: [NSColor textColor]}];
  [textView setTextContainerInset:NSMakeSize(4, 8)];
  [textView setDelegate:self];
  [[textView textStorage] setDelegate:self];
  [scroll setDocumentView:textView];
  self.textView = textView;
  self.gutter = [[LineNumberGutterView alloc] initWithTextView:textView];

  NSBox *separator = [[NSBox alloc] init];
  [separator setBoxType:NSBoxSeparator];
  [separator setTranslatesAutoresizingMaskIntoConstraints:NO];

  // Bottom bar: {saved?} {filename} ... {valid?} ... {Save} {Close}
  self.savedIcon = [[NSImageView alloc] init];
  [self.savedIcon setTranslatesAutoresizingMaskIntoConstraints:NO];
  self.savedLabel = [self barLabel];
  self.pathLabel = [self barLabel];
  [self.pathLabel setStringValue:[[SlateConfigDocument defaultPath] stringByAbbreviatingWithTildeInPath]];
  [self.pathLabel setTextColor:[NSColor secondaryLabelColor]];

  self.statusButton = [NSButton buttonWithTitle:@"" target:self action:@selector(showIssues:)];
  [self.statusButton setTranslatesAutoresizingMaskIntoConstraints:NO];
  [self.statusButton setBordered:NO];
  [self.statusButton setImagePosition:NSImageLeading];
  [self.statusButton setImageHugsTitle:YES];
  [[self.statusButton cell] setLineBreakMode:NSLineBreakByTruncatingTail];
  [self.statusButton setContentCompressionResistancePriority:NSLayoutPriorityDefaultLow forOrientation:NSLayoutConstraintOrientationHorizontal];

  NSButton *save = [NSButton buttonWithTitle:@"Save" target:self action:@selector(save:)];
  [save setTranslatesAutoresizingMaskIntoConstraints:NO];
  [save setKeyEquivalent:@"s"];
  [save setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
  [save setBezelColor:[NSColor controlAccentColor]];
  [save setToolTip:@"Save ~/.slate.js and apply it (⌘S)"];
  NSButton *close = [NSButton buttonWithTitle:@"Close" target:self action:@selector(closeConfiguration:)];
  [close setTranslatesAutoresizingMaskIntoConstraints:NO];
  [close setKeyEquivalent:@"w"];
  [close setKeyEquivalentModifierMask:NSEventModifierFlagCommand];
  [close setToolTip:@"Close and discard unsaved changes (⌘W)"];

  for (NSView *view in @[self.gutter, scroll, separator, self.savedIcon, self.savedLabel, self.pathLabel, self.statusButton, save, close]) {
    [content addSubview:view];
  }

  NSLayoutYAxisAnchor *barCenter = self.savedIcon.centerYAnchor;
  NSLayoutConstraint *centered = [self.statusButton.centerXAnchor constraintEqualToAnchor:content.centerXAnchor];
  [centered setPriority:NSLayoutPriorityDefaultHigh];
  [NSLayoutConstraint activateConstraints:@[
    [self.gutter.topAnchor constraintEqualToAnchor:content.topAnchor],
    [self.gutter.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
    [self.gutter.bottomAnchor constraintEqualToAnchor:separator.topAnchor],
    [scroll.topAnchor constraintEqualToAnchor:content.topAnchor],
    [scroll.leadingAnchor constraintEqualToAnchor:self.gutter.trailingAnchor],
    [scroll.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
    [scroll.bottomAnchor constraintEqualToAnchor:separator.topAnchor],

    [separator.leadingAnchor constraintEqualToAnchor:content.leadingAnchor],
    [separator.trailingAnchor constraintEqualToAnchor:content.trailingAnchor],
    [separator.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-kBarHeight],

    [self.savedIcon.leadingAnchor constraintEqualToAnchor:content.leadingAnchor constant:14],
    [self.savedIcon.centerYAnchor constraintEqualToAnchor:content.bottomAnchor constant:-kBarHeight / 2],
    [self.savedLabel.leadingAnchor constraintEqualToAnchor:self.savedIcon.trailingAnchor constant:5],
    [self.savedLabel.centerYAnchor constraintEqualToAnchor:barCenter],
    [self.pathLabel.leadingAnchor constraintEqualToAnchor:self.savedLabel.trailingAnchor constant:10],
    [self.pathLabel.centerYAnchor constraintEqualToAnchor:barCenter],

    centered,
    [self.statusButton.centerYAnchor constraintEqualToAnchor:barCenter],
    [self.statusButton.leadingAnchor constraintGreaterThanOrEqualToAnchor:self.pathLabel.trailingAnchor constant:16],
    [self.statusButton.trailingAnchor constraintLessThanOrEqualToAnchor:save.leadingAnchor constant:-16],

    [close.trailingAnchor constraintEqualToAnchor:content.trailingAnchor constant:-14],
    [close.centerYAnchor constraintEqualToAnchor:barCenter],
    [save.trailingAnchor constraintEqualToAnchor:close.leadingAnchor constant:-8],
    [save.centerYAnchor constraintEqualToAnchor:barCenter],
  ]];
}

- (NSFont *)editorFont {
  return [NSFont monospacedSystemFontOfSize:12 weight:NSFontWeightRegular];
}

#pragma mark - Showing and loading

- (void)showConfiguration {
  if (!self.dirty) [self loadFromDisk];
  [NSApp activateIgnoringOtherApps:YES];
  [self showWindow:self];
  [[self window] makeKeyAndOrderFront:self];
  [[self window] makeFirstResponder:self.textView];
}

+ (void)reopenAfterRelaunchIfNeeded {
  NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
  NSDictionary *state = [defaults dictionaryForKey:kReopenDefaultsKey];
  if (state == nil) return;
  [defaults removeObjectForKey:kReopenDefaultsKey];

  ConfigurationWindowController *controller = [self sharedController];
  [controller showConfiguration];
  NSUInteger length = [[controller.textView string] length];
  NSUInteger selection = MIN([state[@"selection"] unsignedIntegerValue], length);
  [controller.textView setSelectedRange:NSMakeRange(selection, 0)];
  NSClipView *clip = [[controller.textView enclosingScrollView] contentView];
  [clip scrollToPoint:NSMakePoint(0, [state[@"scrollY"] doubleValue])];
  [[controller.textView enclosingScrollView] reflectScrolledClipView:clip];
}

- (NSString *)configPath {
  return [SlateConfigDocument defaultPath];
}

- (NSDate *)modificationDateOnDisk {
  NSString *target = [[self configPath] stringByResolvingSymlinksInPath];
  return [[NSFileManager defaultManager] attributesOfItemAtPath:target error:nil][NSFileModificationDate];
}

// The bundled defaults, converted to the managed format.
- (NSString *)defaultConfigText {
  NSString *path = [[NSBundle mainBundle] pathForResource:@"default" ofType:@"slate"];
  NSString *legacy = path ? [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:nil] : nil;
  if (legacy == nil) return [[[SlateConfigDocument alloc] init] stringRepresentation];
  return [[SlateLegacyMigration documentFromLegacySource:legacy warnings:[NSMutableArray array]] stringRepresentation];
}

- (void)loadFromDisk {
  NSError *error = nil;
  NSString *text = [NSString stringWithContentsOfFile:[self configPath] encoding:NSUTF8StringEncoding error:&error];
  self.fileExisted = text != nil;
  if (text == nil) {
    BOOL missing = [error.domain isEqualToString:NSCocoaErrorDomain] && error.code == NSFileReadNoSuchFileError;
    if (!missing) {
      [self showError:@"Couldn't read ~/.slate.js" detail:[error localizedDescription]];
    }
    text = missing ? [self defaultConfigText] : @"";
  }
  self.loadedModificationDate = [self modificationDateOnDisk];

  self.loading = YES;
  [self.textView setString:text];
  [[self.textView undoManager] removeAllActions];
  [self.textView setSelectedRange:NSMakeRange(0, 0)];
  [self.textView scrollRangeToVisible:NSMakeRange(0, 0)];
  self.loading = NO;
  [self.gutter updateThickness];
  [self setDirty:NO];
  [self runValidation];
}

- (void)setDirty:(BOOL)dirty {
  _dirty = dirty;
  [[self window] setDocumentEdited:dirty];
  if (dirty) {
    [self.savedIcon setImage:[self symbol:@"circle.fill" color:[NSColor systemOrangeColor]]];
    [self.savedLabel setStringValue:@"Edited"];
  } else if (self.fileExisted) {
    [self.savedIcon setImage:[self symbol:@"checkmark.circle.fill" color:[NSColor secondaryLabelColor]]];
    [self.savedLabel setStringValue:@"Saved"];
  } else {
    [self.savedIcon setImage:[self symbol:@"doc.badge.plus" color:[NSColor secondaryLabelColor]]];
    [self.savedLabel setStringValue:@"Not saved yet"];
  }
}

#pragma mark - Editing

- (void)textDidChange:(NSNotification *)notification {
  if (self.loading) return;
  if (!self.dirty) [self setDirty:YES];
  [[self.textView layoutManager] removeTemporaryAttribute:NSBackgroundColorAttributeName
                                        forCharacterRange:NSMakeRange(0, [[self.textView string] length])];
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(runValidation) object:nil];
  [self performSelector:@selector(runValidation) withObject:nil afterDelay:kValidateDelay];
}

// Tab inserts two spaces, matching the generated file.
- (BOOL)textView:(NSTextView *)textView doCommandBySelector:(SEL)selector {
  if (selector == @selector(insertTab:)) {
    [textView insertText:@"  " replacementRange:[textView selectedRange]];
    return YES;
  }
  return NO;
}

- (void)textStorage:(NSTextStorage *)textStorage didProcessEditing:(NSTextStorageEditActions)editedMask
              range:(NSRange)editedRange changeInLength:(NSInteger)delta {
  if (editedMask & NSTextStorageEditedCharacters) [self highlight:textStorage];
}

- (void)color:(NSTextStorage *)storage pattern:(NSString *)pattern color:(NSColor *)color {
  NSRegularExpression *re = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
  [re enumerateMatchesInString:[storage string] options:0 range:NSMakeRange(0, [storage length])
                    usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
    [storage addAttribute:NSForegroundColorAttributeName value:color range:[match range]];
  }];
}

- (void)highlight:(NSTextStorage *)storage {
  NSRange all = NSMakeRange(0, [storage length]);
  [storage addAttribute:NSFontAttributeName value:[self editorFont] range:all];
  [storage addAttribute:NSForegroundColorAttributeName value:[NSColor textColor] range:all];
  [self color:storage pattern:@"\\b(var|let|const|function|return|if|else|for|while|do|switch|case|break|continue|new|this|typeof|in|of|try|catch|throw|true|false|null|undefined)\\b"
        color:[NSColor systemPinkColor]];
  [self color:storage pattern:@"\\b[0-9]+(\\.[0-9]+)?\\b" color:[NSColor systemBlueColor]];
  [self color:storage pattern:@"\\b(slate|S)(?=\\.)" color:[NSColor systemPurpleColor]];

  // Strings and comments in one pass, so "//" inside a string isn't a comment and vice versa.
  NSRegularExpression *tokens = [NSRegularExpression regularExpressionWithPattern:
    @"(//[^\\n]*|/\\*[\\s\\S]*?\\*/)|(\"(?:\\\\.|[^\"\\\\\\n])*\"|'(?:\\\\.|[^'\\\\\\n])*'|`(?:\\\\.|[^`\\\\])*`)"
                                                                         options:0 error:nil];
  NSRegularExpression *alias = [NSRegularExpression regularExpressionWithPattern:@"\\$\\{[^}]*\\}" options:0 error:nil];
  NSString *text = [storage string];
  [tokens enumerateMatchesInString:text options:0 range:all usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
    if ([match rangeAtIndex:1].location != NSNotFound) {
      [storage addAttribute:NSForegroundColorAttributeName value:[NSColor secondaryLabelColor] range:[match range]];
      return;
    }
    [storage addAttribute:NSForegroundColorAttributeName value:[NSColor systemRedColor] range:[match range]];
    [alias enumerateMatchesInString:text options:0 range:[match range] usingBlock:^(NSTextCheckingResult *a, NSMatchingFlags f, BOOL *s) {
      [storage addAttribute:NSForegroundColorAttributeName value:[NSColor systemOrangeColor] range:[a range]];
    }];
  }];
}

#pragma mark - Validation

- (NSRange)rangeOfLine:(NSUInteger)line {
  NSString *text = [self.textView string];
  NSUInteger index = 0;
  for (NSUInteger current = 1; current < line && index < [text length]; current++) {
    index = NSMaxRange([text lineRangeForRange:NSMakeRange(index, 0)]);
  }
  if (index > [text length]) return NSMakeRange(NSNotFound, 0);
  return [text lineRangeForRange:NSMakeRange(index, 0)];
}

- (NSString *)plural:(NSUInteger)count of:(NSString *)noun {
  return [NSString stringWithFormat:@"%lu %@%@", (unsigned long)count, noun, count == 1 ? @"" : @"s"];
}

- (void)setStatus:(NSString *)text symbol:(NSString *)symbol color:(NSColor *)color {
  [self.statusButton setImage:[self symbol:symbol color:color]];
  // A chevron shows the status opens a list when there are issues.
  [self.statusButton setTitle:[self.issues count] > 0 ? [text stringByAppendingString:@"  ▾"] : text];
  [self.statusButton setToolTip:[self.issues count] > 0 ? [NSString stringWithFormat:@"Show %@", [self plural:[self.issues count] of:@"issue"]] : nil];
}

- (SlateConfigValidationResult *)runValidation {
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(runValidation) object:nil];
  SlateConfigValidationResult *result = [SlateConfigValidator validateSource:[self.textView string]];
  self.issues = result.issues;

  NSString *counts = [NSString stringWithFormat:@"%@, %@", [self plural:result.bindingCount of:@"binding"],
                      [self plural:result.settingCount of:@"setting"]];
  if (result.errorCount > 0) {
    SlateConfigIssue *first = result.issues[0];
    NSString *where = first.line > 0 ? [NSString stringWithFormat:@"line %lu: ", (unsigned long)first.line] : @"";
    [self setStatus:[NSString stringWithFormat:@"%@ · %@%@", [self plural:result.errorCount of:@"error"], where, first.message]
             symbol:@"xmark.octagon.fill" color:[NSColor systemRedColor]];
  } else if (result.warningCount > 0) {
    [self setStatus:[NSString stringWithFormat:@"Valid · %@ · %@", counts, [self plural:result.warningCount of:@"warning"]]
             symbol:@"exclamationmark.triangle.fill" color:[NSColor systemOrangeColor]];
  } else {
    [self setStatus:[@"Valid · " stringByAppendingString:counts] symbol:@"checkmark.circle.fill" color:[NSColor systemGreenColor]];
  }

  // Error lines marked in the gutter and text.
  NSMutableIndexSet *errorLines = [NSMutableIndexSet indexSet];
  NSLayoutManager *layoutManager = [self.textView layoutManager];
  [layoutManager removeTemporaryAttribute:NSBackgroundColorAttributeName forCharacterRange:NSMakeRange(0, [[self.textView string] length])];
  for (SlateConfigIssue *issue in result.issues) {
    if (!issue.isError || issue.line == 0) continue;
    [errorLines addIndex:issue.line];
    NSRange range = [self rangeOfLine:issue.line];
    if (range.location != NSNotFound) {
      [layoutManager addTemporaryAttribute:NSBackgroundColorAttributeName
                                     value:[[NSColor systemRedColor] colorWithAlphaComponent:0.15]
                         forCharacterRange:range];
    }
  }
  [self.gutter setErrorLines:errorLines];
  return result;
}

- (IBAction)showIssues:(id)sender {
  if ([self.issues count] == 0) return;
  NSMenu *menu = [[NSMenu alloc] init];
  for (SlateConfigIssue *issue in self.issues) {
    NSString *title = issue.line > 0 ? [NSString stringWithFormat:@"Line %lu: %@", (unsigned long)issue.line, issue.message] : issue.message;
    NSMenuItem *item = [menu addItemWithTitle:title action:@selector(jumpToIssue:) keyEquivalent:@""];
    [item setTarget:self];
    [item setRepresentedObject:@(issue.line)];
    [item setImage:[self symbol:issue.isError ? @"xmark.octagon.fill" : @"exclamationmark.triangle.fill"
                          color:issue.isError ? [NSColor systemRedColor] : [NSColor systemOrangeColor]]];
  }
  [menu popUpMenuPositioningItem:nil atLocation:NSMakePoint(0, NSHeight([self.statusButton bounds]) + 4) inView:self.statusButton];
}

- (IBAction)jumpToIssue:(NSMenuItem *)sender {
  [self goToLine:[[sender representedObject] unsignedIntegerValue]];
}

- (void)goToLine:(NSUInteger)line {
  if (line == 0) return;
  NSRange range = [self rangeOfLine:line];
  if (range.location == NSNotFound) return;
  [[self window] makeFirstResponder:self.textView];
  [self.textView setSelectedRange:NSMakeRange(range.location, 0)];
  [self.textView scrollRangeToVisible:range];
  [self.textView showFindIndicatorForRange:range];
}

#pragma mark - Saving

- (void)showError:(NSString *)message detail:(NSString *)detail {
  NSAlert *alert = [[NSAlert alloc] init];
  [alert setAlertStyle:NSAlertStyleWarning];
  [alert setMessageText:message];
  [alert setInformativeText:detail ?: @""];
  [alert beginSheetModalForWindow:[self window] completionHandler:nil];
}

// Saves, then relaunches Slate to apply the file; the window reopens where it was.
- (IBAction)save:(id)sender {
  SlateConfigValidationResult *result = [self runValidation];
  if (result.errorCount > 0) {
    SlateConfigIssue *first = result.issues[0];
    NSAlert *alert = [[NSAlert alloc] init];
    [alert setAlertStyle:NSAlertStyleWarning];
    [alert setMessageText:[NSString stringWithFormat:@"Save with %@?", [self plural:result.errorCount of:@"error"]]];
    [alert setInformativeText:[NSString stringWithFormat:
      @"%@%@\n\nIf you save anyway, Slate will show these errors when it reloads and skip what it can't load.",
      first.line > 0 ? [NSString stringWithFormat:@"Line %lu: ", (unsigned long)first.line] : @"", first.message]];
    [alert addButtonWithTitle:@"Review errors"];
    [alert addButtonWithTitle:@"Save anyway"];
    [alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse response) {
      if (response == NSAlertFirstButtonReturn) {
        [self goToLine:first.line];
      } else {
        [self confirmOverwriteThenSave];
      }
    }];
    return;
  }
  [self confirmOverwriteThenSave];
}

- (BOOL)changedOnDisk {
  NSDate *current = [self modificationDateOnDisk];
  if (current == nil && self.loadedModificationDate == nil) return NO;
  return ![current isEqualToDate:self.loadedModificationDate];
}

- (void)confirmOverwriteThenSave {
  if (![self changedOnDisk]) {
    [self writeAndApply];
    return;
  }
  NSAlert *alert = [[NSAlert alloc] init];
  [alert setAlertStyle:NSAlertStyleWarning];
  [alert setMessageText:@"~/.slate.js changed on disk"];
  [alert setInformativeText:@"Another app changed the file after you opened it here. Saving replaces those changes; the previous file is kept as ~/.slate.js.bak."];
  [alert addButtonWithTitle:@"Cancel"];
  [alert addButtonWithTitle:@"Replace"];
  [alert beginSheetModalForWindow:[self window] completionHandler:^(NSModalResponse response) {
    if (response == NSAlertSecondButtonReturn) [self writeAndApply];
  }];
}

- (void)writeAndApply {
  NSError *error = nil;
  if (![SlateConfigDocument writeString:[self.textView string] toFile:[self configPath] error:&error]) {
    [self showError:@"Couldn't save ~/.slate.js" detail:[error localizedDescription]];
    return;
  }
  self.fileExisted = YES;
  [self setDirty:NO];
  self.loadedModificationDate = [self modificationDateOnDisk];

  NSDictionary *state = @{
    @"selection": @([self.textView selectedRange].location),
    @"scrollY": @(NSMinY([[[self.textView enclosingScrollView] contentView] bounds])),
  };
  [[NSUserDefaults standardUserDefaults] setObject:state forKey:kReopenDefaultsKey];
  [[NSUserDefaults standardUserDefaults] synchronize];
  [(SlateAppDelegate *)[NSApp delegate] relaunch];
}

#pragma mark - Closing

// Close discards unsaved changes; the next open reloads ~/.slate.js from disk.
- (IBAction)closeConfiguration:(id)sender {
  [[self window] close];
}

- (void)windowWillClose:(NSNotification *)notification {
  [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(runValidation) object:nil];
  [self setDirty:NO];
}

@end
