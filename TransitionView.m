//
//  TransitionView.m
//  WebPresenter
//
//  Created by Robert Walker on 5/4/06.
//  Copyright 2006 Bennett Technology Group. All rights reserved.
//

#import "TransitionView.h"
#import "MainController.h"

@implementation TransitionView

+ (NSOpenGLPixelFormat *)defaultPixelFormat
{
    static NSOpenGLPixelFormat *pf;
	
    if (pf == nil)
    {
		/* Making sure the context's pixel format doesn't have a recovery
		* renderer is important - otherwise CoreImage may not be able to
		* create deeper context's that share textures with this one. */
		
		static const NSOpenGLPixelFormatAttribute attr[] = {
			NSOpenGLPFAAccelerated,
			NSOpenGLPFANoRecovery,
			NSOpenGLPFAColorSize, 32,
			0
		};
		
		pf = [[NSOpenGLPixelFormat alloc] initWithAttributes:(void *)&attr];
    }
	
    return pf;
}

#pragma mark -

- (id)initWithFrame:(NSRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        webContent = [[NSMutableArray arrayWithCapacity:3] retain];
		currentWebViewIndex = 0;
		current = 1;
		isTransitioning = NO;
		isWebViewLoadComplete = NO;
		transitionCounter = 0;
    }
    return self;
}

- (void)dealloc
{
	[webContent release];
    [transitions release];
    [_context release];
    
    [super dealloc];
}

#pragma mark -

- (void)awakeFromNib
{
    NSURL *url;
    NSRect bounds = [self bounds];
	
	// Setup the source and destination image for the transition
	url = [NSURL fileURLWithPath: [[NSBundle mainBundle]
        pathForResource: @"Loading" ofType: @"jpg"]];
	[self setSourceImage: [CIImage imageWithContentsOfURL: url]];
	
	url = [NSURL fileURLWithPath: [[NSBundle mainBundle]
        pathForResource: @"Loading" ofType: @"jpg"]];
	[self setTargetImage: [CIImage imageWithContentsOfURL: url]];
	
	// Setup our transitions
	if(transitions == nil)
		[self setupTransitions];

	// Seed the random number generator
	srandom([NSDate timeIntervalSinceReferenceDate]);
}

- (BOOL)acceptsFirstResponder
{
	return YES;
}

#pragma mark -

- (void)setSourceImage: (CIImage *)source
{
    [source retain];
    [sourceImage release];
    sourceImage = source;
}

- (void)setTargetImage: (CIImage *)target
{
    [target retain];
    [targetImage release];
    targetImage = target;
}

// return our static shading image
- (CIImage *)shadingImage
{
    if(!shadingImage)
    {
        NSURL  *url;
		
        url   = [NSURL fileURLWithPath: [[NSBundle mainBundle]
            pathForResource: @"Shading" ofType: @"tiff"]];
        shadingImage = [[CIImage alloc] initWithContentsOfURL: url];
    }
	
    return shadingImage;
}

// return our static backside image
- (CIImage *)backsideImage
{
    if(!backsideImage)
    {
        NSURL  *url;
		
        url   = [NSURL fileURLWithPath: [[NSBundle mainBundle]
            pathForResource: @"Backside" ofType: @"jpg"]];
        backsideImage = [[CIImage alloc] initWithContentsOfURL: url];
    }
	
    return backsideImage;
}

// return our static empty image
- (CIImage *)blankImage
{
    if(!blankImage)
    {
        NSURL  *url;
		
        url   = [NSURL fileURLWithPath: [[NSBundle mainBundle]
            pathForResource: @"Blank" ofType: @"jpg"]];
        blankImage = [[CIImage alloc] initWithContentsOfURL: url];
    }
	
    return blankImage;
}

// return our static mask image
- (CIImage *)maskImage
{
    if(!maskImage)
    {
        NSURL  *url;
		
        url   = [NSURL fileURLWithPath: [[NSBundle mainBundle]
            pathForResource: @"Mask" ofType: @"jpg"]];
        maskImage = [[CIImage alloc] initWithContentsOfURL: url];
    }
	
    return maskImage;
}

#pragma mark -

