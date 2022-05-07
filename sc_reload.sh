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

echo "randomize and dequeue"
#~sc/playlists/rebuild_main.sh

cd /home/sc/playlists
#./makeplay.sh 1 >main.lst

DAY=$(date +%j)
echo "DAY: %DAY"

if [ "$1" = "1" ]
then
 ls -1 ../music/*mp3 | shuf >temp.file 
 # add xmas songs
 [ "$DAY" -gt 350 -a "$DAY" -lt 365 ] && echo "XMAS" && ls -1 ../music/xmas/*mp3 | shuf >>temp.file 
 # add halloween songs
 [ "$DAY" -gt 298 -a "$DAY" -lt 306 ] && echo "Halloween" &&  ls -1 ../music/halloween/*mp3 | shuf >>temp.file
 # add bud
## ls -1 ../music/Bud\ Light\ Presents/*mp3 | rl >>temp.file
 # add Samples
 ls -1 ../music/Samples/*mp3 | shuf >>temp.file
else
 ls -1 ../music/*mp3 >temp.file
 ls -1 ../music/Samples/*mp3 >>temp.file
fi

cat temp.file >main.lst
rm temp.file

#./dra main.lst
#./dra_v2.sh main.lst

#LIST="$1"
CHECK=20

# randomize source list
#rl $LIST >song.list
shuf main.lst >song.list

>dequeue.list
while read SONG
do
   echo "Checking: `basename "$SONG"`"
   S0=`basename "$SONG" | cut -c1-4`
   tail -$CHECK dequeue.list > check.list
   STAT=`grep "../music/$S0" check.list`
   #echo "--- $S0 -- $STAT --"

   # if STAT is still empty, accept song
   [ "$STAT" = "" ] && echo "$SONG" >>dequeue.list || echo "        : Found Match for [$S0], Song Dequeued"

done < ./song.list

cat dequeue.list >main.lst
rm dequeue.list song.list

ID=`ps -ef | grep sc_trans | grep -v grep |awk '{ print $2 }'`

echo
if [ "$ID" ]
then
   echo "Reloading playlist for sc_trans at $ID"
   kill -USR1 $ID
else
   echo "Did not find a running sc_trans"
fi

echo


