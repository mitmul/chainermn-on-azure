#!/bin/bash

while getopts r:n:l:d: OPT
do
  case $OPT in
    "r" ) RESOURCE_GROUP=$OPTARG ;;
    "n" ) IMAGE_NAME=$OPTARG ;;
    "l" ) LOCATION=$OPTARG ;;
    "d" ) TARGET_GROUP=$OPTARG ;;
  esac
done

az image copy \
--source-resource-group $RESOURCE_GROUP \
--source-object-name $IMAGE_NAME \
--target-location $LOCATION \
--target-resource-group $TARGET_GROUP
