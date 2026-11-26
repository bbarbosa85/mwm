//
//  MWMSyncPresenter.m
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

#import "MWMSyncPresenter.h"
#import "MWMAlert.h"

@implementation MWMSyncPresenter

+ (NSString *)bulletedNames:(NSArray<MWMSyncItem *> *)items {
  NSMutableArray *lines = [NSMutableArray array];
  for (MWMSyncItem *item in items) [lines addObject:[@"• " stringByAppendingString:item.name]];
  return [lines componentsJoinedByString:@"\n"];
}

+ (NSString *)messageForReport:(MWMSyncReport *)report {
  return [report.summary stringByAppendingString:@"."];
}

+ (NSString *)questionForFlagged:(NSArray<MWMSyncItem *> *)flagged {
  if ([flagged count] == 0) return nil;
  NSMutableArray<MWMSyncItem *> *here = [NSMutableArray array], *gist = [NSMutableArray array];
  for (MWMSyncItem *item in flagged) [(item.status == MWMSyncStatusDeletedHere ? here : gist) addObject:item];
  NSMutableString *text = [NSMutableString string];
  if ([here count] > 0) [text appendFormat:@"These were deleted on this computer but are still in your gist:\n%@", [self bulletedNames:here]];
  if ([gist count] > 0) [text appendFormat:@"%@These were removed from your gist but are still on this computer:\n%@", [text length] ? @"\n\n" : @"", [self bulletedNames:gist]];
  [text appendString:@"\n\nClear them everywhere, or keep them and bring them back?"];
  return text;
}

+ (MWMAlert *)alertWithTitle:(NSString *)title text:(NSString *)text kind:(MWMAlertKind)kind {
  MWMAlert *alert = [MWMAlert alert];
  [alert setShowsSyncIcons:YES];
  [alert setKind:kind];
  [alert setMessageText:title];
  [alert setInformativeText:text];
  return alert;
}

+ (void)runWithCompletion:(void (^)(MWMSyncReport *))done {
  [MWMSync syncWithCompletion:^(MWMSyncReport *report) {
    [NSApp activateIgnoringOtherApps:YES];
    if (report.problem != nil) {
      MWMAlert *alert = [self alertWithTitle:@"Sync didn't finish" text:report.problem kind:MWMAlertKindWarning];
      [alert addButtonWithTitle:@"OK"];
      [alert runModal];
      if (done) done(report);
      return;
    }
    NSString *question = [self questionForFlagged:report.flagged];
    if (question == nil) {
      MWMAlert *alert = [self alertWithTitle:@"Sync finished" text:[self messageForReport:report] kind:MWMAlertKindSuccess];
      [alert addButtonWithTitle:@"OK"];
      [alert runModal];
      if (done) done(report);
      return;
    }
    MWMAlert *alert = [self alertWithTitle:@"Sync finished" text:[NSString stringWithFormat:@"%@\n\n%@", [self messageForReport:report], question] kind:MWMAlertKindConfirm];
    [alert addButtonWithTitle:@"Keep them"];
    [alert addDestructiveButtonWithTitle:@"Clear them"];
    BOOL keep = [alert runModal] == NSAlertFirstButtonReturn;
    [MWMSync resolveFlagged:report.flagged keep:keep completion:^(NSString *notes, NSString *problem) {
      MWMAlert *result = [self alertWithTitle:problem ? @"Couldn't finish" : (keep ? @"Kept" : @"Cleared") text:problem ?: notes kind:problem ? MWMAlertKindWarning : MWMAlertKindSuccess];
      [result addButtonWithTitle:@"OK"];
      [result runModal];
      if (done) done(report);
    }];
  }];
}

@end
