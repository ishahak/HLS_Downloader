# HLS_Downloader
A bash script for downloading a stream from a remote server down to the local machine.

How to use:
* Create an empty folder in your local machine, and copy dlhls.sh into it.
* Edit dlhls.sh:
    * MAX_FILE_PER_STREAM=10
        * How many TS files you want to download for each bitrate? Bigger numbers will allow more playback time, but require more time to download and more space on your disk
    * URL=http://...
        * Put here your own stream
    * THEIP=
        * There are several options here. We currently use ping to turn the DNS name into IP. If you know the IP you can specify it directly.
* Open a terminal and cd into that folder.
* Run these commands:
```bash
chmod u+x dlhls.sh
./dlhls
```
This should initiate the download, giving out more than enough printouts for troubleshooting.

To play the stream, you can install npm's http-server and activate it at the current path:
```bash
npm install -g http-server
http-server -p 3002
```

Enjoy!
