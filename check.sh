#!/bin/sh

#this code is tested un fresh 2015-11-21-raspbian-jessie-lite Raspberry Pi image
#by default this script should be located in two subdirecotries under the home

#sudo apt-get update -y && sudo apt-get upgrade -y
#sudo apt-get install git -y
#mkdir -p /home/pi/detect && cd /home/pi/detect
#git clone https://github.com/catonrug/intel-ethernet-driver-cd-detect.git && cd intel-ethernet-driver-cd-detect && chmod +x check.sh && ./check.sh

#check if script is located in /home direcotry
pwd | grep "^/home/" > /dev/null
if [ $? -ne 0 ]; then
  echo script must be located in /home direcotry
  return
fi

#it is highly recommended to place this directory in another directory
deep=$(pwd | sed "s/\//\n/g" | grep -v "^$" | wc -l)
if [ $deep -lt 4 ]; then
  echo please place this script in deeper directory
  return
fi

#set application name based on directory name
#this will be used for future temp directory, database name, google upload config, archiving
appname=$(pwd | sed "s/^.*\///g")

#set temp directory in variable based on application name
tmp=$(echo ../tmp/$appname)

#create temp directory
if [ ! -d "$tmp" ]; then
  mkdir -p "$tmp"
fi

#check if database directory has prepared
if [ ! -d "../db" ]; then
  mkdir -p "../db"
fi

#set database variable
db=$(echo ../db/$appname.db)

#if database file do not exist then create one
if [ ! -f "$db" ]; then
  touch "$db"
fi

#check if google drive config directory has been made
#if the config file exists then use it to upload file in google drive
#if no config file is in the directory there no upload will happen
if [ ! -d "../gd" ]; then
  mkdir -p "../gd"
fi

if [ -f ~/uploader_credentials.txt ]; then
sed "s/folder = test/folder = `echo $appname`/" ../uploader.cfg > ../gd/$appname.cfg
else
echo google upload will not be used cause ~/uploader_credentials.txt do not exist
fi

#set url
name=$(echo "Intel Ethernet Driver CD")
download=$(echo "https://downloadcenter.intel.com/download/26757/Ethernet-Intel-Ethernet-Adapter-Connections-CD")

wget -S --spider -o $tmp/output.log "$download"

grep -A99 "^Resolving" $tmp/output.log | grep "HTTP.*200 OK"
if [ $? -eq 0 ]; then
#if file request retrieve http code 200 this means OK

#get all exe english installers
linklist=$(wget -qO- "$download" | sed "s/\d034/\n/g" | grep "Ethernet-Intel-Ethernet-Adapter-Connections" | sort | uniq | sed "s/^.*download\//https:\/\/downloadcenter\.intel\.com\/download\//g" | sed '$alast line')

echo "$linklist"

#count how many links are in download page. substarct one fake last line from array
links=$(echo "$linklist" | head -n -1 | wc -l)
if [ $links -gt 1 ]; then
echo $links download links found
echo

printf %s "$linklist" | while IFS= read -r link
do {

echo "Link:" "$link"

#look for zip file
url=$(wget -qO- "$link" | sed "s/\d034\|=/\n/g" | sed "s/%3A/:/g" | sed "s/%2F/\//g" | grep -m1 "http.*zip\|http.*ZIP")

echo " URL:" "$url"

echo
echo

#check if exact link is ok
wget -S --spider "$url" -o $tmp/output.log 

echo "==="
cat $tmp/output.log
echo "==="
echo

grep "HTTP.*200 OK" $tmp/output.log
if [ $? -eq 0 ]; then
#if file request retrieve http code 200 this means OK

echo ir OK
echo

#check if size is OK
size=$(grep "Content-Length" $tmp/output.log | sed "s/^.*: //g")
if [ $size -gt 47560805 ]; then

echo "$size"

#check if this primary link is in database
grep "$link" $db > /dev/null
if [ $? -ne 0 ]; then
echo

#calculate filename
filename=$(echo "$url" | sed "s/\//\n/g" | grep "zip")

#download file
echo Downloading $filename
wget "$url" -O "$tmp/$filename"

#check downloded file size if it is fair enought
size=$(du -b $tmp/$filename | sed "s/\s.*$//g")
if [ $size -gt 47560805 ]; then
echo

echo creating md5 checksum of file..
md5=$(md5sum $tmp/$filename | sed "s/\s.*//g")
echo

echo creating sha1 checksum of file..
sha1=$(sha1sum $tmp/$filename | sed "s/\s.*//g")
echo

echo "$link">> $db
echo "$url">> $db
echo "$md5">> $db
echo "$sha1">> $db
echo >> $db

#lets send emails to all people in "posting" file
emails=$(cat ../posting | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$name $filename" "$url 
$md5
$sha1
"
} done
echo

else
#downloaded file size is to small
echo downloaded file size is to small
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$name" "Downloaded file size is to small:
$url
$size"
} done
fi

else
#$id is already in database
echo "$id" is already in database
fi

else
#zip file size is to small
echo zip file size in "$url" is to small
fi

else
#if url is not OK
echo download link "$link" do not retrieve good zip file "$url"
fi

rm -rf $tmp/*

} done

else
#only $links download links found
echo only $links download links found
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$name" "only $links download links found:
$download "
} done
fi

else
#if http status code is not 200 ok
emails=$(cat ../maintenance | sed '$aend of file')
printf %s "$emails" | while IFS= read -r onemail
do {
python ../send-email.py "$onemail" "$name" "the following link do not retrieve good http status code:
$url"
} done
echo
echo
fi

#clean and remove whole temp direcotry
rm $tmp -rf > /dev/null
