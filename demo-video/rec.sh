# usage: source rec.sh; rec_start NAME; ...; rec_stop NAME
export MSYS_NO_PATHCONV=1
ADB="$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe"
P="python ../scripts/phone.py"
rec_start() { "$ADB" shell "screenrecord --bit-rate 8000000 --time-limit 180 /sdcard/$1.mp4" >/dev/null 2>&1 & sleep 1.5; }
rec_stop() { sleep 1; "$ADB" shell pkill -INT screenrecord; sleep 2; "$ADB" pull /sdcard/$1.mp4 raw_$1.mp4 >/dev/null && "$ADB" shell rm /sdcard/$1.mp4; ffprobe -v error -show_entries format=duration -of csv=p=0 raw_$1.mp4; }
