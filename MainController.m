//
//  MainController.m
//  WebPresenter
//
//  Created by Robert Walker on 5/4/06.
//  Copyright Bennett Technology Group 2006 . All rights reserved.
//

#import "MainController.h"
#import "FullScreenWindow.h"
#import "TransitionView.h"

@implementation MainController

- (void)awakeFromNib
{
	NSError *error;
	
	// Initialize slide delay to 5 seconds
	[slideDelayTextField setDoubleValue:5.0];
	isAnimating = YES;
	
	// Set the default sort descriptors
	NSSortDescriptor *ordering = [[NSSortDescriptor alloc] initWithKey:@"identifier" ascending:YES];
	[mSlidesArrayController setSortDescriptors:[NSArray arrayWithObject:ordering]];
	[ordering release];
	
	// Create and set fetch request
//	NSManagedObjectContext *moc = [self managedObjectContext];
//	NSEntityDescription *entityDescription =
//		[NSEntityDescription entityForName:@"Slide" inManagedObjectContext:moc];
//	NSFetchRequest *request = [[[NSFetchRequest alloc] init] autorelease];
//	[request setEntity:entityDescription];
//	NSPredicate *predicate =
//		[NSPredicate predicateWithFormat:@"enabled = YES"];
//	[request setPredicate:predicate];
    
	// Preload web content
	[mSlidesArrayController fetchWithRequest:nil merge:NO error:&error];
	[transitionView preloadWebContent:[mSlidesArrayController arrangedObjects]];
}

- (NSArrayController *)slidesArrayController
{
	return mSlidesArrayController;
}

/**
    Returns the support folder for the application, used to store the Core Data
    store file.  This code uses a folder named "WebPresenter" for
    the content, either in the NSApplicationSupportDirectory location or (if the
    former cannot be found), the system's temporary directory.
 */

- (NSString *)applicationSupportFolder {

    NSArray *paths = NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES);
    NSString *basePath = ([paths count] > 0) ? [paths objectAtIndex:0] : NSTemporaryDirectory();
    return [basePath stringByAppendingPathComponent:@"WebPresenter"];
}


/**
    Creates, retains, and returns the managed object model for the application 
    by merging all of the models found in the application bundle and all of the 
    framework bundles.
 */
 
- (NSManagedObjectModel *)managedObjectModel {

    if (managedObjectModel != nil) {
        return managedObjectModel;
    }
	
    NSMutableSet *allBundles = [[NSMutableSet alloc] init];
    [allBundles addObject: [NSBundle mainBundle]];
    [allBundles addObjectsFromArray: [NSBundle allFrameworks]];
    
    managedObjectModel = [[NSManagedObjectModel mergedModelFromBundles: [allBundles allObjects]] retain];
    [allBundles release];
    
    return managedObjectModel;
}


/**
    Returns the persistent store coordinator for the application.  This 
    implementation will create and return a coordinator, having added the 
    store for the application to it.  (The folder for the store is created, 
    if necessary.)
 */

- (NSPersistentStoreCoordinator *) persistentStoreCoordinator {

    if (persistentStoreCoordinator != nil) {
        return persistentStoreCoordinator;
    }

    NSFileManager *fileManager;
    NSString *applicationSupportFolder = nil;
    NSURL *url;
    NSError *error;
    
    fileManager = [NSFileManager defaultManager];
    applicationSupportFolder = [self applicationSupportFolder];
    if ( ![fileManager fileExistsAtPath:applicationSupportFolder isDirectory:NULL] ) {
        [fileManager createDirectoryAtPath:applicationSupportFolder attributes:nil];
    }
    
    url = [NSURL fileURLWithPath: [applicationSupportFolder stringByAppendingPathComponent: @"WebPresenter.xml"]];
    persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel: [self managedObjectModel]];
    if (![persistentStoreCoordinator addPersistentStoreWithType:NSXMLStoreType configuration:nil URL:url options:nil error:&error]){
        [[NSApplication sharedApplication] presentError:error];
    }    

    return persistentStoreCoordinator;
}


/**
    Returns the managed object context for the application (which is already
    bound to the persistent store coordinator for the application.) 
 */
 
- (NSManagedObjectContext *) managedObjectContext {

    if (managedObjectContext != nil) {
        return managedObjectContext;
    }

    NSPersistentStoreCoordinator *coordinator = [self persistentStoreCoordinator];
    if (coordinator != nil) {
        managedObjectContext = [[NSManagedObjectContext alloc] init];
        [managedObjectContext setPersistentStoreCoordinator: coordinator];
    }
    
    return managedObjectContext;
}


