//
//  MKMapView+MTDirections.h
//  MTDirections
//
//  Created by Matthias Tretter on 21.01.11.
//  Copyright (c) 2009-2012  Matthias Tretter, @myell0w. All rights reserved.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"),
// to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense,
// and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
// WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

#import "MTDirectionsOverlay.h"

@interface MKMapView (MTDirections)

/** all waypoints of the current active direction */
@property (nonatomic, strong) NSArray *waypoints;
/** the current active direction overlay */
@property (nonatomic, strong) MTDirectionsOverlay *directionsOverlay;
/** the color of the current active overlay */
@property (nonatomic, strong) UIColor *directionsOverlayColor;

/**
 Starts a request and loads the directions between the specified coordinates.
 When the request is finished the directionOverlay gets set on the MapView and
 the region gets set to show the overlay, if the flag zoomToShowDirections is set.
 
 @param fromCoordinate the start point of the direction
 @param toCoordinate the end point of the direction
 @param zoomToShowDirections flag whether the mapView gets zoomed to show the overlay (gets zoomed animated)
 */
- (void)loadDirectionsFrom:(CLLocationCoordinate2D)fromCoordinate
                        to:(CLLocationCoordinate2D)toCoordinate
      zoomToShowDirections:(BOOL)zoomToShowDirections;

/**
 Sets the region of the MapView to show the whole directionOverlay at once.
 
 @param animated flag whether the region gets set animated
 */
- (void)setRegionToShowDirectionsAnimated:(BOOL)animated;

/**
 Returns a corresponding overlayView for the given directionsOverlay.
 If there is no overlay set yet or overlay is not kind of MTDirectionsOverlay
 this method returns nil
 
 @param overlay the overlay to return the corresponding view, must be a subclass of MTDirectionsOverlay
 @return an overlay view or nil
 */
- (MKOverlayView *)viewForDirectionsOverlay:(id<MKOverlay>)overlay;

@end