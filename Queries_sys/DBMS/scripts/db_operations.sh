#!/bin/bash

keywords=("select" "insert" "id" "create" "update" "delete" "drop" "alter" "table" "database" "and" "or")
create_db(){
local dbname=$1
if [[ -d "$DBSM_PATH/data/$dbname" ]]; then 
   echo -e "\e[31mERROR DATABASE ALREADY EXISTS\e[0m"
else
   echo $DBSM_PATH;
   echo "$DBSM_PATH/data/$dbname";
   for keyword in "${keywords[@]}"; do
        if [[ "$dbname" == "$keyword" ]]; then
            echo -e "\e[31mERROR: Can't create database using reserved keyword '$dbname'\e[0m"
            return 1
        fi
    done
   mkdir "$DBSM_PATH/data/$dbname";
   local metafile=$(echo "$dbname" "_meta" | sed -E "s/ //g")
   touch "$DBSM_PATH/data/$dbname/$metafile"
fi
}


drop_db(){
local dbname=$1
if [[ -d "$DBSM_PATH/data/$dbname" ]]; then 
   rm -R "$DBSM_PATH/data/$dbname"
else
   echo -e "\e[31mDATABASE DOESNT EXIST>\e[0m"
fi
}


list_db() {
echo -e "\e[34mAvailable Databases:\e[0m"
local databases=($(ls -A "$DBSM_PATH/data"))  
if [[ ${#databases[@]} -eq 0 ]]; then  
        echo "No databases found."
        return
fi
for db in "${databases[@]}"; do
      if [[ -d "$DBSM_PATH/data/$db" ]]; then 
         echo "$db"
      fi
done
}




connect_db(){
local dbname=$1
if [[ -d "$DBSM_PATH/data/$dbname" ]]; then 
   echo -e "\e[32mCONNECTION SUCCESSFUL\e[0m";
   return 0;
else
   echo -e "\e[31mCONNECTION FAILED\e[0m";
   return 1
fi
}
