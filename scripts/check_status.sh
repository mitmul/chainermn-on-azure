az login
group=$1
vmss=$2
az vmss list-instances -g $group -n $vmss>instances.json
while IFS= read -r idvalue; do
 az vmss get-instance-view  -g $group -n $vmss --instance-id $idvalue>instancesview.json
 while IFS= read -r status; do
        echo "Status-$status"
        if [ "$status" != "ProvisioningState/succeeded" ] && [ "$status" != "PowerState/running" ]; then
			az vmss restart -g $group -n $vmss --instance-id $idvalue
        fi
 done < <(jq -r '.statuses[] | (.code)' <instancesview.json)
 echo "value $idvalue"
done < <(jq -r '.[] | (.instanceId)' <instances.json)
while IFS= read -r hostName; do
	echo| telnet $hostName 22 >status.txt
	check_connection()
		{
			grep Connected status.txt
			return $?
		}
	if check_connection; then
		echo "$hostName is communicating properly" >>Activestatus.txt
	else
		echo "$hostName failed to communicate" >>Inactivestatus.txt
	fi
done < <( jq -r '.[] | (.osProfile .computerName)' <instances.json)
file1=/root/Activestatus.txt
file2=/root/Inactivestatus.txt

if [ -e "$file1" ]; then
cat Activestatus.txt
fi
if [ -e "$file2" ]; then
cat Inactivestatus.txt
fi
rm -rf instancesview.json
rm -rf prerequisite.sh
rm -rf instances.json
rm -rf Activestatus.txt
rm -rf Inactivestatus.txt





