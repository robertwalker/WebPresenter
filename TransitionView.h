//
//  TransitionView.h
//  WebPresenter
//
//  Created by Robert Walker on 5/4/06.
//  Copyright 2006 Bennett Technology Group. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <QuartzCore/QuartzCore.h>
#import <WebKit/WebKit.h>

@class MainController;

@interface TransitionView : NSOpenGLView {
	// Controller
	IBOutlet MainController *controller;
	NSTimer			*frameTimer;
	NSTimer			*transTimer;

	// Core Image context
    CIContext		*_context;
    BOOL		    _needsReshape;
	
	// Images used for transitions
    CIImage		    *sourceImage, *targetImage;
    CIImage		    *shadingImage;
    CIImage		    *backsideImage;
    CIImage		    *blankImage;
    CIImage		    *maskImage;
	
	// Array of CIFilters in the transition category
    NSMutableArray	*transitions;
	
	// Cached web content used to create the slides
	NSMutableArray	*webContent;
	// Variables used to control scene
    NSTimeInterval	base;
	NSTimeInterval	current;
	int				currentWebViewIndex;
	int				currentTransitionIndex;
	int				transitionCounter;
	BOOL			isTransitioning;
	BOOL			isWebViewLoadComplete;
}

- (NSTimer *)frameTimer;
- (NSTimer *)transTimer;
- (WebView *)currentWebView;
- (void)setupSlideTimer:(NSTimeInterval)t;

- (void)setSourceImage: (CIImage *)source;
- (void)setTargetImage: (CIImage *)target;
- (CIImage *)shadingImage;
- (CIImage *)backsideImage;
- (CIImage *)blankImage;
- (CIImage *)maskImage;

- (void)preloadWebContent:(NSArray *)slides;
- (void)setViewportRect:(NSRect)bounds;
- (CIImage *)imageForTransition: (int)transitionIndex  atTime: (float)t;

@end

@interface TransitionView (TransitionViewSetup)

- (void)setupTransitions;

@end