- (void)preloadWebContent:(NSArray *)slides;
{
    NSURL *url;
    NSRect bounds = [self bounds];
	NSMutableArray *urls = [NSMutableArray arrayWithCapacity:1];
	NSEnumerator *enumerator;
	WebView *aWebView;
	id object;
	
	// Make the first slide the current slide
	currentWebViewIndex = 0;
	isWebViewLoadComplete = NO;
	
	// setup the source and destination image for the transition
	url = [NSURL fileURLWithPath: [[NSBundle mainBundle]
        pathForResource: @"Loading" ofType: @"jpg"]];
	[self setSourceImage: [CIImage imageWithContentsOfURL: url]];
	
	url = [NSURL fileURLWithPath: [[NSBundle mainBundle]
        pathForResource: @"Loading" ofType: @"jpg"]];
	[self setTargetImage: [CIImage imageWithContentsOfURL: url]];
	
	enumerator = [slides objectEnumerator];
	while ((object = [enumerator nextObject])) {
		if ([[object valueForKey:@"enabled"] boolValue] == YES)
			[urls addObject:[object valueForKey:@"url"]];
	}
	
	enumerator = [urls objectEnumerator];
	[webContent removeAllObjects];
	while ((object = [enumerator nextObject])) {
		// Setup the web view
		aWebView = [[WebView alloc] initWithFrame:bounds];
		[aWebView setCustomUserAgent:@"Mozilla/5.0 (Macintosh; U; PPC Mac OS X; en) AppleWebKit/417.9 (KHTML, like Gecko) Safari/417.9.2"];
		[[aWebView mainFrame] loadRequest:[NSURLRequest requestWithURL: [NSURL URLWithString:object]]];
		
		// Set this class as the web view's frame load delegate
		[aWebView setFrameLoadDelegate:self];
		
		// Add web view to webContent array
		[webContent addObject:aWebView];
		[aWebView release];
	}
}

- (void)webView:(WebView *)sender didFinishLoadForFrame:(WebFrame *)frame
{
	if (sender == [self currentWebView]) {
		isWebViewLoadComplete = YES;
	}
}

#pragma mark -

- (void)setViewportRect:(NSRect)aRect
{
	NSRect  mappedVisibleRect = NSIntegralRect([self convertRect: aRect toView: self]);
	
	glViewport (0, 0, aRect.size.width, aRect.size.height);
	
	glMatrixMode (GL_PROJECTION);
	glLoadIdentity ();
	glOrtho(aRect.origin.x,
			aRect.origin.x + aRect.size.width,
			aRect.origin.y,
			aRect.origin.y + aRect.size.height,
			-1, 1);
	
	glMatrixMode (GL_MODELVIEW);
	glLoadIdentity ();
	
	_needsReshape = NO;
}

- (CIImage *)imageForTransition: (int)transitionIndex  atTime: (float)t
{
	NSRect bounds = [self bounds];
    CIFilter  *transition, *crop;
	
	transition = [transitions objectAtIndex:transitionIndex];
	
	if ([[transition inputKeys] containsObject:@"inputAngle"]) {
		if (transitionIndex == 2)
			[transition setValue:[NSNumber numberWithFloat:2.5] forKey:@"inputAngle"];
		else
			[transition setValue:[NSNumber numberWithFloat:0] forKey:@"inputAngle"];
	}
	
	// Set source and target images if not set
    if([transition valueForKey:@"inputImage"] == [self maskImage]) {
        [transition setValue: sourceImage  forKey: @"inputImage"];
        [transition setValue: targetImage  forKey: @"inputTargetImage"];
    }
	
    // Set the time for the transition
    [transition setValue: [NSNumber numberWithFloat: current]
				  forKey: @"inputTime"];
	
    // Crop the output image to be within the rect of the thumbnail.
	// This is needed as some transitions have effects that can go beyond the borders of the source image
    crop = [CIFilter filterWithName: @"CICrop"
					  keysAndValues: @"inputImage", [transition valueForKey: @"outputImage"], @"inputRectangle",
		[CIVector vectorWithX: 0  Y: 0 Z: bounds.size.width  W: bounds.size.height], nil];
	
    return [crop valueForKey: @"outputImage"];
}

#pragma mark -

- (NSTimer *)frameTimer
{
	return frameTimer;
}

- (NSTimer *)transTimer
{
	return transTimer;
}

#pragma mark -

- (WebView *)currentWebView
{
	return [webContent objectAtIndex:currentWebViewIndex];
}

- (void)setupSlideTimer:(NSTimeInterval)t
{
    // Setup the repeating timer to trigger the rendering - we will render at 30fps
    base = [NSDate timeIntervalSinceReferenceDate];
    frameTimer = [NSTimer scheduledTimerWithTimeInterval: 1.0/30.0  target: self
												selector: @selector(timerFired:)  userInfo: nil  repeats: YES];
    [[NSRunLoop currentRunLoop] addTimer: frameTimer  forMode: NSDefaultRunLoopMode];
	
	// Setup the timer for the delay between slides
    transTimer = [NSTimer scheduledTimerWithTimeInterval:t  target: self
												selector: @selector(transTimerFired:)  userInfo: nil  repeats: YES];
    [[NSRunLoop currentRunLoop] addTimer: transTimer  forMode: NSDefaultRunLoopMode];
}

