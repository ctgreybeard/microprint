//
//  AppDelegate.m
//  MicroPrint UI
//
//  Created by Tomas Franzén on Mon 2015-07-13.
//  Copyright (c) 2015 Tomas Franzén. All rights reserved.
//

#import "TFPApplicationDelegate.h"

@interface TFPApplicationDelegate ()
@property NSWindow *mainWindow;
@end


@implementation TFPApplicationDelegate


- (void)applicationDidFinishLaunching:(NSNotification *)notification {
	self.mainWindow = [NSApp windows].firstObject;
}


- (BOOL)applicationShouldOpenUntitledFile:(NSApplication *)sender {
	[self.mainWindow makeKeyAndOrderFront:nil];
	return NO;
}


- (IBAction)openMainWindow:(id)sender {
	[self.mainWindow makeKeyAndOrderFront:nil];
}


@end