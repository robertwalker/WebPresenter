//
//  MainController.h
//  WebPresenter
//
//  Created by Robert Walker on 5/4/06.
//  Copyright Bennett Technology Group 2006 . All rights reserved.
//

#import <Cocoa/Cocoa.h>

@class TransitionView;

@interface MainController : NSResponder
{
    IBOutlet NSWindow *configWindow;
	IBOutlet NSWindow *presentationWindow;
    IBOutlet TransitionView *transitionView;
	IBOutlet NSArrayController *mSlidesArrayController;
	IBOutlet NSTextField *slideDelayTextField;
	
	NSWindow *mScreenWindow;
	
    NSPersistentStoreCoordinator *persistentStoreCoordinator;
    NSManagedObjectModel *managedObjectModel;
    NSManagedObjectContext *managedObjectContext;
	
	BOOL isAnimating;
}

- (NSArrayController *)slidesArrayController;

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator;
- (NSManagedObjectModel *)managedObjectModel;
- (NSManagedObjectContext *)managedObjectContext;

- (IBAction)saveAction:sender;
- (IBAction)playPresentation:sender;
- (IBAction)stopPresentation:sender;
- (IBAction)goFullScreen:(id)sender;

@end
