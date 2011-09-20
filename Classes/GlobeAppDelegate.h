//
//  GlobeAppDelegate.h
//  Globe
//
//  Copyright Jera Design LCC 2009. All rights reserved.
//

#import <UIKit/UIKit.h>

@class EAGLView;

@interface GlobeAppDelegate : NSObject <UIApplicationDelegate, UIAccelerometerDelegate> {
  IBOutlet UIWindow *window;
  IBOutlet EAGLView *glView;
}

@property (nonatomic, retain) UIWindow *window;
@property (nonatomic, retain) EAGLView *glView;

-(void)configureAccelerometer;

@end

