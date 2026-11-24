//
//  ConfigurationBackupView.m
//
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

#import "ConfigurationBackupView.h"
#import "MWMAlert.h"
#import "MWMComponents.h"
#import "MWMConfigDocument.h"
#import "MWMDisplays.h"
#import "MWMGist.h"
#import "MWMSnapshots.h"
#import "MWMTheme.h"

@interface ConfigurationBackupView () <NSTextFieldDelegate>
@property (strong) NSStackView *rows;
@property (strong) NSTextField *nameField;
@property (strong) NSTextField *tokenField;
@property (strong) NSButton *backUpButton;
@property (copy) NSArray<MWMBackupEnvironment *> *environments;
@property (copy, nullable) NSString *problem;
@property (assign) BOOL loading;
@property (assign) BOOL loaded;
@property (assign) BOOL editingToken;
@property (assign) BOOL busy;
@end

@implementation ConfigurationBackupView

- (instancetype)initWithFrame:(NSRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    _interactive = YES;
    _environments = @[];
    _nameField = [NSTextField textFieldWithString:@"My computer"];
    [_nameField setDelegate:self];
    [_nameField setIdentifier:@"backup-name"];
    [_nameField setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    _tokenField = [NSSecureTextField textFieldWithString:@""];
    [_tokenField setPlaceholderString:@"ghp_…"];
    [_tokenField setIdentifier:@"backup-token"];
    [_tokenField setContentHuggingPriority:1 forOrientation:NSLayoutConstraintOrientationHorizontal];
    _rows = [NSStackView stackViewWithViews:@[]];
    [_rows setOrientation:NSUserInterfaceLayoutOrientationVertical];
    [_rows setAlignment:NSLayoutAttributeLeading];
    [_rows setSpacing:MWMSpacingL];
    [_rows setEdgeInsets:NSEdgeInsetsMake(8, MWMSpacingXL, MWMSpacingXL, MWMSpacingXL)];
    NSScrollView *scroll = [MWMComponents scrollViewWithContent:_rows];
    [self addSubview:scroll];
    [MWMComponents pinView:scroll toEdgesOf:self insets:NSEdgeInsetsMake(0, 0, 0, 0)];
    [self rebuild];
  }
  return self;
}

- (void)viewDidMoveToWindow {
  [super viewDidMoveToWindow];
  if (self.window != nil && !self.loaded && [MWMGist token] != nil) [self refresh:nil];
}

- (void)setDocument:(MWMConfigDocument *)document {
  _document = document;
  [self rebuild];
}

#pragma mark - Facts

