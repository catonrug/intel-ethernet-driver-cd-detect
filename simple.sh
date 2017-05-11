


download=$(echo "https://downloadcenter.intel.com/download/26757/Ethernet-Intel-Ethernet-Adapter-Connections-CD")

wget -qO- "$download" | \
sed "s/\d034/\n/g" | \
grep "Ethernet-Intel-Ethernet-Adapter-Connections" | sort | uniq | \
sed "s/^.*download\//https:\/\/downloadcenter\.intel\.com\/download\//g" | \
while IFS= read -r link; do

wget -qO- "$link" | \
sed "s/\d034\|=/\n/g" | \
sed "s/%3A/:/g" | \
sed "s/%2F/\//g" | \
grep -m1 "http.*zip\|http.*ZIP"

done