- (void)prepareOpenGL
{
    long parm = 1;
	
    /* Enable beam-synced updates. */
	
    [[self openGLContext] setValues:&parm forParameter:NSOpenGLCPSwapInterval];
    
    /* Make sure that everything we don't need is disabled. Some of these
		* are enabled by default and can slow down rendering. */
	
    glDisable (GL_ALPHA_TEST);
    glDisable (GL_DEPTH_TEST);
    glDisable (GL_SCISSOR_TEST);
    glDisable (GL_BLEND);
    glDisable (GL_DITHER);
    glDisable (GL_CULL_FACE);
    glColorMask (GL_TRUE, GL_TRUE, GL_TRUE, GL_TRUE);
    glDepthMask (GL_FALSE);
    glStencilMask (0);
    glClearColor (0.0f, 0.0f, 0.0f, 0.0f);
    glHint (GL_TRANSFORM_HINT_APPLE, GL_FASTEST);
    _needsReshape = YES;
}

// Scrolled, moved or resized
- (void)reshape
{
	_needsReshape = YES;
}

#pragma mark -

// trigger the rendering
- (void)timerFired: (id)sender
{
	[self setNeedsDisplay: YES];
}

- (void)transTimerFired: (id)sender
{
	WebView *aWebView;
	CGSize imgSize = [sourceImage extent].size;
	NSRect bounds = [self bounds];
	NSRect imgRect = NSMakeRect(0, bounds.size.height-imgSize.height, bounds.size.width, bounds.size.height);
	NSBitmapImageRep *imageRep;
    CIFilter  *transition, *crop;
	
	// Randomly set the trasition index
	currentTransitionIndex = random() % 8;
    transition = [transitions objectAtIndex:currentTransitionIndex];
	
	aWebView = [webContent objectAtIndex:currentWebViewIndex];
	
	if (isWebViewLoadComplete) {
		[self setSourceImage:targetImage];
		imageRep = [aWebView bitmapImageRepForCachingDisplayInRect:bounds];
		[aWebView cacheDisplayInRect:bounds toBitmapImageRep:imageRep];
		[self setTargetImage:[CIImage imageWithData:[imageRep TIFFRepresentation]]];
		current = 0;
		
		// Update page content periodically
		transitionCounter++;
		if (transitionCounter >= 5) {
			transitionCounter = 0;
			[aWebView reload:self];
		}
		
		// Increment to next slide (wraps at end)
		if (currentWebViewIndex < ([webContent count] - 1)) {
			currentWebViewIndex++;
		} else {
			currentWebViewIndex = 0;
		}
		
		// Set the images for transition effect
		[transition setValue: sourceImage  forKey: @"inputImage"];
		[transition setValue: targetImage  forKey: @"inputTargetImage"];
		
		// Begin tranistioning
		current = 0;
		isTransitioning = YES;
	}
	
	[self setNeedsDisplay:YES];
}

#pragma mark -

- (void)keyDown:(NSEvent *)theEvent
{
    // Delegate to our controller object for handling key events.
    [controller keyDown:theEvent];
}

- (void)drawRect: (NSRect)rectangle
{
	NSRect bounds = [self bounds];
    [[self openGLContext] makeCurrentContext];
	
    CGPoint origin = CGPointZero;
    CGRect  imageFrame, displayRect;
    float   t;
	
    if (_needsReshape) {
		// reset the views coordinate system when the view has been resized or scrolled
		[self setViewportRect:[self visibleRect]];
    }
	
    if (_context == nil) {
		NSOpenGLPixelFormat *pf;
		
		pf = [self pixelFormat];
		if (pf == nil)
			pf = [[self class] defaultPixelFormat];
		
		_context = [[CIContext contextWithCGLContext: CGLGetCurrentContext()
										 pixelFormat: [pf CGLPixelFormatObj] options: nil] retain];
    }
    
    // fill the view black
    glColor4f (0.0f, 0.0f, 0.0f, 0.0f);
    glBegin(GL_POLYGON);
	glVertex2f (rectangle.origin.x, rectangle.origin.y);
	glVertex2f (rectangle.origin.x + rectangle.size.width, rectangle.origin.y);
	glVertex2f (rectangle.origin.x + rectangle.size.width, rectangle.origin.y + rectangle.size.height);
	glVertex2f (rectangle.origin.x, rectangle.origin.y + rectangle.size.height);
    glEnd();
    
    t = 0.4*([NSDate timeIntervalSinceReferenceDate] - base);
	
    // draw the transition
    imageFrame = CGRectMake(0, 0, bounds.size.width, bounds.size.height);
	displayRect.origin = origin;
	displayRect.size = imageFrame.size;
	displayRect = CGRectIntersection (displayRect, *(CGRect*)&rectangle);
	if((displayRect.size.width > 0) && (displayRect.size.height > 0))	// only draw the transitions that are in the visible area to increase performance
		[_context drawImage: [self imageForTransition:currentTransitionIndex atTime:current]  atPoint: origin  fromRect: displayRect];
    
	if (current < 1.0) {
		current += 0.05;
	} else {
		current = 1;
	}
	
    glFlush();
}

@end
