/*
        
        File:			ScanController.m
        Program:		KisMAC
	Author:			Michael Ro�berg
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
#import "ScanController.h"
#import "ScanControllerPrivate.h"
#import "ScanControllerScriptable.h"
#import "WaveHelper.h"
#import "GPSController.h"
#import "WaveClient.h"
#import "../WindowControllers/CrashReportController.h"
#import "../Controller/TrafficController.h"
#import "WaveContainer.h"
#import "../WaveDrivers/WaveDriver.h"
#import "ScriptController.h"
#import "SpinChannel.h"
#import <sys/sysctl.h>
#import <BIGeneric/BIGeneric.h>
#import <BIGL/BIGL.h>

NSString *const KisMACViewItemChanged       = @"KisMACViewItemChanged";
NSString *const KisMACCrackDone             = @"KisMACCrackDone";
NSString *const KisMACAdvNetViewInvalid     = @"KisMACAdvNetViewInvalid";
NSString *const KisMACModalDone             = @"KisMACModalDone";
NSString *const KisMACFiltersChanged        = @"KisMACFiltersChanged";
NSString *const KisMACStopScanForced        = @"KisMACStopScanForced";
NSString *const KisMACNetworkAdded          = @"KisMACNetworkAdded";
NSString *const KisMACUserDefaultsChanged   = @"KisMACUserDefaultsChanged";
NSString *const KisMACTryToSave             = @"KisMACTryToSave";
NSString *const KisMACGPSStatusChanged      = @"KisMACGPSStatusChanged";

@implementation ScanController
+ (void)initialize {
    id registrationDict = nil ;

    registrationDict = [NSDictionary dictionaryWithObjectsAndKeys:
        [NSNumber numberWithFloat: 0.25], @"frequence",
        [NSNumber numberWithFloat: 0.25], @"activeScanInterval",
        [NSNumber numberWithBool:NO], @"ScanAtStartUp",
        [NSNumber numberWithBool:NO], @"dontAskToSave",
        [NSNumber numberWithBool:YES], @"terminateIfClosed",
        [NSNumber numberWithBool:NO], @"disableSleepMode",
        [NSNumber numberWithInt:250], @"GeigerSensity",
        [NSNumber numberWithInt:0], @"Voice",
        [WaveHelper colorToInt:[NSColor redColor]], @"CurrentPositionColor",
        [WaveHelper colorToInt:[NSColor redColor]], @"TraceColor",
        [WaveHelper colorToInt:[NSColor blueColor]], @"WayPointColor",
        [WaveHelper colorToInt:[[NSColor greenColor] colorWithAlphaComponent:0.5]], @"NetAreaColorGood",
        [WaveHelper colorToInt:[[NSColor redColor] colorWithAlphaComponent:0.5]], @"NetAreaColorBad",
        [NSNumber numberWithFloat:5.0], @"NetAreaQuality",
        [NSNumber numberWithInt:30], @"NetAreaSensitivity",
        @"None", @"WEPSound",
        @"None", @"noWEPSound",
        @"None", @"GeigerSound",
        @"", @"GPSDevice",
        [NSNumber numberWithInt:2], @"GPSTrace",
        [NSNumber numberWithInt:0], @"GPSNoFix",
        [NSNumber numberWithBool:NO], @"GPSTripmate",
        @"3", @"DownloadMapScale",
        @"<Select a Server>", @"DownloadMapServer",
        [NSNumber numberWithInt:1024], @"DownloadMapWidth",
        [NSNumber numberWithInt:768], @"DownloadMapHeight",
        [NSNumber numberWithFloat:0.0], @"DownloadMapLatitude",
        [NSNumber numberWithFloat:0.0], @"DownloadMapHLongitude",
        @"N", @"DownloadMapNS",
        @"E", @"DownloadMapEW",
        [NSNumber numberWithInt:1], @"TrafficViewShowSSID",
        [NSNumber numberWithInt:0], @"TrafficViewShowBSSID",
        [NSArray array], @"FilterBSSIDList",
        [NSNumber numberWithInt:2947], @"GPSDaemonPort",
        @"localhost", @"GPSDaemonHost",
        [NSNumber numberWithInt:0], @"DebugMode",
        [NSNumber numberWithInt:2], @"WaveNetAvgTime",
        [NSArray array], @"ActiveDrivers",
        [NSNumber numberWithBool: NO], @"useWebService",
        [NSNumber numberWithBool: NO], @"useWebServiceAutomatically",
        @"", @"webServiceAccount",
        nil];

    [[NSUserDefaults standardUserDefaults] registerDefaults:registrationDict];
}

-(id) init {
    self=[super init];
    if (self==Nil) return Nil;

    aNetHierarchVisible = NO;
    _visibleTab = tabNetworks;
    [_window setDocumentEdited:NO];
    _refreshGUI = YES;
    aMS = Nil;
    _zoomToRect = NSZeroRect;
    _importOpen = 0;
    
    return self;
}

-(void)awakeFromNib {
    static BOOL alreadyAwake = NO;
    NSUserDefaults *sets;

    if(!alreadyAwake)
        alreadyAwake = YES;
    else
        return;

    [WaveHelper setScanController:self];
    [_headerField setStringValue:[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"]];
    
    [ScanHierarch setContainer:_container];
    [WaveHelper setMainWindow:_window];
    [WaveHelper setMapView:_mappingView];
    _visibleTab = tabInvalid;
    [self showNetworks];
    
    [_showNetworks setImage: [NSImage imageNamed:@"networks-button.tif"]];
    [_showTraffic  setImage: [NSImage imageNamed:@"traffic-button.tif"]];
    [_showMap      setImage: [NSImage imageNamed:@"map-button.tif"]];
    [_showDetails  setImage: [NSImage imageNamed:@"details-button.tif"]];
    
    [_networkTable setDoubleAction:@selector(showClient:)];
    [_window makeFirstResponder:_networkTable]; //select the network table not the search box
    
    [self menuSetEnabled:NO menu:aNetworkMenu];
    [[_showNetInMap menu] setAutoenablesItems:NO];
    [_showNetInMap setEnabled:NO];
    [_trafficTimePopUp setHidden:YES];
    [_trafficModePopUp setHidden:YES];
  
    sets=[NSUserDefaults standardUserDefaults];
    
    if ([[sets objectForKey:@"DebugMode"] intValue] != 1) [[_debugMenu menu] removeItem:_debugMenu];

    [_window makeKeyAndOrderFront:self];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateViewItems:)     name:KisMACViewItemChanged      object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(modalDone:)           name:KisMACCrackDone            object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(advNetViewInvalid:)   name:KisMACAdvNetViewInvalid    object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(modalDone:)           name:KisMACModalDone            object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(stopScanForced:)      name:KisMACStopScanForced       object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkAdded:)        name:KisMACNetworkAdded         object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updatePrefs:)         name:KisMACUserDefaultsChanged  object:nil];

    NSLog(@"KiMAC startup done. Homedir is %s NSAppKitVersionNumber: %f",[[[NSBundle mainBundle] bundlePath] fileSystemRepresentation], NSAppKitVersionNumber);
    [sets setObject:[[[NSBundle mainBundle] bundlePath] stringByAbbreviatingWithTildeInPath] forKey:@"KisMACHomeDir"];
}

#pragma mark -

//#define USEPASTEOUT
- (IBAction)updateNetworkTable:(id)sender complete:(bool)complete {
#ifndef USEPASTEOUT    
    int row;
    int i;

    if ([_container count]!=[_networkTable numberOfRows]) complete = YES;

    [_channelProg setChannel:[[WaveHelper driverWithName:_whichDriver] getChannel]];

    if (_visibleTab == tabTraffic) {
        [_trafficController updateGraph];
    } else if (_visibleTab == tabNetworks) {
        if (_lastSorted) [_container sortWithShakerByColumn:_lastSorted order:_ascending];
        
        if (complete) {
            [_networkTable reloadData];
            if (_detailsPaneVisibile) [aInfoController reloadData];
            if ([_container netAtIndex:_selectedRow] != _curNet) { //we lost our selected network
                for (i = [_container count]; i>=0; i--)
                if ([_container netAtIndex:i] == _curNet) {
                    _selectedRow = i;
                    [_networkTable selectRow:i byExtendingSelection:NO];
                    break;
                }
            }
        }
        else {
            row = [_container nextChangedRow:0xFFFFFFFF];
            while (row != 0xFFFFFFFF) {
                if ([_container netAtIndex:row] == _curNet) {
                    if (_detailsPaneVisibile) [aInfoController reloadData];
                    _selectedRow = row;
                    [_networkTable selectRow:row byExtendingSelection:NO];
                }
                [_networkTable displayRect:[_networkTable rectOfRow:row]];
                row = [_container nextChangedRow:row];
            }
        }
    } else if (_visibleTab == tabDetails) {
        if (complete) {
            [aInfoController reloadData];
            if ([_container netAtIndex:_selectedRow] != _curNet) { //we lost our selected network
                for (i = [_container count]; i>=0; i--)
                if ([_container netAtIndex:i] == _curNet) {
                    _selectedRow = i;
                    [_networkTable selectRow:i byExtendingSelection:NO];
                    break;
                }
            }
        } else {
            row = [_container nextChangedRow:0xFFFFFFFF];
            while (row != 0xFFFFFFFF) {
                if ([_container netAtIndex:row] == _curNet) {
                    [aInfoController reloadData];
                    _selectedRow = row;
                    [_networkTable selectRow:row byExtendingSelection:NO];
                }
                row = [_container nextChangedRow:row];
            }
        }
    }
#else
    NSPasteboard *board;
    NSMutableString *outString;
    NSString *lineString;
    WaveNet *n;
    WaveClient *cl;
    unsigned int i, d;
    NSString *type;
    NSString *wep;
    NSDictionary *c;
    NSArray *k;
    
    board = [NSPasteboard pasteboardWithName:NSGeneralPboard];
    outString = [NSMutableString string];

    for(i=0; i<[nets count]; i++) {
        n = [aNets objectForKey:[nets objectAtIndex:i]];
        switch ([n isWep]) {
            case 4: wep = @"WPA";
            case 2: wep = @"YES";
            case 1: wep = @"NO";
            case 0: wep = @"NA";
        }
        switch ([n type]) {
            case 0: type =@"NA";
            case 1: type = @"ad-hoc";
            case 2: type = @"managed";
            case 3: type = @"tunnel";
            case 4: type = @"probe";
            case 5: type = @"lucent tunnel";
            default:
                NSAssert(NO, @"Network type invalid");
            }
    
        lineString = [NSString stringWithFormat:@"ap %i %@ %@ %@ %@ %@ %i %i %i %@ %@\n",[n channel],[n BSSID],[n SSID], type, wep, [n getVendor], [n curSignal],[n maxSignal], [n packets], [n data], [[n date] description]];
        [outString appendString:lineString];
        
        k = [n getClientKeys];
        c = [n getClients];
        for(d=0;d<[k count];d++) {
            wep = [k objectAtIndex:d];
            cl = [c objectForKey:wep];
            lineString = [NSString stringWithFormat:@"client %@ %@ %@ %@ %i %@\n", wep, [cl vendor], [cl sent], [cl recieved], [cl curSignal], [[cl date] description] ];
            [outString appendString:lineString];
        }
    }
    lineString = [board stringForType:NSStringPboardType];
    [board declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    [board setString:outString forType:NSStringPboardType];
#endif    
}

- (void)updateViewItems:(NSNotification*)note {
    if (!_refreshGUI) return;
    [self performSelectorOnMainThread:@selector(doUpdateViewItems:) withObject:nil waitUntilDone:NO];
}

- (void)doUpdateViewItems:(id)anObject {
    [_container refreshView];
    if (_lastSorted) [_container sortWithShakerByColumn:_lastSorted order:_ascending];
    
    if (aNetHierarchVisible) {
        [ScanHierarch updateTree];
        [aOutView reloadData];
    }
}

#pragma mark -

- (void)stopScanForced:(NSNotification*)note {
    [self stopScan];
}

#pragma mark -

- (id) tableView:(NSTableView *)aTableView objectValueForTableColumn:(NSTableColumn *) aTableColumn row:(int) rowIndex {
    WaveNet *net = [_container netAtIndex:rowIndex];
    NSString *s = [aTableColumn identifier];
    
    if ([s isEqualToString:@"id"]) return [NSString stringWithFormat:@"%i", [net netID]];
    if ([s isEqualToString:@"ssid"]) return [net SSID];
    if ([s isEqualToString:@"bssid"]) return [net BSSID];
    if ([s isEqualToString:@"lastseen"]) return [net date];
    if ([s isEqualToString:@"signal"]) return [NSString stringWithFormat:@"%i", [net curSignal]];
    if ([s isEqualToString:@"avgsignal"]) return [NSString stringWithFormat:@"%i", [net avgSignal]];
    if ([s isEqualToString:@"maxsignal"]) return [NSString stringWithFormat:@"%i", [net maxSignal]];
    if ([s isEqualToString:@"channel"]) return [NSString stringWithFormat:@"%i", [net channel]];
    if ([s isEqualToString:@"packets"]) return [NSString stringWithFormat:@"%i", [net packets]];
    if ([s isEqualToString:@"data"]) return [net data];
    if ([s isEqualToString:@"wep"]) {
        switch ([net wep]) {
            case encryptionTypeLEAP:    return NSLocalizedString(@"LEAP", "table description");
            case encryptionTypeWPA:     return NSLocalizedString(@"WPA", "table description");
            case encryptionTypeWEP40:   return NSLocalizedString(@"WEP-40", "table description");
            case encryptionTypeWEP:     return NSLocalizedString(@"WEP", "table description");
            case encryptionTypeNone:    return NSLocalizedString(@"NO", "table description");
            case encryptionTypeUnknown: return @"";
            default:
                NSAssert(NO, @"Encryption type invalid");
        }
    }
    if ([s isEqualToString:@"type"]) {
        switch ([net type]) {
            case 0: return @"";
            case 1: return NSLocalizedString(@"ad-hoc", "table description");
            case 2: return NSLocalizedString(@"managed", "table description");
            case 3: return NSLocalizedString(@"tunnel", "table description");
            case 4: return NSLocalizedString(@"probe", "table description");
            case 5: return NSLocalizedString(@"lucent tunnel", "table description");
            default:
                NSAssert(NO, @"Network type invalid");
        }
    }
    return @"unknown row";
}

- (int)numberOfRowsInTableView:(NSTableView *)aTableView {
    return [_container count];
}

- (void)tableViewSelectionDidChange:(NSNotification *)aNotification {
    if ([_networkTable selectedRow]<0) [self hideDetails]; 
    else [self selectNet:[_container netAtIndex:[_networkTable selectedRow]]];
}

- (void)tableView:(NSTableView*)tableView mouseDownInHeaderOfTableColumn:(NSTableColumn *)tableColumn {
    NSString *ident = [tableColumn identifier];
    
    if(![tableView isEqualTo:_networkTable]) return;

    if ((_lastSorted) && ([_lastSorted isEqualToString:ident])) {
        if (_ascending) _ascending=NO;
        else {
            [_lastSorted release];
            _lastSorted = Nil;
            [tableView setIndicatorImage:Nil inTableColumn:tableColumn];
            [tableView setHighlightedTableColumn:Nil];
            [tableView reloadData];
            return;
        }
    } else {
        _ascending=YES;
        if (_lastSorted) {
            [tableView setIndicatorImage:nil inTableColumn:[tableView tableColumnWithIdentifier:_lastSorted]];
            [_lastSorted release];
        }
        _lastSorted=[ident retain];
    }
    
    if (_ascending)
        [tableView setIndicatorImage:[NSImage imageNamed:@"NSAscendingSortIndicator"] inTableColumn:tableColumn];
    else 
        [tableView setIndicatorImage:[NSImage imageNamed:@"NSDescendingSortIndicator"] inTableColumn:tableColumn];
    [tableView setHighlightedTableColumn:tableColumn];
    
    [self updateNetworkTable:self complete:YES];
}

#pragma mark -

- (int)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item {
    return (item == nil) ? 3 : [item numberOfChildren];
}
- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item {
    return ([item numberOfChildren] != -1);
}
- (id)outlineView:(NSOutlineView *)outlineView child:(int)index ofItem:(id)item {
    if (item!=Nil) return [item childAtIndex:index];
    else {
        return [ScanHierarch rootItem:_container index:index];
    }
}
- (id)outlineView:(NSOutlineView *)outlineView objectValueForTableColumn:(NSTableColumn *)tableColumn byItem:(id)item {
    return (item == nil) ? nil : (id)[item nameString];
}
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldEditTableColumn:(NSTableColumn *)tableColumn item:(id)item {
    return NO;
}
- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item {
    unsigned int tmpID[6], i;
    unsigned char ID[6];
    if (item==nil) return YES;
    
    switch ([(ScanHierarch*)item type]) {
        case 99: //BSSID selector
            if (sscanf([[item identKey] cString], "%2X%2X%2X%2X%2X%2X", &tmpID[0], &tmpID[1], &tmpID[2], &tmpID[3], &tmpID[4], &tmpID[5])!=6) 
                NSLog(@"Error could not decode ID %@!", [item identKey]);
            for (i=0; i<6; i++) ID[i] = tmpID[i];
            
            [self showDetailsFor:[_container netForKey:ID]];
            break;
        case 1: //topitems
        case 2:
        case 36:
            [self hideDetails];
            [_container setViewType:0 value:nil];
            if (_lastSorted) [_container sortByColumn:_lastSorted order:_ascending];
            break;
        case 3: //SSID selectors
            [self hideDetails];
            [_container setViewType:2 value:[(ScanHierarch*)item nameString]];
            if (_lastSorted) [_container sortByColumn:_lastSorted order:_ascending];
            break;
        case 37: //Crypto selectors
        case 38:
        case 40:
        case 41:
            [self hideDetails];
            [_container setViewType:3 value:[NSNumber numberWithInt:[(ScanHierarch*)item type]-36]];
            if (_lastSorted) [_container sortByColumn:_lastSorted order:_ascending];
            break;
        default: //channel selectors left
            [self hideDetails];
            [_container setViewType:1 value:[NSNumber numberWithInt:[(ScanHierarch*)item type]-20]];
            if (_lastSorted) [_container sortByColumn:_lastSorted order:_ascending];
    }
    [_networkTable reloadData];
    return YES;
}

#pragma mark -

- (IBAction)showInfo:(id)sender {
    NSSize contentSize;
    
    if (_detailsPaneVisibile) {
        [_detailsDrawer close];
        [sender setTitle: NSLocalizedString(@"Show Details", "menu item")];
        _detailsPaneVisibile = NO;

        return;
    }
    if (_visibleTab == tabDetails) return;
    
    if (!_detailsDrawer) {
        contentSize = NSMakeSize(200, 250);
        _detailsDrawer = [[NSDrawer alloc] initWithContentSize:contentSize preferredEdge:NSMaxXEdge];
        [_detailsDrawer setParentWindow:_window];
        [_detailsDrawer setContentView:detailsView];
        [_detailsDrawer setMinContentSize:NSMakeSize(50, 50)];

        [_detailsDrawer setLeadingOffset:50];
        [_detailsDrawer setTrailingOffset:[_window frame].size.height-300];

        [_detailsDrawer setMaxContentSize:NSMakeSize(200, 300)];
    }
    
    [aInfoController setDetails:YES];
    [_detailsDrawer openOnEdge:NSMaxXEdge];
    [sender setTitle: NSLocalizedString(@"Hide Details", "menu item")];
    _detailsPaneVisibile = YES;
}

- (IBAction)showClient:(id)sender {
    if ([_networkTable selectedRow]>=0) [self showDetailsFor:[_container netAtIndex:[_networkTable selectedRow]]];
}

- (IBAction)showNetHierarch:(id)sender {
    if (!aNetHierarchVisible) {
        [sender setTitle: NSLocalizedString(@"Hide Hierarchy", "menu item")];
        [_netHierarchDrawer openOnEdge:NSMinXEdge];
        
        [ScanHierarch updateTree];
        [aOutView reloadData];
    } else {
        [sender setTitle: NSLocalizedString(@"Show Hierarchy", "menu item. needs to be same as MainMenu.nib")];
        [_netHierarchDrawer close];
    }
    aNetHierarchVisible =! aNetHierarchVisible;
    [_showHierarch setState: aNetHierarchVisible ? NSOnState : NSOffState];
}

- (IBAction)changeSearchValue:(id)sender {
    [_container setFilterString:[_searchField stringValue]];
    [_networkTable reloadData];
}

#pragma mark -

-(void) dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];

    [_importController stopAnimation];
    [_importController release];
    [aStatusItem release];
    [aStatusBar release];
    [_fileName release];

    [super dealloc];
}

#pragma mark -

#pragma mark Application delegates

- (BOOL)application:(NSApplication *)theApplication openFile:(NSString *)filename {
    return [self open:filename];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender {    
    if (![self isSaved]) {
        [self showWantToSaveDialog:@selector(reallyQuitDidEnd:returnCode:contextInfo:)];
        return NSTerminateLater;
    }
    
    return NSTerminateNow;
}

- (void)reallyQuitDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    switch (returnCode) {
    case NSAlertOtherReturn:
        [NSApp replyToApplicationShouldTerminate:NO];
        break;
    case NSAlertDefaultReturn:
        [NSNotificationCenter postNotification:KisMACTryToSave];
    case NSAlertAlternateReturn:
    default:        
        [NSApp replyToApplicationShouldTerminate:YES];
    }
}

- (void)applicationDidFinishLaunching:(NSNotification *)aNotification {
    NSString* crashPath;
    NSFileManager *mang;
    NSUserDefaults *sets;
 
    [self updatePrefs:nil];
    sets=[NSUserDefaults standardUserDefaults];

    crashPath = [@"~/Library/Logs/CrashReporter/KisMAC.crash.log" stringByExpandingTildeInPath];
    mang = [NSFileManager defaultManager];
    
    if ([[sets objectForKey:@"SupressCrashReport"] intValue]!=1 && [mang fileExistsAtPath:crashPath] && [[[mang fileAttributesAtPath:crashPath traverseLink:NO] objectForKey:NSFileSize] intValue] != 0) {
        NSData *crashLog = [mang contentsAtPath:crashPath];
        CrashReportController* crc = [[CrashReportController alloc] initWithWindowNibName:@"CrashReporter"];
        [[crc window] setFrameUsingName:@"aKisMAC_CRC"];
        [[crc window] setFrameAutosaveName:@"aKisMAC_CRC"];
        
        [crc setReport:crashLog];
        [crc showWindow:self];
        [[crc window] makeKeyAndOrderFront:self];
        
        NSLog(@"crash occured the last time kismac started");
    }

}

- (void)applicationWillTerminate:(NSNotification *)notification {
    [self stopScan];
    [self stopActiveAttacks];
    [[WaveHelper gpsController] stop];
    if (aOurSleepMode) {
        [WaveHelper runScript:@"nosleep_disable.sh"];
    }
    [WaveHelper unloadAllDrivers];
}


#pragma mark Main Window delegates

- (NSRect)windowWillUseStandardFrame:(NSWindow *)sender defaultFrame:(NSRect)defaultFrame {
    if (aNetHierarchVisible) {
        defaultFrame.size.width-=[_netHierarchDrawer contentSize].width+10;
        defaultFrame.origin.x+=[_netHierarchDrawer contentSize].width+10;
    }
    if (_detailsPaneVisibile) {
        defaultFrame.size.width-=[_detailsDrawer contentSize].width+10;
        [_window setFrame:[_window frame] display:YES animate:YES];
    }
    
    return defaultFrame;
}

- (NSSize)windowWillResize:(NSWindow *)sender toSize:(NSSize)proposedFrameSize {
    [_detailsDrawer setTrailingOffset:proposedFrameSize.height-280];
    return proposedFrameSize;
}

- (BOOL)windowShouldClose:(id)sender {
    NSUserDefaults *sets = [NSUserDefaults standardUserDefaults];
    
    if ([sets boolForKey:@"terminateIfClosed"]) {
        if (![self isSaved]) {
            [self showWantToSaveDialog:@selector(reallyCloseDidEnd:returnCode:contextInfo:)];
            return NO;
        }
    
        [NSApp terminate:self];
        return YES;
    } else {
        [self new];
        return NO;
    }
}
- (void)reallyCloseDidEnd:(NSWindow *)sheet returnCode:(int)returnCode contextInfo:(void *)contextInfo {
    switch (returnCode) {
    case NSAlertDefaultReturn:
        [NSNotificationCenter postNotification:KisMACTryToSave];
    case NSAlertOtherReturn:
        break;
    case NSAlertAlternateReturn:
    default:
        [_window setDocumentEdited:NO];
        [NSApp terminate:self];
    }
}

@end