/**
    Returns the NSUndoManager for the application.  In this case, the manager
    returned is that of the managed object context for the application.
 */
 
- (NSUndoManager *)windowWillReturnUndoManager:(NSWindow *)window {
    return [[self managedObjectContext] undoManager];
}


/**
    Performs the save action for the application, which is to send the save:
    message to the application's managed object context.  Any encountered errors
    are presented to the user.
 */
 
- (IBAction) saveAction:(id)sender {
	int i = 0;
	
    NSError *error = nil;
    if (![[self managedObjectContext] save:&error]) {
        [[NSApplication sharedApplication] presentError:error];
    }
	
	// Rearrange the slides
	[mSlidesArrayController rearrangeObjects];
	
	// Renumber rows
	NSArray *slides = [mSlidesArrayController arrangedObjects];
	NSManagedObject *object;
    
	for (NSManagedObject *object in slides) {
		i++;
		[object setValue:[NSNumber numberWithInt:i] forKey:@"identifier"];
	}
	
	// Update preloaded web content
	[transitionView preloadWebContent:[mSlidesArrayController arrangedObjects]];
}

- (IBAction)playPresentation:sender
{
	// Invaidate the times if the presentation window is visible
	if ([presentationWindow isVisible]) {
		[[transitionView transTimer] invalidate];
		[[transitionView frameTimer] invalidate];
	}
	
	// Begin presentation
	[transitionView setupSlideTimer:[slideDelayTextField doubleValue]];
	[transitionView setNeedsDisplay:YES];
	[presentationWindow makeKeyAndOrderFront:self];
}

- (IBAction)stopPresentation:sender
{
	[presentationWindow close];
}

- (IBAction)goFullScreen:(id)sender
{
	// Invaidate the times if the presentation window is visible
	if ([presentationWindow isVisible]) {
		[[transitionView transTimer] invalidate];
		[[transitionView frameTimer] invalidate];
	}
	
    // Get the screen information.
    NSScreen* mainScreen = [NSScreen mainScreen]; 
    NSDictionary* screenInfo = [mainScreen deviceDescription]; 
    NSNumber* screenID = [screenInfo objectForKey:@"NSScreenNumber"];
	NSRect winRect = [mainScreen frame];
	
    // Capture the screen.
    CGDirectDisplayID displayID = (CGDirectDisplayID)[screenID longValue]; 
    CGDisplayErr err = CGDisplayCapture(displayID);
    if (err == CGDisplayNoErr)
    {
        // Create the full-screen window if it doesn’t already  exist.
        if (!mScreenWindow)
        {
            // Create the full-screen window.
            mScreenWindow =
				[[FullScreenWindow alloc] initWithContentRect:winRect
											styleMask:NSBorderlessWindowMask 
											  backing:NSBackingStoreBuffered 
												defer:NO 
											   screen:[NSScreen mainScreen]];
			
            // Establish the window attributes.
            [mScreenWindow setReleasedWhenClosed:NO];
            [mScreenWindow setDisplaysWhenScreenProfileChanges:YES];
            [mScreenWindow setDelegate:self];
        }
		
		// Create the content for the window.
		[transitionView setFrame:winRect];
		[mScreenWindow setContentView:transitionView];
		[transitionView setupTransitions];
		[transitionView setupSlideTimer:[slideDelayTextField doubleValue]];
		[transitionView preloadWebContent:[mSlidesArrayController arrangedObjects]];
		
		// Mark views as needing display
		[[transitionView superview] setNeedsDisplayInRect:[transitionView frame]];
		[transitionView setNeedsDisplay:YES];
		
        // The window has to be above the level of the shield window.
        int32_t shieldLevel = CGShieldingWindowLevel();
        [mScreenWindow setLevel:shieldLevel];
		
        // Show the window.
        [mScreenWindow makeKeyAndOrderFront:self];
		[mScreenWindow makeFirstResponder:transitionView];
    }
}

#pragma mark -

