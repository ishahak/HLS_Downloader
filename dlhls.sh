MAX_FILE_PER_STREAM=10

function remove_nonexisting {
    if [ -z $1 ]||[ $1 == --help ]||[ ! -e $1 ]; then
        echo "This script removes lines of HLS playlist which include non-existing TS files"
        echo "Usage: ./remove_nonexisting <M3U8 playlist file>"
        exit 1
    fi
    fileToModify=$1
    echo "remove_nonexisting: file=$fileToModify"
    sed -e '/^#EXTINF/ { N; s_\n_%%%_; }' $fileToModify > tmp_pl.txt

    #remove lines of non-existing streams in tmp_pl.txt
    lastExtInf=`tail -n 10 -r tmp_pl.txt | sed -n -e '/%%%/{ p; q; }'`
    #most of lines are #EXTINF:2.0,%%%1479853/471060000.ts
    while read line; do
        if [[ $line == *"%%%"* ]]; then
            ts=`echo $line | sed s_.*%%%__`
            if [ ! -e $ts ]; then
                echo "Found $ts as missing"
                firstMissing=$line
                break
            fi
        fi
    done < tmp_pl.txt

    echo "Will remove FROM last=$lastExtInf TO first=$firstMissing"

    #remove missing, turning / into \/ for the sed
    sed -i "" -e "/${firstMissing//\//\\/}/,/${lastExtInf//\//\\/}/d" tmp_pl.txt
    sed -i "" -e 's_%%%_\
_' tmp_pl.txt
    cp tmp_pl.txt $fileToModify
}

#set -x
URL=http://static.france24.com/live/F24_EN_LO_HLS/live_ios.m3u8
DOMAIN=$(echo $URL | awk -F/ '{print $3}')
#THEIP=$(dig +short $DOMAIN)
#THEIP=201.6.17.245
echo "###--- pinging to get IP for $DOMAIN..."
THEIP=$(ping $DOMAIN -c 1 | sed -n -e '1 s/.*(\(.*\)).*/\1/p')
URL2=$(echo $URL | sed -e "s:$DOMAIN:$THEIP:")
echo "###--- New URL: $URL2"
HOST_HDR="--header Host:$DOMAIN"
MANIFESTNAME=$(basename $URL)
#STREAM=${MANIFESTNAME%.*}
#mkdir $STREAM 2> /dev/null
LOCAL_MANIFEST=$MANIFESTNAME
URLPREF=$(dirname $URL)

if [ -s $LOCAL_MANIFEST ] && [ -s all_playlists.txt ]; then
  echo -e "$LOCAL_MANIFEST: Already exists. skiping.\n\n"
else
  echo -e "\n\n###--- Downloading master manifest from $URL2 ---"
  wget $URL2 $HOST_HDR -O $LOCAL_MANIFEST
  if [ ! $? == 0 ]||[ ! -s $LOCAL_MANIFEST ]; then
    echo ">>>> Error downloading manifest <<<<"
    exit 2
  fi
  echo -e "###--- manifest downloaded. now building list of playlists...\n\n"
  cat $LOCAL_MANIFEST | grep "#EXT-X-STREAM-INF:" -A1 | grep m3u8 | tr -d '\r' > all_playlists.txt
  cat $LOCAL_MANIFEST | grep "#EXT-X-MEDIA.*URI" | sed -e 's_.*URI=\"\(.*\)\".*_\1_' | tr -d '\r' >> all_playlists.txt
  #this will yield files which we already downloaded, but we want to index file itself
  cat $LOCAL_MANIFEST | grep "#EXT-X-I-FRAME-STREAM-INF.*URI" | sed -e 's_.*URI=\"\(.*\)\".*_\1_' | tr -d '\r' >> all_playlists.txt
fi

echo "###--- all_playlists.txt: ---"
cat all_playlists.txt
echo --------------------------

while read playList; do
  FOLDER=$(dirname $playList)
  PL_NAME=$(basename $playList)
  LOCAL_PL=$FOLDER/$PL_NAME
  mkdir -p $FOLDER 2> /dev/null
  PL_URL=$URLPREF/$playList

  echo -e "\n\n###--- Downloading playlist $PL_URL"
  TSL=${FOLDER}_TSList.txt
  wget $PL_URL -O $LOCAL_PL 
  if [ ! $? == 0 ]||[ ! -s $LOCAL_PL ]; then
    echo "###>>>> Error downloading playlist file <<<<"
  else
    echo -e "###--- Playlist downloaded ---\n\n"
  fi
  #echo "LOCAL_PL=$LOCAL_PL"
  cat $LOCAL_PL | grep -v "^#" | uniq | tr -d '\r' | head -n $MAX_FILE_PER_STREAM > $TSL
  echo "====== media list to download, based on playlist ======="
  cat $TSL
  echo -e "========================================================\n"
  #TS is actually any media file
  while read ts; do
    if [ $FOLDER == "." ]; then
      TS_NAME=$URLPREF/$ts
    else
      TS_NAME=$URLPREF/$FOLDER/$ts
    fi
    LOCAL_TS=$FOLDER/$ts
    FOLDER2=$(dirname $LOCAL_TS) 
    mkdir -p $FOLDER2 2> /dev/null
    echo $TS_NAME
    if [ -s $LOCAL_TS ]; then
      echo "Already exists. skiping."
    else
      echo -e "\n\n###--- Downloading TS from $TS_NAME"
      wget $TS_NAME -O $LOCAL_TS
      if [ ! $? == 0 ]||[ ! -s $LOCAL_TS ]; then
        echo "###>>>> Error downloading TS file <<<<"
      else
        echo -e "###--- TS downloaded ---\n\n"
      fi
    
    fi
  done < $TSL
  rm $TSL
  remove_nonexisting $LOCAL_PL
done < all_playlists.txt
rm all_playlists.txt
find . -name Thumbs.db -exec rm {} \;

