import os, sys
from array import *
import png
import gzip

numFrames = 6572
frameRange = range(1, numFrames + 1)
#numFrames = 2
#frameRange = range(42, 44)
treshold = 127
usePFrames = 1

rawFrames = []

frameData = array('B')

idx = -1
for frameNum in frameRange:
    originalData = png.Reader("./../frames/badapple" + str(frameNum).zfill(4) + ".png").read_flat()[2]
    pixelData = array('B')
    for i in range(96 * 4, 96 * 68):
        if (i & 7 == 0):
            idx += 1;
        frameData.append(1 if (originalData[3 * i + 1] > treshold) else 0)
    print("loaded frame " + str(frameNum).zfill(4))

f = gzip.open('./frames.bin.gz', 'wb')
frameData.tofile(f)
f.close()
