//
//  GlobeView.h
//  Globe
//
//  Created by John Brewer on 8/16/13.
//  Copyright (c) 2013 Jera Design LLC. All rights reserved.
//

#import <GLKit/GLKit.h>

#define SANTA_CRUZ 1

#ifdef SANTA_CRUZ
#define INITIAL_ROTATION (121.92119)
#define INITIAL_TILT 37.37696
#else
#define INITIAL_ROTATION -90.0
#define INITIAL_TILT 10.0
#endif

@interface GlobeView : GLKView<GLKViewControllerDelegate>

-(void)setupGL;
-(void)tearDownGL;

@end
