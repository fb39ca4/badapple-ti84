#!/usr/bin/env python3
import sys
if (len(sys.argv) < 6):
    print("Usage: audio.py INPUTFILE OUTPUT1 OUTPUT2 OUTPUT3 OUTPUT4")
    exit(-1)
import xml.etree.ElementTree
import math

try:
    tree = xml.etree.ElementTree.parse(sys.argv[1])
except:
    print("Error opening input file")
    exit(-1)

def keyToCount(keyNo):
    interruptFreq = 33333.3#32768.0
    freq = 1.05946309436**(keyNo - 57) * 440.0
    count = 0.5 * interruptFreq / freq
    count = max(1, count)
    count = min(254, count)
    return count
scale = 3600.0 / (48.0 * 138.0)
root = tree.getroot()
channels = []
minlength = 9001
maxlength = 0
for track in root.iter('track'):
    if (track.get("type") != '0'):
        continue
    #print(track.get("name"))
    currentChannel = []
    for pattern in track.iter('pattern'):
        #print("  " + pattern.get("name"))
        offset = int(pattern.get("pos"))
        for note in pattern.iter('note'):
            freq = keyToCount(int(note.get("key")))
            freqInt = math.floor(math.modf(freq)[1])
            freqFract = math.floor(math.modf(freq)[0] * 256)
            currentChannel.append( ( int(int(int(note.get("pos")) + offset) / 6), int((int(note.get("len")) + 1) / 6), freqFract, freqInt) )
            #print("    " + "note")
    channels.append(sorted(currentChannel))
#print(channels)
#print(len(channels[0]), len(channels[1]), len(channels[2]), len(channels[3]))

for c in channels:
    l = len(c)
    if (0 < c[0][0]):
        c.append((0, c[0][0], 0, 0))
    for i in range(0, l - 1):
        if (c[i][0] + c[i][1] < c[i + 1][0]):
            for j in range(0, (c[i + 1][0] - c[i][0] + c[i][1]) >> 8):
                c.append( (c[i][0] + c[i][1] + j * 256, 256, 255, 0) )
            if ((c[i + 1][0] - (c[i][0] + c[i][1])) % 256 > 0):
                c.append( (c[i][0] + c[i][1] + ((c[i + 1][0] - c[i][0] + c[i][1]) >> 8) * 256, (c[i + 1][0] - (c[i][0] + c[i][1])) % 256, 0, 0) )
    c.append((0, 16, 0, 0))
    c.sort()
    c.append((0, 256, 0, 0))
    c.append((0, 256, 0, 0))
    c.append((0, 256, 0, 0))
    #print("\n\n\n\n")
    totalPos = 0
    for i in range(0, len(c)):
        #print(c[i], totalPos)
        totalPos += c[i][1]

for i in range(0, 4):
    f = open(sys.argv[i + 2], "w")
    f.write(".org $4000\n")
    f.write(".db 04\n")
    f.write("Track" + str(i + 1) + "Data:\n")
    for j in range(0, len(channels[i])):
        f.write(".db " + str(channels[i][j][1] % 256) + ", " + str(channels[i][j][2] & 0xFF) + ", " + str(channels[i][j][3]) + " ;" + str(channels[i][j][0]) + "\n")
    f.write("\n")
    f.write(".block $8000 - $")
    f.close()
