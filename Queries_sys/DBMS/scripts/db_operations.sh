#!/bin/bash

keywords=("select" "insert" "id" "create" "update" "delete" "drop" "alter" "table" "database" "and" "or")

validate_name(){
 entity=$1;
 entity_name=$2;
 for keyword in "${keywords[@]}"; do
        if [[ "$entity_name" == "$keyword" ]]; then
            echo -e "\e[31mERROR: Can't create $entity using reserved keyword '$entity_name'\e[0m"
            return 1;
        fi
   done
    if [[ ! "$entity_name" =~ ^[[:alpha:]]+[a-zA-Z0-9_]*$ ]]; then
            echo -e "\e[31mERROR: Can't  $entity name must start with a letter then followed only by alphanumeric characters \e[0m";
            return 1;
    fi
    if (( "${#entity_name}" > 20 )); then
            echo -e "\e[31mERROR: Can't  be longer than 20 character \e[0m"
            return 1
    fi
 

}
create_db(){
local dbname=$1
if [[ -d "$DBSM_PATH/data/$dbname" ]]; then 
   echo -e "\e[31mERROR DATABASE ALREADY EXISTS\e[0m"
else

   validate_name "database" $dbname;
   if (( $? == 1 )); then
       return 1;
   fi
   mkdir "$DBSM_PATH/data/$dbname";
   local metafile="$dbname-meta" 
   touch "$DBSM_PATH/data/$dbname/$metafile"
   echo -e "\e[32mDATABASE WAS CREATED SUCCESSFULLY\e[0m"
fi
}


drop_db(){
local dbname=$1;
if $CONNECTED; then
   if [[ $CURRENT_DB == $dbname ]]; then
    echo -e "\e[31mCANT DROP DATABASE $dbname WHILE CURRENTLY CONNECTED TO IT\e[0m";
    return 1;
   fi
fi
if [[ -d "$DBSM_PATH/data/$dbname" ]]; then 
   rm -R "$DBSM_PATH/data/$dbname";
   echo -e "\e[32mDATABASE $dbname WAS DROPPED SUCCESSFULLY\e[0m";
else
   echo -e "\e[31mDATABASE $dbname DOESNT EXIST\e[0m";
fi
}


list_db() {
echo -e "\e[36mAvailable Databases:\e[0m"
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



list_db_meta() {
local database=($(ls -A "$DBSM_PATH/data/$CURRENT_DB"))  
if [[ ${#database[@]} -eq 1 ]]; then  
                  echo -e "\e[33mNO TABLES IN DATABASE YET\e[0m";
        return 
fi
local metafile="${CURRENT_DB}-meta";

echo -e "\e[36mTABLES IN DATABASE $CURRENT_DB :\e[0m"
for file in "${database[@]}"; do
      if [[ -f "$DBSM_PATH/data/$CURRENT_DB/$file" ]] && [[ ! $file =~ -meta$ ]] ; then 
        # local tableline=$(grep "^$file=header=" "$DBSM_PATH/data/$CURRENT_DB/$metafile");
         local header=$(sed -En  '/^id/p' "$DBSM_PATH/data/$CURRENT_DB/$file" 2>/dev/null );
         echo "$file" " ===columns====> " "$header";
      fi
done
}




connect_db(){
local dbname=$1
if [[ -d "$DBSM_PATH/data/$dbname" ]]; then 
   echo -e "\e[32mCONNECTION SUCCESSFUL\e[0m";
   return 0;
else
   echo -e "\e[31mCONNECTION FAILED NO DATABASE CALLED $dbname\e[0m";
   return 1
fi
}
