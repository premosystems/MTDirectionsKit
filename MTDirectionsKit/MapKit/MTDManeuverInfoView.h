//
//  MTDManeuverInfoView.h
//  MTDirectionsKit
//
//  Created by Matthias Tretter on 21.01.12.
//  Copyright (c) 2012 Matthias Tretter (@myell0w). All rights reserved.
//


@interface MTDManeuverInfoView : UIView

@property (nonatomic, copy) NSString *infoText;

+ (MTDManeuverInfoView *)infoViewForMapView:(MKMapView *)mapView;

@end
