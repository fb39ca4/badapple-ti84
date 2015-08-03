#!/usr/bin/env python3
import os
from array import *

os.environ["PATH"] += os.pathsep + "./util"

if (os.path.isfile("./bin/badapple.bin") == False):
    os.system("." + os.sep + "build.py")

badapple_bin = open("./bin/badapple.bin", "rb")
data = array('B', badapple_bin.read())
badapple_bin.close()
data.extend([0] * (16384 - (len(data) % 16384)))

os.makedirs("./allsizes", exist_ok=True)
resized_bin = open("./allsizes/resized.bin", "wb")
data.tofile(resized_bin)
resized_bin.close()

numPages = len(data) // 16384
emptyPage = array('B', [0] * 16384)

while (numPages < 96):
    print("Packaging with " + str(numPages + 1) + " pages.")
    os.system("rabbitsign -f -p -o ./allsizes/badapple" + str(numPages + 1) + ".8xk ./allsizes/resized.bin")
    resized_bin = open("./allsizes/resized.bin", "ab")
    emptyPage.tofile(resized_bin)
    resized_bin.close()
    numPages += 1

os.remove("./allsizes/resized.bin")
