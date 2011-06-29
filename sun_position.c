//
//  sun_position.c
//  Globe
//
//  Created by John Brewer on 6/26/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#include "sun_position.h"
#include <CoreFoundation/CoreFoundation.h>

#define SECONDS_PER_YEAR (60.0 * 60.0 * 24.0 * 365.242191)
#define PI 3.141592653589793

static double julean_date(int year, int month, double day) {
  if ((month == 1) || (month == 2)) {
    year -= 1;
    month += 12;
  }
  int A = year / 100;
  int B = 2 - A + (A / 4);
  int C = 365.25 * year;
  int D = 30.6001 * (month + 1);
  double jd = B + C + D + day + 1720994.5;
  return jd;
}

static double sidereal_time(CFAbsoluteTime time) {
  CFGregorianDate gdate = CFAbsoluteTimeGetGregorianDate(time, NULL);
//  CFGregorianDate gdate;
//  gdate.year = 1980;
//  gdate.month = 4;
//  gdate.day = 22;
//  gdate.hour = 14;
//  gdate.minute = 36;
//  gdate.second = 51.67;

  double jd = julean_date(gdate.year, gdate.month, gdate.day);
  double S = jd - 2451545.0;
  double T = S / 36525.0;
  double T0 = 6.697374558 + (2400.051336 * T) + (0.000025862 * T * T);
  while (T0 < 0) {
    T0 += 24;
  }
  while (T0 > 24) {
    T0 -= 24;
  }
  double UT = gdate.hour + gdate.minute / 60.0 + gdate.second / 3600.0;
  double GST = UT * 1.002737909;
  GST += T0;
  if (GST < 0) {
    GST += 24;
  } else if (GST > 24) {
    GST -= 24;
  }
  return GST * 15;
}

void sun_position(float positionVector[3]) {
  CFAbsoluteTime now = CFAbsoluteTimeGetCurrent();
  
  CFGregorianDate gdate;
  
//  gdate.year = 2011;
//  gdate.month = 12;
//  gdate.day = 22;
//  gdate.hour = 6;
//  gdate.minute = 0;
//  gdate.second = 0.0;
//  now = CFGregorianDateGetAbsoluteTime(gdate, NULL);
  
  gdate.year = 1989;
  gdate.month = 12;
  gdate.day = 31;
  gdate.hour = 0;
  gdate.minute = 0;
  gdate.second = 0.0;
  CFAbsoluteTime epoch = CFGregorianDateGetAbsoluteTime(gdate, NULL);
  
  CFTimeInterval delta = now - epoch;
  double years = delta / SECONDS_PER_YEAR;
  years = fmod(years, 1);
//  printf("years = %f\n", years);
  
  double angle = 360.0 * years;
  angle += 279.403303 - 282.768422;
  angle += 360.0;
  angle = fmod(angle, 360.0);
//  printf("angle = %f\n", angle);
  double v = angle + (360 / PI) * 0.016713 * sin((2.0 * PI) * (angle / 360.0));
  v += 282.768422;
  v = fmod(v, 360.0);
//  printf("v = %f\n", v);
  double lambda = (2.0 * PI) * v / 360.0;
  double obliquity = (2.0 * PI) * 23.441884 / 360.0;
  
  double alpha = atan2(sin(lambda) * cos(obliquity), cos(lambda));
  double beta = asin(sin(obliquity) * sin(lambda));
  
  alpha += 2.0 * PI * sidereal_time(now) / 360.0;
  alpha += PI / 2;
//  double alphaDegrees = 360.0 * alpha / (2 * PI);
//  alpha = 360.0 * alpha / (2.0 * PI);
//  if (alpha < 0.0) { alpha += 360.0; }
//  beta = 360.0 * beta / (2.0 * PI);
//  
//  printf("alpha = %f\n", alpha);
//  printf("beta = %f\n", beta);
  
  positionVector[0] = cos(alpha);
  positionVector[2] = sin(alpha);
  positionVector[1] = sin(beta);
//  now += 3600;
  return;
}