- (NSView *)factsForDisplays:(NSArray<MWMDisplay *> *)displays shortcuts:(NSUInteger)shortcuts modifiers:(NSUInteger)modifiers snapshots:(NSUInteger)snapshots {
  NSMutableArray *lines = [NSMutableArray array];
  NSTextField *heading = [MWMComponents captionLabel:@"Displays"];
  [lines addObject:heading];
  for (MWMDisplay *display in displays) {
    NSMutableAttributedString *line = [[NSMutableAttributedString alloc] initWithString:display.name attributes:@{NSFontAttributeName: [MWMTheme fontSmall], NSForegroundColorAttributeName: [MWMTheme textPrimary]}];
    [line appendAttributedString:[[NSAttributedString alloc] initWithString:[NSString stringWithFormat:@" (%ld × %ld)", (long)display.width, (long)display.height] attributes:@{NSFontAttributeName: [MWMTheme fontSmall], NSForegroundColorAttributeName: [MWMTheme textSecondary]}]];
    [lines addObject:[NSTextField labelWithAttributedString:line]];
  }
  if ([displays count] == 0) [lines addObject:[MWMComponents secondaryLabel:@"No displays recorded"]];
  NSStackView *displaysColumn = [NSStackView stackViewWithViews:lines];
  [displaysColumn setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [displaysColumn setAlignment:NSLayoutAttributeLeading];
  [displaysColumn setSpacing:3];

  NSMutableArray *counts = [NSMutableArray array];
  NSArray *items = @[@[@"keyboard", @"shortcut", @(shortcuts)], @[@"command", @"modifier", @(modifiers)], @[@"camera", @"snapshot", @(snapshots)]];
  for (NSArray *item in items) {
    NSUInteger count = [item[2] unsignedIntegerValue];
    NSImageView *icon = [NSImageView imageViewWithImage:[NSImage imageWithSystemSymbolName:item[0] accessibilityDescription:nil]];
    [icon setContentTintColor:[MWMTheme textSecondary]];
    NSTextField *text = [MWMComponents labelWithText:[NSString stringWithFormat:@"%lu %@%@", (unsigned long)count, item[1], count == 1 ? @"" : @"s"] font:[MWMTheme fontSmall] color:[MWMTheme textPrimary]];
    NSStackView *line = [NSStackView stackViewWithViews:@[icon, text]];
    [line setSpacing:MWMSpacingS];
    [line setAlignment:NSLayoutAttributeCenterY];
    [[icon.widthAnchor constraintEqualToConstant:18] setActive:YES];
    [counts addObject:line];
  }
  NSStackView *countsColumn = [NSStackView stackViewWithViews:counts];
  [countsColumn setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [countsColumn setAlignment:NSLayoutAttributeLeading];
  [countsColumn setSpacing:6];
  [countsColumn setIdentifier:@"backup-counts"];

  NSStackView *facts = [NSStackView stackViewWithViews:@[displaysColumn, [MWMComponents spacer], countsColumn]];
  [facts setAlignment:NSLayoutAttributeTop];
  [facts setSpacing:MWMSpacingXL];
  return facts;
}

// The title, a separator and the facts, wrapped in a card.
- (NSView *)cardWithTop:(NSView *)top facts:(NSView *)facts dashed:(BOOL)dashed extra:(NSArray<NSView *> *)extra identifier:(NSString *)identifier {
  NSMutableArray *views = [NSMutableArray arrayWithObject:top];
  [views addObjectsFromArray:extra];
  NSView *line = [MWMComponents separator];
  [views addObject:line];
  [views addObject:facts];
  NSStackView *column = [NSStackView stackViewWithViews:views];
  [column setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [column setAlignment:NSLayoutAttributeLeading];
  [column setSpacing:MWMSpacingM];
  for (NSView *view in views) [[view.widthAnchor constraintEqualToAnchor:column.widthAnchor] setActive:YES];
  [column setCustomSpacing:MWMSpacingL afterView:[views count] > 2 ? extra.lastObject ?: top : top];
  NSView *card = dashed ? [MWMComponents dashedCard] : [MWMComponents card];
  [card setIdentifier:identifier];
  [card addSubview:column];
  [MWMComponents pinView:column toEdgesOf:card insets:NSEdgeInsetsMake(MWMSpacingL, MWMSpacingL, MWMSpacingL, MWMSpacingL)];
  return card;
}

#pragma mark - Page

static NSString *const kNewTokenURL = @"https://github.com/settings/tokens/new?description=MWM%20backup&scopes=gist";
static NSString *const kTokensURL = @"https://github.com/settings/tokens";

// A step: an icon tile, a title, a line of help and, when there is one, a control under it.
- (NSView *)stepCardNumber:(NSUInteger)number symbol:(NSString *)symbol title:(NSString *)title help:(NSString *)help extra:(NSArray<NSView *> *)extra {
  NSView *circle = [MWMComponents iconTileWithSymbol:symbol color:[MWMTheme accent] size:34];
  NSMutableArray *column = [NSMutableArray arrayWithObject:[MWMComponents labelWithText:title font:[MWMTheme fontBodyStrong] color:[MWMTheme textPrimary]]];
  if (help != nil) [column addObject:[MWMComponents wrappingLabelWithText:help size:12 color:[MWMTheme textSecondary] weight:NSFontWeightRegular]];
  [column addObjectsFromArray:extra];
  NSStackView *text = [NSStackView stackViewWithViews:column];
  [text setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [text setAlignment:NSLayoutAttributeLeading];
  [text setSpacing:MWMSpacingS];
  for (NSView *view in column) if ([view isKindOfClass:[NSTextField class]] || [view isKindOfClass:[NSStackView class]]) [[view.widthAnchor constraintLessThanOrEqualToAnchor:text.widthAnchor] setActive:YES];
  [text setCustomSpacing:MWMSpacingM afterView:column.count > 1 ? column[1] : column[0]];
  NSStackView *row = [NSStackView stackViewWithViews:@[circle, text]];
  [row setAlignment:NSLayoutAttributeTop];
  [row setSpacing:MWMSpacingM];
  NSView *card = [MWMComponents card];
  [card setIdentifier:[NSString stringWithFormat:@"backup-step-%lu", (unsigned long)number]];
  [card addSubview:row];
  [MWMComponents pinView:row toEdgesOf:card insets:NSEdgeInsetsMake(MWMSpacingL, MWMSpacingL, MWMSpacingL, MWMSpacingL)];
  return card;
}

- (NSView *)tokenBlock {
  BOOL has = [MWMGist token] != nil;
  NSTextField *title = [MWMComponents labelWithText:has ? @"Use a different token" : @"Connect your GitHub account" font:[MWMTheme fontBodyStrong] color:[MWMTheme textPrimary]];
  NSTextField *intro = [MWMComponents wrappingLabelWithText:@"Backups live in a private gist that only you can see. MWM needs a token to read and write it. This takes about a minute." size:12 color:[MWMTheme textSecondary] weight:NSFontWeightRegular];

  NSButton *open = [MWMComponents secondaryButtonWithTitle:@"Create token on GitHub" symbol:@"arrow.up.right.square" target:self action:@selector(createTokenPressed:)];
  [open setIdentifier:@"backup-create-token"];
  NSTextField *classic = [MWMComponents wrappingLabelWithText:@"It has to be a classic token. Fine-grained tokens can't reach gists." size:11 color:[MWMTheme textTertiary] weight:NSFontWeightRegular];
  NSView *one = [self stepCardNumber:1 symbol:@"link" title:@"Create a token on GitHub" help:@"The page opens with the name “MWM backup” and the gist permission already ticked. Pick an expiration and choose Generate token." extra:@[open, classic]];
  NSView *two = [self stepCardNumber:2 symbol:@"doc.on.doc" title:@"Copy the token" help:@"It starts with ghp_. GitHub shows it only once, so copy it before you leave the page." extra:@[]];

  NSButton *connect = [MWMComponents accentButtonWithTitle:has ? @"Save token" : @"Connect" symbol:nil target:self action:@selector(connectPressed:)];
  [connect setIdentifier:@"backup-connect"];
  NSStackView *form = [NSStackView stackViewWithViews:@[self.tokenField, connect]];
  [form setSpacing:MWMSpacingS];
  [form setAlignment:NSLayoutAttributeCenterY];
  NSView *three = [self stepCardNumber:3 symbol:@"key" title:@"Paste it here" help:nil extra:@[form]];
  [[form.widthAnchor constraintEqualToAnchor:three.widthAnchor constant:-(2 * MWMSpacingL + 34 + MWMSpacingM)] setActive:YES];

  NSMutableAttributedString *note = [[NSMutableAttributedString alloc] initWithString:@"The token is kept in your Keychain and used only for one private gist called “MWM backup”. You can revoke it any time in your GitHub token settings." attributes:@{NSFontAttributeName: [NSFont systemFontOfSize:12], NSForegroundColorAttributeName: [MWMTheme textSecondary]}];
  NSRange link = [[note string] rangeOfString:@"your GitHub token settings"];
  [note addAttributes:@{NSLinkAttributeName: [NSURL URLWithString:kTokensURL], NSForegroundColorAttributeName: [MWMTheme accent]} range:link];
  NSTextField *keychain = [NSTextField wrappingLabelWithString:@""];
  [keychain setAttributedStringValue:note];
  [keychain setSelectable:YES];
  [keychain setAllowsEditingTextAttributes:YES];
  [keychain setIdentifier:@"backup-keychain-note"];

  NSStackView *column = [NSStackView stackViewWithViews:@[title, intro, one, two, three, keychain]];
  [column setOrientation:NSUserInterfaceLayoutOrientationVertical];
  [column setAlignment:NSLayoutAttributeLeading];
  [column setSpacing:MWMSpacingL];
  [column setCustomSpacing:MWMSpacingXS afterView:title];
  [column setCustomSpacing:MWMSpacingXL afterView:intro];
  [column setCustomSpacing:MWMSpacingXL afterView:three];
  for (NSView *view in @[intro, one, two, three, keychain]) [[view.widthAnchor constraintEqualToAnchor:column.widthAnchor] setActive:YES];
  [column setIdentifier:@"backup-token-card"];
  return column;
}

- (void)createTokenPressed:(id)sender { [[NSWorkspace sharedWorkspace] openURL:[NSURL URLWithString:kNewTokenURL]]; }

- (NSArray<MWMDisplay *> *)connectedDisplays { return [MWMDisplays connected]; }

- (NSDictionary *)currentCounts {
  return @{@"shortcuts": @([self.document.bindings count]), @"modifiers": @([self.document.modifiers count]), @"snapshots": @([[MWMSnapshots snapshots] count])};
}

- (NSView *)thisComputerCard {
  NSDictionary *counts = [self currentCounts];
  NSTextField *title = [MWMComponents labelWithText:@"This computer now" font:[MWMTheme fontBodyStrong] color:[MWMTheme textPrimary]];
  self.backUpButton = [MWMComponents accentButtonWithTitle:@"Back up" symbol:@"icloud.and.arrow.up" target:self action:@selector(backUpPressed:)];
  [self.backUpButton setIdentifier:@"backup-save"];
  NSStackView *form = [NSStackView stackViewWithViews:@[[MWMComponents labelWithText:@"Name" font:[MWMTheme fontSmall] color:[MWMTheme textSecondary]], self.nameField, self.backUpButton]];
  [form setSpacing:MWMSpacingS];
  [form setAlignment:NSLayoutAttributeCenterY];
  NSTextField *hint = [MWMComponents wrappingLabelWithText:@"Saving with a name that already exists replaces that backup." size:12 color:[MWMTheme textSecondary] weight:NSFontWeightRegular];
  [hint setIdentifier:@"backup-hint"];
  NSView *facts = [self factsForDisplays:[self connectedDisplays] shortcuts:[counts[@"shortcuts"] unsignedIntegerValue] modifiers:[counts[@"modifiers"] unsignedIntegerValue] snapshots:[counts[@"snapshots"] unsignedIntegerValue]];
  [facts setIdentifier:@"backup-now-facts"];
  NSView *card = [self cardWithTop:title facts:facts dashed:YES extra:@[form, hint] identifier:@"backup-now"];
  [self updateBackUpButton];
  return card;
}

- (NSView *)cardForEnvironment:(MWMBackupEnvironment *)environment {
  NSString *name = environment.name;
  NSMutableArray *top = [NSMutableArray arrayWithObject:[MWMComponents labelWithText:name font:[MWMTheme fontBodyStrong] color:[MWMTheme textPrimary]]];
  if ([environment matchesDisplays:[self connectedDisplays]]) {
    MWMChipView *chip = [MWMChipView chipWithText:@"Matches" color:[MWMTheme success]];
    [chip setIdentifier:@"backup-matches"];
    [top addObject:chip];
  }
  [top addObject:[MWMComponents spacer]];
  NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
  [formatter setLocalizedDateFormatFromTemplate:@"d MMM yyyy"];
  NSTextField *date = [MWMComponents labelWithText:[formatter stringFromDate:environment.savedAt] font:[MWMTheme fontSmall] color:[MWMTheme textSecondary]];
  [date setAlignment:NSTextAlignmentRight];
  [date setIdentifier:@"backup-date"];
  NSButton *restore = [MWMComponents secondaryButtonWithTitle:@"Restore" target:self action:@selector(restorePressed:)];
  [restore setIdentifier:[@"restore-" stringByAppendingString:name]];
  [restore setToolTip:@"Replace your shortcuts, slots and snapshots with this backup"];
  NSButton *remove = [NSButton buttonWithImage:[NSImage imageWithSystemSymbolName:@"trash" accessibilityDescription:@"Delete"] target:self action:@selector(deletePressed:)];
  [remove setBordered:NO];
  [remove setContentTintColor:[MWMTheme textTertiary]];
  [remove setIdentifier:[@"delete-" stringByAppendingString:name]];
  [remove setToolTip:@"Delete this backup"];
  [top addObjectsFromArray:@[date, restore, remove]];
  NSStackView *header = [NSStackView stackViewWithViews:top];
  [header setSpacing:MWMSpacingM];
  [header setAlignment:NSLayoutAttributeCenterY];
  NSView *facts = [self factsForDisplays:environment.displays shortcuts:environment.shortcutCount modifiers:environment.modifierCount snapshots:environment.snapshotCount];
  return [self cardWithTop:header facts:facts dashed:NO extra:@[] identifier:[@"backup-" stringByAppendingString:name]];
}

- (void)rebuild {
  for (NSView *view in [[self.rows arrangedSubviews] copy]) {
    [self.rows removeArrangedSubview:view];
    [view removeFromSuperview];
  }
  BOOL connected = [MWMGist token] != nil;
  void (^add)(NSView *) = ^(NSView *view) {
    [self.rows addArrangedSubview:view];
    [[view.widthAnchor constraintEqualToAnchor:self.rows.widthAnchor constant:-2 * MWMSpacingXL] setActive:YES];
  };
  if (!connected || self.editingToken) {
    add([self tokenBlock]);
  } else {
    NSButton *change = [MWMComponents secondaryButtonWithTitle:@"Change token" target:self action:@selector(changeTokenPressed:)];
    [change setIdentifier:@"backup-change-token"];
    NSStackView *bar = [NSStackView stackViewWithViews:@[[MWMComponents secondaryLabel:@"Private GitHub gist · token saved in your Keychain"], change, [MWMComponents spacer]]];
    [bar setSpacing:MWMSpacingM];
    [bar setAlignment:NSLayoutAttributeCenterY];
    add(bar);
  }
  if (!connected) return;
  add([self thisComputerCard]);
  [self.rows setCustomSpacing:MWMSpacingXL + 8 afterView:self.rows.arrangedSubviews.lastObject];
  add([MWMComponents sectionHeading:@"Saved in your gist"]);
  [self.rows setCustomSpacing:MWMSpacingM afterView:self.rows.arrangedSubviews.lastObject];
  if (self.problem != nil) {
    NSTextField *error = [MWMComponents wrappingLabelWithText:self.problem size:13 color:[MWMTheme danger] weight:NSFontWeightRegular];
    [error setIdentifier:@"backup-problem"];
    NSButton *retry = [MWMComponents secondaryButtonWithTitle:@"Try again" target:self action:@selector(retryPressed:)];
    [retry setIdentifier:@"backup-retry"];
    NSStackView *line = [NSStackView stackViewWithViews:@[error, retry]];
    [line setSpacing:MWMSpacingM];
    [line setAlignment:NSLayoutAttributeCenterY];
    add(line);
  } else if (self.loading && !self.loaded) {
    NSTextField *wait = [MWMComponents secondaryLabel:@"Loading your backups…"];
    [wait setIdentifier:@"backup-loading"];
    add(wait);
  } else if ([self.environments count] == 0) {
    NSTextField *none = [MWMComponents wrappingLabelWithText:@"No backups yet. Name this computer's setup and choose Back up." size:13 color:[MWMTheme textSecondary] weight:NSFontWeightRegular];
    [none setIdentifier:@"backup-empty"];
    add(none);
  }
  for (MWMBackupEnvironment *environment in self.environments) {
    add([self cardForEnvironment:environment]);
    [self.rows setCustomSpacing:MWMSpacingM afterView:self.rows.arrangedSubviews.lastObject];
  }
}

#pragma mark - Actions

- (void)updateBackUpButton {
  NSString *problem = self.document == nil ? @"Nothing to back up yet." : [MWMBackupEnvironment problemWithName:[self.nameField stringValue]];
  [self.backUpButton setEnabled:problem == nil && !self.busy];
  [self.backUpButton setToolTip:problem ?: @"Save this computer's setup to your gist"];
}

- (void)controlTextDidChange:(NSNotification *)note { [self updateBackUpButton]; }

- (void)changeTokenPressed:(id)sender { self.editingToken = YES; [self rebuild]; }

- (void)connectPressed:(id)sender { [self connectWithToken:[self.tokenField stringValue] completion:nil]; }
- (void)backUpPressed:(id)sender { [self backUpAs:[self.nameField stringValue] completion:nil]; }
- (void)retryPressed:(id)sender { [self refresh:nil]; }

- (void)restorePressed:(NSButton *)sender { [self restoreNamed:[sender.identifier substringFromIndex:[@"restore-" length]]]; }
- (void)deletePressed:(NSButton *)sender { [self deleteNamed:[sender.identifier substringFromIndex:[@"delete-" length]] completion:nil]; }

- (void)showProblem:(NSString *)message title:(NSString *)title {
  if (!self.interactive) return;
  MWMAlert *alert = [MWMAlert alert];
  [alert setKind:MWMAlertKindWarning];
  [alert setMessageText:title];
  [alert setInformativeText:message];
  [alert runModal];
}

- (void)refresh:(void (^)(void))done {
  self.loading = YES;
  self.problem = nil;
  [self rebuild];
  [MWMGist listEnvironments:^(NSArray<MWMBackupEnvironment *> *environments, NSString *problem) {
    self.loading = NO;
    self.loaded = problem == nil;
    self.problem = problem;
    self.environments = environments;
    [self rebuild];
    if (done) done();
  }];
}

- (void)connectWithToken:(NSString *)token completion:(void (^)(void))done {
  NSString *trimmed = [token stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
  if ([trimmed length] == 0) { if (done) done(); return; }
  [MWMGist checkToken:trimmed completion:^(NSString *problem) {
    if (problem != nil) {
      [self showProblem:problem title:@"That token didn't work"];
    } else {
      [MWMGist setToken:trimmed];
      [self.tokenField setStringValue:@""];
      self.editingToken = NO;
      self.loaded = NO;
      [self rebuild];
      [self refresh:done];
      return;
    }
    if (done) done();
  }];
}

- (void)backUpAs:(NSString *)name completion:(void (^)(void))done {
  NSString *trimmed = [MWMBackupEnvironment trimmedName:name];
  NSString *problem = [MWMBackupEnvironment problemWithName:trimmed];
  if (problem != nil || self.document == nil) { [self showProblem:problem ?: @"There's no configuration to back up yet." title:@"Can't back up"]; if (done) done(); return; }
  MWMBackupEnvironment *environment = [MWMBackupEnvironment environmentNamed:trimmed configText:[self.document stringRepresentation] snapshots:[MWMSnapshots exportAll] displays:[self connectedDisplays] date:[NSDate date]];
  self.busy = YES;
  [self updateBackUpButton];
  [MWMGist saveEnvironment:environment completion:^(NSString *saveProblem) {
    self.busy = NO;
    if (saveProblem != nil) {
      [self updateBackUpButton];
      [self showProblem:saveProblem title:@"The backup wasn't saved"];
      if (done) done();
      return;
    }
    [self refresh:done];
  }];
}

- (MWMBackupEnvironment *)environmentNamed:(NSString *)name {
  for (MWMBackupEnvironment *environment in self.environments) if ([environment.name isEqualToString:name]) return environment;
  return nil;
}

- (void)restoreNamed:(NSString *)name {
  MWMBackupEnvironment *environment = [self environmentNamed:name];
  if (environment == nil) return;
  NSError *error = nil;
  if ([MWMConfigDocument documentFromString:environment.configText lenient:YES error:&error] == nil) {
    [self showProblem:@"The configuration in this backup can't be read." title:@"Can't restore"];
    return;
  }
  if (self.interactive) {
    MWMAlert *alert = [MWMAlert alert];
    [alert setKind:MWMAlertKindConfirm];
    [alert setMessageText:[NSString stringWithFormat:@"Restore \"%@\"?", name]];
    [alert setInformativeText:@"Replaces your shortcuts, slots and snapshots with this backup. A copy of your current configuration is kept next to it first."];
    [alert addButtonWithTitle:@"Restore"];
    [alert addButtonWithTitle:@"Cancel"];
    if ([alert runModal] != NSAlertFirstButtonReturn) return;
  }
  if (![self.delegate backupView:self restoreConfigText:environment.configText]) return;
  [MWMSnapshots importAll:environment.snapshots];
  [self.delegate backupViewDidRestoreSnapshots:self];
  [self rebuild];
  if (self.interactive) {
    MWMAlert *done = [MWMAlert alert];
    [done setKind:MWMAlertKindSuccess];
    [done setMessageText:[NSString stringWithFormat:@"Restored \"%@\"", name]];
    [done setInformativeText:@"Choose Apply to start using it."];
    [done runModal];
  }
}

- (void)deleteNamed:(NSString *)name completion:(void (^)(void))done {
  if (self.interactive) {
    MWMAlert *alert = [MWMAlert alert];
    [alert setKind:MWMAlertKindDanger];
    [alert setMessageText:[NSString stringWithFormat:@"Delete \"%@\"?", name]];
    [alert setInformativeText:@"The backup is removed from your gist. This can't be undone."];
    [alert addButtonWithTitle:@"Cancel"];
    [alert addDestructiveButtonWithTitle:@"Delete"];
    if ([alert runModal] == NSAlertFirstButtonReturn) { if (done) done(); return; }
  }
  [MWMGist deleteEnvironmentNamed:name completion:^(NSString *problem) {
    if (problem != nil) { [self showProblem:problem title:@"The backup wasn't deleted"]; if (done) done(); return; }
    [self refresh:done];
  }];
}

@end