- (void)keyDown:(NSEvent *)theEvent
{
	// Escape will exit full screen mode
	unichar keyDownCharacter = [[theEvent charactersIgnoringModifiers] characterAtIndex:0];
	if (keyDownCharacter == '\E') {
		// Get the screen information.
		NSScreen* mainScreen = [NSScreen mainScreen]; 
		NSDictionary* screenInfo = [mainScreen deviceDescription]; 
		NSNumber* screenID = [screenInfo objectForKey:@"NSScreenNumber"];
		
		// Release the screen.
		CGDirectDisplayID displayID = (CGDirectDisplayID)[screenID longValue];
		CGDisplayErr err = CGDisplayRelease(displayID);
		
		// Set the window level back to normal and close
		[[transitionView window] setLevel:NSNormalWindowLevel];
		[[transitionView window] close];
	}
	
	// Space bar replaces the slide show with the actual web view
	if (keyDownCharacter == ' ') {
		NSTimer *transTimer = [transitionView transTimer];
		if (isAnimating) {
			// Stop the presentation
			[[transitionView transTimer] invalidate];
			[[transitionView frameTimer] invalidate];

			// Set window content to current web view
			[presentationWindow setContentView:[transitionView currentWebView]];
			[presentationWindow makeFirstResponder:[transitionView currentWebView]];
		} else {
			NSLog(@"Replacing tranistion view: %@", transitionView);

			// Set window content to display slideshow
			[presentationWindow setContentView:transitionView];
			[presentationWindow makeFirstResponder:transitionView];
			
			// Start the slideshow
			[transitionView setupSlideTimer:[slideDelayTextField doubleValue]];
			[transitionView setNeedsDisplay:YES];
			isAnimating = YES;
		}
	}
}

- (void)windowWillClose:(NSNotification *)aNotification
{
	NSWindow *aWindow = [aNotification object];
	NSRect frameRect;
	if (aWindow == mScreenWindow) {
		frameRect = NSMakeRect(0, 0, [presentationWindow frame].size.width, [presentationWindow frame].size.height);
		[transitionView setFrame:frameRect];
		[presentationWindow setContentView:transitionView];
		[transitionView setupTransitions];
		[presentationWindow makeFirstResponder:transitionView];
		[transitionView preloadWebContent:[mSlidesArrayController arrangedObjects]];
		[transitionView setNeedsDisplay:YES];
		[presentationWindow makeKeyAndOrderFront:self];
	}
	if (aWindow == presentationWindow && isAnimating) {
		[[transitionView transTimer] invalidate];
		[[transitionView frameTimer] invalidate];
	}
}

#pragma mark -

/**
    Implementation of the applicationShouldTerminate: method, used here to
    handle the saving of changes in the application managed object context
    before the application terminates.
 */
 
- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {

    NSError *error;
    int reply = NSTerminateNow;
    
    if (managedObjectContext != nil) {
        if ([managedObjectContext commitEditing]) {
            if ([managedObjectContext hasChanges] && ![managedObjectContext save:&error]) {
				
                // This error handling simply presents error information in a panel with an 
                // "Ok" button, which does not include any attempt at error recovery (meaning, 
                // attempting to fix the error.)  As a result, this implementation will 
                // present the information to the user and then follow up with a panel asking 
                // if the user wishes to "Quit Anyway", without saving the changes.

                // Typically, this process should be altered to include application-specific 
                // recovery steps.  

                BOOL errorResult = [[NSApplication sharedApplication] presentError:error];
				
                if (errorResult == YES) {
                    reply = NSTerminateCancel;
                } 

                else {
					
                    int alertReturn = NSRunAlertPanel(nil, @"Could not save changes while quitting. Quit anyway?" , @"Quit anyway", @"Cancel", nil);
                    if (alertReturn == NSAlertAlternateReturn) {
                        reply = NSTerminateCancel;	
                    }
                }
            }
        } 
        
        else {
            reply = NSTerminateCancel;
        }
    }
    
    return reply;
}

/**
    Implementation of dealloc, to release the retained variables.
 */
 
- (void) dealloc {
	[configWindow release], configWindow = nil;
	[presentationWindow release], presentationWindow = nil;
	[transitionView release], transitionView = nil;
	[mSlidesArrayController release], mSlidesArrayController = nil;
	[slideDelayTextField release], slideDelayTextField = nil;
	[mScreenWindow release], mScreenWindow = nil;
    [managedObjectContext release], managedObjectContext = nil;
    [persistentStoreCoordinator release], persistentStoreCoordinator = nil;
    [managedObjectModel release], managedObjectModel = nil;
    [super dealloc];
}


@end
