//
//  GlobeAppDelegate.m
//  Globe
//
//  Copyright Jera Design LLC 2009. All rights reserved.
//

#import "GlobeAppDelegate.h"
#import "EAGLView.h"

double tilt0 = INITIAL_TILT;
double tilt1 = INITIAL_TILT;
double tilt2 = INITIAL_TILT;
double tilt3 = INITIAL_TILT;
double tilt4 = INITIAL_TILT;

@implementation GlobeAppDelegate

@synthesize window;
@synthesize glView;

- (void)applicationDidFinishLaunching:(UIApplication *)application {

	glView.animationInterval = 1.0 / 60.0;
	[glView startAnimation];
  [self configureAccelerometer];
}


- (void)applicationWillResignActive:(UIApplication *)application {
	glView.animationInterval = 1.0 / 5.0;
}


- (void)applicationDidBecomeActive:(UIApplication *)application {
	glView.animationInterval = 1.0 / 60.0;
}

- (void)accelerometer:(UIAccelerometer *)accelerometer didAccelerate:(UIAcceleration *)acceleration
{
  UIAccelerationValue z = acceleration.z;
  
  // Do something with the values.
  tilt4 = tilt3;
  tilt3 = tilt2;
  tilt2 = tilt1;
  tilt1 = tilt0;
  tilt0 = -90 * z;
  glView->tilt = (tilt0 + tilt1 + tilt2 + tilt3) / 4;
//  printf("x = %f, y = %f, z = %f\n", x, y, z);
}

#define kAccelerometerFrequency        50 //Hz
- (void)configureAccelerometer
{
  UIAccelerometer*  theAccelerometer = [UIAccelerometer sharedAccelerometer];
  theAccelerometer.updateInterval = 1 / kAccelerometerFrequency;
  
  theAccelerometer.delegate = self;
}

- (void)dealloc {
	[window release];
	[glView release];
	[super dealloc];
}

@end
