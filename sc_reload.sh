#!/bin/sh
# 20120606 - Jamey Hopkins
#            Generate a random/ordered playlist from an MP3 directory
#            Echo output to playlist file for use by SHOUTcast
#            example ./makeplay.sh >main.lst (ordered list)
#                    ./makeplay.sh 1 >main.lst (random list)
#            apt-get install randomize-lines to install rl command
#            Note: The SHOUTcast transcoder plays random by default
#             *** Set shuffle=0 in sc_trans.conf to disable shuffle ***
# 20121116 - Perform kill -USR1 on running sc_trans
#            Use in nightly cron to reshuffle "random" playlist
#            sc_trans accepts the following signals:
#            HUP - flush logfiles (close and reopen) -- will make console logging stop
#            WINCH - jump to next song
#            USR1 - reload playlist off disk (will not interrupt current playing stream)
#            USR2 - toggle shuffle on/off
#            TERM - normal sc_trans shutdown (clean)
# 201310   - Option for Halloween
# 201311   - Option for Christmas
# 201512   - Option for Bud and Samples
# 20170707 - Dequeue repeating artists from list (Artist - Song)
#            Play X amount of songs before playing artist again
# 20181018 - Shift history down not up fix to avoid duplicates (deprecated 20210428)
#          - Document switch to shuf a few months ago
#          - The shuf command is part of coreutils vs no longer available randomize-lines
# 20190124 - Expand from S6 to S8 (deprecated 20210428)
#          - Moved match string to second line for items dequeued
#          - Checking line to only list song being checked
# 20210428 - Tail and grep for song instead of trying to remember and compare each song line by line
#            This is the twilight sleep simple solution, 4 years of doing it the hard way gone
# 20211028 - Switch to shuf and set DAY to auto select extra playlists, example halloween
# 20220505 - Inline rebuild_main.sh and makeplay.sh
#            Rename reload.sh -> sc_relead.sh
# 20220507 - Fix DAY output and move to end of list.
# 20241030 - Remove run option "1" for special events (add event songs by default)
#          - Remove shuf of XMAS and Halloween (double shuf fix)
#          - Remove old deprecated codes line that were commented out
#          - Added Halloween Day
#          - General code formatting and output cleanup
#          - temp.file -> initial.lst, song.list -> song.lst, check.list -> check.lst, dequeue.list -> dequeue.lst

cd /home/sc/playlists

DAY=$(date +%j)
# start fresh list
>initial.lst
echo;echo "Build Initial Playlist"
# add xmas songs
[ "$DAY" -gt 350 -a "$DAY" -lt 365 ] && echo "--- XMAS --- " && ls -1 ../music/xmas/*mp3 >>initial.lst
# add halloween songs
[ "$DAY" -gt 298 -a "$DAY" -lt 306 ] && echo "--- Halloween General --- " && ls -1 ../music/halloween/*mp3 >>initial.lst
# add halloween day songs
[ "$DAY" -eq 305 ] && echo "--- Halloween Day --- " && ls -1 ../music/halloween_day/*mp3 >>initial.lst
# add samples
echo "--- Samples ---"
ls -1 ../music/Samples/*mp3 >>initial.lst
# add bud commercials
#ls -1 ../music/Bud\ Light\ Presents/*mp3 | rl >>initial.lst
echo "--- General Pool ---"
ls -1 ../music/*mp3 >>initial.lst
sleep 3 # pause to show holiday specific selection happened

cat initial.lst >main.lst

CHECK=20

echo;echo "Randomize List and Dequeue Repeats"
shuf main.lst >song.lst

>dequeue.list
while read SONG
do
   echo "Checking: `basename "$SONG"`"
   S0=`basename "$SONG" | cut -c1-4`
   tail -$CHECK dequeue.lst > check.lst
   STAT=`grep "../music/$S0" check.lst`
   #echo "--- $S0 -- $STAT --"

   # if STAT is still empty, accept song
   [ "$STAT" = "" ] && echo "$SONG" >>dequeue.lst || echo "        : Found Match for [$S0], Song Dequeued"
done < ./song.lst

cat dequeue.lst >main.lst
rm dequeue.lst song.lst

ID=`pgrep sc_trans`

echo
echo "DAY: $DAY"
if [ "$ID" ]
then
   echo "Reloading playlist for SHOUTcast Transcoder at PID: $ID."
   kill -USR1 $ID
else
   echo "Did not find a running SHOUTcast Transcoder."
fi

echo

