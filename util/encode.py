#!/usr/bin/env python3
import sys
if (len(sys.argv) < 3):
    print("Usage: encode.py INPUTFILE OUTPUTFILE [FRAMESIZES]")
    exit(-1)
from array import *
import gzip

usePFrames = 1

rawFrames = []
interlacedFrames = []
iFrames = []
pFrames = []
finalFrames = []
pages = []

#01: p-frame
#02: i-frame (rlex)
#03: d-frame
#04: next page
#05: quit

def packBits(input):
    res = []
    for i in range(0, len(input)):
        if (i % 8 == 0):
            res.append(0)
        res[-1] = res[-1] ^ ((0 if (input[i] == 0) else 1) << (i % 8))
    return array('B', res)
    
def packBitsRev(input):
    res = []
    for i in range(0, len(input)):
        if (i % 8 == 0):
            res.append(0)
        res[-1] = res[-1] ^ ((1 if (input[i] == 0) else 0) << (7 - (i % 8)))
    return array('B', res)
    
def unpackBits(input):
    res = []
    for i in range(0, len(input)):
        for j in range(0, 8):
            res.append((input[i] >> j) & 1)
    return array('B', res)
    
def transposeByteFrame(input):
    res = array('B', [0] * 12 * 64)
    for i in range(0, 12):
        for j in range(0, 64):
            res[i * 64 + j] = input[j * 12 + i]
    return res  

def unpackRlex(input):
    i = 0
    a = 0
    r = input[i]
    i += 1
    output = []
    while (i < len(input)):
        a = input[i]
        i += 1
        if (a != r):
            output.append(a)
        else:
            b = input[i]
            if (b == 0):
                b = 256
            i += 1
            a = input[i]
            i += 1
            for j in range(0, b):
                output.append(a)
    return output    

try:
    f = gzip.open(sys.argv[1], 'rb')
except:
    print("Error opening input file")
    exit(-1)
frameBin = array('B')
frameBin.frombytes(f.read())
f.close()
frameSizeBytes = 6144

for i in range(0, len(frameBin) // frameSizeBytes):
    rawFrames.append(frameBin[i*frameSizeBytes : (i+1)*frameSizeBytes])
numFrames = len(rawFrames)
print("Loaded " + str(numFrames) + " frames")

for frameNum in range(0, numFrames):
    print("RLE compressing frame " + str(frameNum) + "/" + str(numFrames), end="\r")
    rlexData = array('B')
    byteData = transposeByteFrame(packBitsRev(rawFrames[frameNum]))
    byteFrequency = array('I', [0] * 256)
    for i in range(0, len(byteData)):
        byteFrequency[byteData[i]] += 1
    minFrequency = 9001
    repeatByte = 0
    for i in range(0, len(byteFrequency)):
        if (byteFrequency[i] < minFrequency):
            repeatByte = i
            minFrequency = byteFrequency[i]
    rlexData.append(repeatByte)
    runData = []
    runData.append([byteData[0], 1])
    for i in range(1, len(byteData)):
        if (byteData[i] == runData[-1][0]):
            if (runData[-1][1] < 256):
                runData[-1][1] += 1
            else:
                runData.append([byteData[i], 1])
        else:
            runData.append([byteData[i], 1])
    for i in range(0, len(runData)):
        if (runData[i][0] == repeatByte):
            rlexData.append(repeatByte)
            rlexData.append(runData[i][1] % 256)
            rlexData.append(repeatByte)
        else:
            if (runData[i][1] == 1):
                rlexData.append(runData[i][0])
            elif (runData[i][1] == 2):
                rlexData.append(runData[i][0])
                rlexData.append(runData[i][0])
            else:
                rlexData.append(repeatByte)
                rlexData.append(runData[i][1] % 256)
                rlexData.append(runData[i][0])
    iFrames.append(rlexData)
print(" " * 40 + "\rRLE compressed " + str(numFrames) + " frames")
 
for frameNum in range(0, numFrames):
    print("Delta compressing frame " + str(frameNum) + "/" + str(numFrames), end="\r")
    pData = array('B')
    if (usePFrames == 1):
        oldScanlines = []
        newScanlines = []
        frameHeader = array('B')
        for i in range(0, 64):
            if (frameNum < 1):
                oldScanlines.append(array('B', [0] * 12))
            else:
                oldScanlines.append(packBitsRev(rawFrames[frameNum - 1][i * 96:i * 96 + 96]))
            newScanlines.append(packBitsRev(rawFrames[frameNum][i * 96:i * 96 + 96]))
            frameHeader.append(0 if (oldScanlines[-1] == newScanlines[-1]) else 1)
        pData.extend(packBits(frameHeader))
        for i in range(0, 64):
            if (frameHeader[i] == 1):
                scanlineHeader = array('B')
                for j in range(0, 12):
                    scanlineHeader.append(0 if (oldScanlines[i][j] == newScanlines[i][j]) else 1)
                pData.append(packBits(scanlineHeader)[0])
                for j in range(0, 8):
                    if (scanlineHeader[j] == 1):
                        pData.append(newScanlines[i][j])
                pData.append(packBits(scanlineHeader)[1])
                for j in range(8, 12):
                    if (scanlineHeader[j] == 1):
                        pData.append(newScanlines[i][j])
    else:
        pData.extend(array('B', [0] * (4 + 64 * (12 * 2))))
    pFrames.append(pData)
    
print(" " * 40 + "\rDelta compressed " + str(numFrames) + " frames")

numIFrames = 0
numPFrames = 0
numDFrames = 0
totalSize = 0

for frameNum in range(0, numFrames):
    finalData = array('B')
    if (frameNum < 2):
        finalData.append(2)
        finalData.extend(iFrames[frameNum])
        numIFrames += 1
    else:
        if (rawFrames[frameNum] == rawFrames[frameNum - 1]):
            finalData.append(3)
            numDFrames += 1
        else:
            if (len(iFrames[frameNum]) < len(pFrames[frameNum])):
                finalData.append(2)
                finalData.extend(iFrames[frameNum])
                numIFrames += 1
            else:
                finalData.append(1)
                finalData.extend(pFrames[frameNum])
                numPFrames += 1
    finalFrames.append(finalData)
    totalSize += len(finalData)

print("Encoding results:")
print("RLE frames: " + str(numIFrames))
print("Delta frames: " + str(numPFrames))
print("Duplicate frames: " + str(numDFrames))
print("Total Size: " + str(totalSize))

pages.append(array('B'))
for frameNum in range(0, numFrames):
    if (len(pages[-1]) + len(finalFrames[frameNum]) >= 16383):
        pages[-1].append(4)
        pages[-1].extend(array('B', [0] * (16384 - len(pages[-1]) ) ) )
        pages.append(array('B'))
    pages[-1].extend(finalFrames[frameNum])
pages[-1].append(5)
#pages[-1].extend(array('B', [0] * (16384 - len(pages[-1]) ) ) )

f = open(sys.argv[2], "wb")
for pageNum in range(0, len(pages)):
    pages[pageNum].tofile(f)
f.close()
    
if (len(sys.argv) >= 4):
    f = open(sys.argv[3], "w")
    f.write("RLE Frame, Delta Frame\n")
    for frameNum in range(0, numFrames):
        f.write(str(len(iFrames[frameNum])) + ", " + str(len(pFrames[frameNum])) + "\n")
    f.close()
