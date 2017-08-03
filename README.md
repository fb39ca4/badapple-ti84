# Bad Apple for TI-84
This is the source code for the Bad Apple demo for TI-84, which plays back the entire 3:40 Bad Apple video on a TI-83+/84+ SE calculator. Video: https://www.youtube.com/watch?v=6pAeWf3NPNU

The source code includes both the playback code, written in Z80 assembly, and encoders for the video and audio, written in Python.

## Building
You will need Python 3, SPASM and Rabbitsign to build this demo. If you do not have SPASM or Rabbitsign installed, you can place their binaries in the `./util` directory.

[SPASM](https://wabbit.codeplex.com/releases/view/45088)

[RabbitSign (Win)](http://www.ticalc.org/archives/files/fileinfo/420/42035.html)

[RabbitSign (*nix)](http://www.ticalc.org/archives/files/fileinfo/383/38392.html)

To build, just run `./build.py`. If everything goes successfully, it will produce the final application file `./badapple.8xk` which you can then transfer to your calculator or run on an emulator.

## Transfer Issues
Calculator file transfer software is unreliable for application files this large. I have only been able to successfully transfer the app using TILP. If you are having problems with TILP crashing, that is probably because you have a version that does not allocate enough memory for applications larger than 50 pages. If this is happening to you, or the transfer is otherwise failing, you can try running `./build_allsizes.py` to generate multiple application files of differing sizes, and try each one until it works.

## Editing

### Video
The source video is contained in `./video/frames.bin.gz`. It simply stores each pixel in one byte, 0 or 1, with a scan order of left to right, then top to bottom, then first frame to last frame, and finally, the entire file is gzipped. Frames are 96x64 pixels. To make sure the video gets reencoded, delete `./bin/videopages.bin` if it already exists.

### Audio
Edit Ch1 - Ch4 of `./music/badapple.mmp` with [LMMS](https://lmms.io/). You shouldn't change the channel names or synths. Notes within a channel should not overlap, and note lengths should be multiples of 1/32 notes. To change the tempo of the music, change the value of `musicInterval` in `./badapple.asm`. When building, the file will be automatically read and converted.

`./music/original` contains the original files provided by the 4chan user who created the chiptune arrangement used in this demo, created using Cubase and Reason. However, they are not directly used.
