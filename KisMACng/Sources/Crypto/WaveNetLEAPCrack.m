/*
        
        File:			WaveNetLEAPCrack.m
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

#import "WaveNetLEAPCrack.h"
#import "LEAP.h"
#import "WaveClient.h"
#import <openssl/md4.h>

struct leapClientData {
    const UInt8 *response;
    const UInt8 *challenge;
    UInt8    hashend[2];
    NSString *username;
    NSString *clientID;
};

@implementation WaveNet(LEAPCrackExtension)

- (BOOL)crackLEAPWithWordlist:(NSString*)wordlist andImportController:(ImportController*)im {
    char wrd[100];
    FILE* fptr;
    unsigned int i, words, keys, curKey;
    struct leapClientData *c;
    WaveClient *wc;
    unsigned char pwhash[MD4_DIGEST_LENGTH];
    
    //open wordlist
    fptr = fopen([wordlist cString], "r");
    if (!fptr) return NO;
    
    //initialize all the data structures
    keys = 0;
    for (i = 0; i < [aClientKeys count]; i++) {
        if ([[aClients objectForKey:[aClientKeys objectAtIndex:i]] leapDataAvailable]) keys++;
    }

    curKey = 0;
    c = malloc(keys * sizeof(struct leapClientData));
    
    for (i = 0; i < [aClientKeys count]; i++) {
        wc = [aClients objectForKey:[aClientKeys objectAtIndex:i]];
        if ([wc leapDataAvailable]) {
            if ([[wc ID] isEqualToString:aBSSID]) {
                keys--;
            } else {
                c[curKey].username  = [wc leapUsername];
                c[curKey].challenge = [[wc leapChallenge] bytes];
                c[curKey].response  = [[wc leapResponse]  bytes];
                c[curKey].clientID  = [wc ID];
                
                //prepare our attack
                if (gethashlast2(c[curKey].challenge, c[curKey].response, c[curKey].hashend) == 0)
                    curKey++;
                else 
                    keys--;
            }
        }
    }

    NSAssert(keys!=0, @"There must be more keys");
    
    words = 0;
    wrd[90]=0;

    while(![im canceled] && !feof(fptr)) {
        fgets(wrd, 90, fptr);
        i = strlen(wrd) - 1;
        wrd[i--] = 0;
        if (wrd[i]=='\r') wrd[i] = 0;
        
        words++;

        if (words % 100000 == 0) {
            [im setStatusField:[NSString stringWithFormat:@"%d words tested", words]];
        }

        if (i > 31) continue; //dont support large passwords
        
        NtPasswordHash(wrd, i+1, pwhash);

        for (curKey = 0; curKey < keys; curKey++) {
            if (c[curKey].hashend[0] != pwhash[14] || c[curKey].hashend[1] != pwhash[15]) continue;
            if (testChallenge(c[curKey].challenge, c[curKey].response, pwhash)) continue;
            
            _password = [[NSString stringWithFormat:@"%s for username %@", wrd, c[curKey].username] retain];
            fclose(fptr);
            free(c);
            NSLog(@"Cracking was successful. Password is <%s> for username %@, client %@", wrd, c[curKey].username, c[curKey].clientID);
            return YES;
        }
    }
    
    free(c);
    fclose(fptr);
    
    _crackErrorString = [NSLocalizedString(@"The key was none of the tested passwords.", @"Error description for WPA crack.") retain];
    return NO;
}

@end