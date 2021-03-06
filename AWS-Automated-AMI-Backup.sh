#!/bin/bash
# These settings are configured for a standard AWS CentOS based instance with EC2 Tools installed to /schedule/BackupJob

# Constants 
export JAVA_HOME="/usr"
export EC2_HOME="/schedule/BackupJob/ec2-api-tools-1.6.1.4" 
AWS_ACCESS_KEY=""
AWS_SECRET_KEY="" 

# Variables
declare -a MACHINES=(i-00000000 i-000000017)
declare -a NAMES=(MachineNameForInstance00000000 AndFor00000001)
declare -a GREPFIX=("-e MachineNameForInstance00000000" "-e AndFor00000001")
declare -a MAILBOXES=(user@email.com)

# Dates 
datecheck_3d=`date +%Y-%m-%d --date '3 days ago'` 
datecheck_s_3d=`date --date="$datecheck_3d" +%s` 

# Get all image info and copy to file
# (Create machine list file and replace GREPFIX with reference to -f list file later.)
$EC2_HOME/bin/ec2-describe-images --aws-access-key $AWS_ACCESS_KEY --aws-secret-key $AWS_SECRET_KEY | grep ${GREPFIX[@]} > image_info.txt 2>&1
$EC2_HOME/bin/ec2-describe-snapshots --aws-access-key $AWS_ACCESS_KEY --aws-secret-key $AWS_SECRET_KEY > snap_info.txt 2>&1


echo "REMOVALS (>3 days out)"$'\n' > output.txt 
# Loop to remove any AMI older than 3 days 
IFS=$'\n'; 
for obj0 in $(cat image_info.txt) 
do 
	image_name=`cat image_info.txt | grep "$obj0" | awk '{print $2}'` 
	datecheck_old=`cat image_info.txt | grep "$image_name" | awk '{print $4}' | awk -F "T" '{printf "%s\n", $1}'` 
	datecheck_s_old=`date --date="$datecheck_old" +%s` 

	if (( $datecheck_s_old <= $datecheck_s_3d )); 
	then 
		echo "Deregistering image $image_name ..." >> output.txt
		$EC2_HOME/bin/ec2-deregister --aws-access-key $AWS_ACCESS_KEY --aws-secret-key $AWS_SECRET_KEY $image_name >> output.txt
		echo "Deregistering for $image_name complete."
		cat snap_info.txt |grep $image_name >> snap_rm.txt
#	else 
#		echo "NOT deregistering image $image_name ..." >> output.txt
	fi 
done 

# Loop to remove any AMI EBS snapshots older than 3 days 
IFS=$'\n'; 
for obj0 in $(cat snap_rm.txt) 
do 
	snap_name=`cat snap_rm.txt | grep "$obj0" | awk '{print $2}'` 
	echo "Deleting snap $snap_name ..." >> output.txt
	$EC2_HOME/bin/ec2-delete-snapshot --aws-access-key $AWS_ACCESS_KEY --aws-secret-key $AWS_SECRET_KEY $snap_name >> output.txt
	echo "Deregistering for $snap_name complete."
done 


# Loop to create image backup
b=0
echo $'\n\n'"ADDITIONS (new images)" $'\n' >> output.txt
for i in ${MACHINES[@]}
do
   # Run AWS image backup. With no-reboot option (no-reboot ensures that instances are not rebooted while AMI creation takes place.)
   $EC2_HOME/bin/ec2-create-image $i --name "${NAMES[$b]} $(date "+%Y-%m-%d %H%M%S")" --aws-access-key $AWS_ACCESS_KEY --aws-secret-key $AWS_SECRET_KEY --description "$i - $(date +%c)" --no-reboot >> output.txt

 if [ $? -ne 0 ]
 then
    echo ${NAMES[$b]} ' backup failed.'.$'\n' >> output.txt
 elif [ $? -ne 0 ]
 then
    echo ${NAMES[$b]} $(date +%m%d%y) 'created.' $'\n' >> output.txt
 fi
((b++))
done


##### Check for mail, then install if not found.
#which mail
#if [ $? -eq 0 ]; then
#    sudo yum install -y mailx
#else
#    echo 'test'
#fi
#####



# Mail results
# Loop through mailboxes
for j in ${MAILBOXES[@]}
 do
   /bin/mail -s "Backup Status - $(date +%m.%d.%y)" $j < output.txt
#end loop
 done



# Remove Temp files
 rm image_info.txt
 rm snap_info.txt
 rm snap_rm.txt
 rm output.txt
