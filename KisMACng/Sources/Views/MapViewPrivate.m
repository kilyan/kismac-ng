/*
        
        File:			MapViewPrivate.m
        Program:		KisMAC
	Author:			Michael Roßberg
				mick@binaervarianz.de
	Description:		KisMAC is a wireless stumbler for MacOS X.
                
        This file is part of KisMAC.

    KisMAC is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    KisMAC is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with KisMAC; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*/

#import "MapViewPrivate.h"
#import "MapView.h"
#import "WaveHelper.h"
#import "NetView.h"
#import "BITextView.h"
#import "MapControlPanel.h"
#import "GPSController.h"
#import "PointView.h"

@implementation MapView(Private)

- (void)_align {
    NSPoint loc;
    
    loc.x = -_center.x * _zoomFact + (_frame.size.width / 2);
    loc.y = -_center.y * _zoomFact + (_frame.size.height / 2);
    
    [_moveContainer setLocation:loc];
}

- (void)_alignStatus {
    NSPoint loc;
    
    loc.x = (_frame.size.width - [_statusView size].width)  / 2;
    loc.y = (_frame.size.height- [_statusView size].height) / 2;
    [_statusView setLocation:loc];
}

- (void)_alignControlPanel {
    NSPoint loc;
    
    loc.x =  (_frame.size.width - [_controlPanel size].width - 5);
    loc.y = 5;
    [_controlPanel setLocation:loc];
}

- (void)_alignNetworks {
    int i;
    NSArray *subviews;
    
    subviews = [_netContainer subViews];
    for (i = 0; i < [subviews count]; i++) {
        NSObject *o = [subviews objectAtIndex:i];
        if ([o isMemberOfClass:[NetView class]]) [(NetView*)o align];
    }
    [self _alignCurrentPos];
    [self _align];
}

- (void)_alignCurrentPos {
    NSPoint wp;
    if (_selmode != selCurPos && _selmode != selShowCurPos) return;
    wp = [self pixelForCoordinate:[[WaveHelper gpsController] currentPoint]];
    if (wp.x != INVALIDPOINT.x || wp.y != INVALIDPOINT.y) {
        [_pView setLocation:wp];
        [_pView setVisible:YES];
    } else {
        [_pView setVisible:NO];    
    }
}

- (void)_setStatus:(NSString*)status {
    NSMutableDictionary* attrs = [[[NSMutableDictionary alloc] init] autorelease];
    NSFont* textFont = [NSFont fontWithName:@"Monaco" size:16];
    NSColor *col = [NSColor redColor];
    
    [WaveHelper secureReplace:&_gpsStatus withObject:status];
    
    [attrs setObject:textFont forKey:NSFontAttributeName];
    [attrs setObject:col forKey:NSForegroundColorAttributeName];
    
    NSAttributedString *a = [[[NSAttributedString alloc] initWithString:_gpsStatus attributes:attrs] autorelease];
    [_statusView setString:a];
    [_statusView setBorderColor:col];
    [_statusView setBackgroundColor:[NSColor colorWithDeviceRed:0.3 green:0 blue:0 alpha:0.5]];
    
    [self _alignStatus];
    if (_visible) [self setNeedsDisplay:YES];
}

#pragma mark -

- (void)_updateStatus {
    if (!_mapImage) {
        [_statusView setVisible:YES];
        [self _setStatus:NSLocalizedString(@"No map loaded! Please import or load one first.", "map view status")];
    } else if (_wp[selWaypoint1]._lat == 0 && _wp[selWaypoint1]._long == 0) {
        [_statusView setVisible:YES];
        [self _setStatus:NSLocalizedString(@"Waypoint 1 is not set!", "map view status")];
    } else if (_wp[selWaypoint2]._lat == 0 && _wp[selWaypoint2]._long == 0) {
        [_statusView setVisible:YES];
        [self _setStatus:NSLocalizedString(@"Waypoint 2 is not set!", "map view status")]; 
    } else if (abs(_point[selWaypoint1].x - _point[selWaypoint2].x) < 5 || abs(_point[selWaypoint1].y - _point[selWaypoint2].y) < 5) {
        [_statusView setVisible:YES];
        [self _setStatus:NSLocalizedString(@"The waypoints are too close!", "map view status")]; 
    } else if (fabs(_wp[selWaypoint1]._lat - _wp[selWaypoint2]._lat) < 0.001 || fabs(_wp[selWaypoint1]._long - _wp[selWaypoint2]._long) < 0.001) {
        [_statusView setVisible:YES];
        [self _setStatus:NSLocalizedString(@"The coordinates of waypoints are too close!", "map view status")]; 
    } else {
        [_statusView setVisible:NO];
        if (_visible) [self setNeedsDisplay:YES];
    }
}

- (void)_setGPSStatus:(NSString*)status {
    NSMutableDictionary* attrs = [[[NSMutableDictionary alloc] init] autorelease];
    NSFont* textFont = [NSFont fontWithName:@"Monaco" size:12];
    NSColor *grey = [NSColor whiteColor];
    
    [WaveHelper secureReplace:&_gpsStatus withObject:status];
    
    [attrs setObject:textFont forKey:NSFontAttributeName];
    [attrs setObject:grey forKey:NSForegroundColorAttributeName];
    
    NSAttributedString *a = [[[NSAttributedString alloc] initWithString:_gpsStatus attributes:attrs] autorelease];
    [_gpsStatusView setString:a];
    [_gpsStatusView setBorderColor:grey];
    [_gpsStatusView setBackgroundColor:[[NSColor darkGrayColor] colorWithAlphaComponent:0.5]];
    
    if (_visible) [self setNeedsDisplay:YES];
}

- (void)_updateGPSStatus:(NSNotification*)note {
    if ([(NSString*)[note object] compare:_gpsStatus] == NSOrderedSame) return;
    [self _setGPSStatus:[note object]];
    [self _alignCurrentPos];
}

@end