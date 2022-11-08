#!/bin/bash

# Download and read contents of the index file.

prefix_url="https://files.singular-devops.com/challenges/01-applogs/"
index_filename="index.txt"

if [[ -f $index_filename ]]
then
  rm $index_filename
fi

wget ${prefix_url}${index_filename} &> /dev/null
dos2unix index.txt &> /dev/null

echo "--------------"
echo "Log filenames:"
echo "--------------"

while read line;
do 
  echo "$line";
done < ${index_filename}

# Generate links and download the application log files.
echo ""
echo "---------------------------"
echo "Application log file links:"
echo "---------------------------"

if [[ ! -d logs/ ]]
then
  mkdir logs/
else
  rm -rf logs/
fi

while read line;
do
  log_file_link=${prefix_url}${line}
  echo "${log_file_link}"
  wget -P logs "${log_file_link}" &> /dev/null
done < ${index_filename}

# Extract Information
echo ""
echo "---------"
echo "Report..."
echo "---------"

if [[ ! -d report/ && -f report/report.json ]]
then
  mkdir report
else 
  rm -rf report/
  mkdir report
fi

for log_file in logs/*.csv
do
  info=$(cat $log_file | grep info | wc -l)
  warnings=$(cat $log_file | grep warning | wc -l)
  errors=$(cat $log_file | grep error | wc -l)
  year_and_month=$(awk -F- '{print $1,$2}' $log_file | uniq -f 2)

  jq -n --arg ym "$year_and_month" --arg inf "$info" --arg warn "$warnings" --arg err "$errors" '{ yearAndMonth: $ym, infoMessages: $inf, warningMessages: $warn, errorMessages: $err }' >> report/report.json
done

cd report/
jq -s '.' ./report.json
echo $(jq -s '.' ./report.json ) > report.json

# Calculate percentage increase/decrease.
warn_num1=$(jq -r '.[0].warningMessages' < report.json)
warn_num2=$(jq -r '.[1].warningMessages' < report.json)
warn_num3=$(jq -r '.[2].warningMessages' < report.json)

err_num1=$(jq -r '.[0].errorMessages' < report.json)
err_num2=$(jq -r '.[1].errorMessages' < report.json)
err_num3=$(jq -r '.[2].errorMessages' < report.json)

warn_perc1=$(( (100) * ($warn_num2-$warn_num1) / ($warn_num1) ))
warn_perc2=$(( (100) * ($warn_num3-$warn_num2) / ($warn_num2) ))

err_perc1=$(( (100) * ($err_num2-$err_num1) / ($err_num1) ))
err_perc2=$(( (100) * ($err_num3-$err_num2) / ($err_num2) ))

echo ""
echo "Warning messages percentage increase/decrease:"
echo '[{"WarningsPercentageChangeI":"'$warn_perc1'"}, {"WarningsPercentageChangeII":"'$warn_perc2'"}]' | jq '[.[] ]'
echo $(echo '[{"WarningsPercentageChangeI":"'$warn_perc1'"}, {"WarningsPercentageChangeII":"'$warn_perc2'"}]' | jq '[.[] ]') >> report.json
echo ""

echo "Error messages percentage increase/decrease:"
echo '[{"ErrorsPercentageChangeI":"'$err_perc1'"}, {"ErrorsPercentageChangeII":"'$err_perc2'"}]' | jq '[.[] ]'
echo $(echo '[{"ErrorsPercentageChangeI":"'$err_perc1'"}, {"ErrorsPercentageChangeII":"'$err_perc2'"}]' | jq '[.[] ]') >> report.json
