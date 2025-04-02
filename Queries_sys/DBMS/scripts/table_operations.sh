#!/bin/bash

keywords=("select" "insert" "id" "create" "update" "delete" "drop" "alter" "table" "database" "and" "or")

validate_name(){
 entity=$1;
 entity_name=$2;
 for keyword in "${keywords[@]}"; do
        if [[ "$entity_name" == "$keyword" ]]; then
            if [[ "$entity" == "column" ]] && [[ "$entity_name" == "id" ]]; then
             echo -e "\e[33mERROR: Can't create $entity named 'id' already primary key id column is added by default please use another name for the column e.g (myid,userid,id_.... ) \e[0m"
            else
             echo -e "\e[31mERROR: Can't create $entity using reserved keyword '$entity_name'\e[0m"
            fi
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
    
    if [[ "$entity" == "column" ]] && (( ${#} > 2 )); then
       column_names=(${@:3})
       declare -i column_occur=0
       for column in ${column_names[@]}; do
         if [[  $entity_name == $column ]]; then
             (( column_occur++ ));          
         fi
         if (( $column_occur >= 2 )); then
              echo -e "\e[31mERROR: $entity_name column appear twice \e[0m"
             return 1;          
         fi
       done
    fi
 

}
create_table(){
local tablename=$1
local tableformat=$2
declare -i columncount=$(echo $tableformat | grep -o :| wc -l)
columncount+=1;
if [[ -f "$DBSM_PATH/data/$CURRENT_DB/$tablename" ]]; then 
   echo -e "\e[31mERROR TABLE ALREADY EXISTS\e[0m";
   return 1;
else
   validate_name "table" $tablename;
   if (( $? == 1 )); then
       return 1;
   fi
   local col_namescomma=$(echo "$tableformat"| sed -E 's/(:text|:int|\(|\))//g' ) 
   local col_names=($(echo "$col_namescomma" | sed -E 's/,/ /g' ))  
   tableformat=$(echo "$tableformat"| sed -E 's/\(/\(id:int,/g' ) 
   local header=$(echo "$tableformat"| sed -E 's/(:text|:int|\(|\))//g' ) 
   for col_name in "${col_names[@]}"; do
       validate_name "column" $col_name "${col_names[@]}"; 
       if (( $? == 1 )); then
        return 1;
      fi
   done
   touch "$DBSM_PATH/data/$CURRENT_DB/$tablename";
   local metafile="${CURRENT_DB}-meta";
   echo "$tablename=index=0;" >> "$DBSM_PATH/data/$CURRENT_DB/$metafile";
   echo "$tablename=header=$tableformat=$columncount" >> "$DBSM_PATH/data/$CURRENT_DB/$metafile";
   echo "$header" >> "$DBSM_PATH/data/$CURRENT_DB/$tablename"; 
fi
echo -e "\e[32mTABLE WAS CREATED SUCCESSFULLY\e[0m"
}


drop_table(){
local tablename=$1
if [[ -f "$DBSM_PATH/data/$CURRENT_DB/$tablename" ]]; then 
   local metafile=$(echo -e "${CURRENT_DB}-meta")
   rm "$DBSM_PATH/data/$CURRENT_DB/$tablename";
   grep -v "$tablename=" "$DBSM_PATH/data/$CURRENT_DB/$metafile" > tempfile && mv tempfile   "$DBSM_PATH/data/$CURRENT_DB/$metafile";
  echo -e "\e[32mDATABASE WAS DROPED SUCCESSFULLY\e[0m"
else
   echo -e "\e[31mERROR: TABLE DOESNT EXIST\e[0m";
fi
}


list_table() {
local database=($(ls -A "$DBSM_PATH/data/$CURRENT_DB"))  
if [[ ${#database[@]} -eq 1 ]]; then  
                  echo -e "\e[33mNO TABLES IN DATABASE YET\e[0m";
        return 
fi
echo -e "\e[36mTABLES IN DATABASE $CURRENT_DB :\e[0m"
for file in "${database[@]}"; do
      if [[ -f "$DBSM_PATH/data/$CURRENT_DB/$file" ]] && [[ ! $file =~ -meta$ ]] ; then 
         echo "$file";
      fi
done
}


validate_insert(){
local tableline=$1;
local column=$2;
local value=$3;
tablecolumn=($(echo "$tableline" | grep -E -o  "[,(]$column:(int|text)" | sed -E 's/(,|\:)/ /g'));
if (( ${#tablecolumn[@]} == 0 )); then
  return 1;
fi
if [[ ${tablecolumn[1]} = "int" ]] && [[ ! "$value" =~ ^[0-9]+$ ]]; then
  return 2;
fi
if [[ $column == "id" ]] ; then
  return 3;
fi
}

####################################################################
######################## INSERT ####################################
##################################################################

insert_into_table(){
local tablename=$1
local insertformat=$2
  if [[ ! -f "$DBSM_PATH/data/$CURRENT_DB/$tablename" ]] || [[  $file =~ -meta$ ]] ; then 
            echo -e "\e[31m$tablename DOESNT EXIST OR NON EDITABLE\e[0m";
            return 1;
  fi
insertarray=($(echo $insertformat | sed -E 's/=values=/ /g'))
colarray=($(echo ${insertarray[0]} | sed -E 's/(\(|\)|,)/ /g'))
valarray=($(echo ${insertarray[1]} | sed -E 's/(\(|\)|,)/ /g'))
local metafile="$CURRENT_DB-meta";
if [[ ! ${#colarray[@]} -eq ${#valarray[@]}  ]]; then
   echo -e "\e[31mERROR NUMBER OF VALUES AND COLUMNS DOESNT MATCH\e[0m";
   return 1;
fi
local tableline=$(grep "^$tablename=header=" "$DBSM_PATH/data/$CURRENT_DB/$metafile");
#echo "$tableline" | grep -o ")=[^)=]*$" | sed -E 's/(\)|=|;)//g'
declare -i columncount=$(echo "$tableline" | grep -o ")=[^)=]*$" | sed -E 's/(\)|=|;)//g');

if [[ ${#colarray[@]} -gt $columncount  ]]; then
   echo -e "\e[31mERROR INPUT COLUMNS NUMBER IS MORE THAN TABLE COLUMN NUMBER\e[0m";
   return 1;
fi
declare -i counter=0;
while (( $counter < ${#colarray[@]}  )); do
   validate_insert $tableline ${colarray[$counter]} ${valarray[$counter]};
   declare -i result=$?;
   if (( $result == 1 )); then
          echo -e "\e[31mERROR:COLUMN NAME ${colarray[$counter]} DOESNT EXISTS IN $tablename\e[0m";
          return 1;
   elif (( $result == 2 ));  then
          echo -e "\e[31mERROR:COLUMN ${colarray[$counter]} HAS DIFFERENT DATA TYPE\e[0m";
          return 1;
   elif (( $result == 3 ));  then
          echo -e "\e[33mWARNING: COLUMN ${colarray[$counter]} IS AUTO INCREMENTED AND ONLY SET BY THE SYSTEM\e[0m";
   fi
   (( counter+=1 ));
done 
grep "$tablename=index=[0-9]*;" "$DBSM_PATH/data/$CURRENT_DB/$metafile" | sed -E "s/(index=|;)//g"
declare -i rownumber=$(grep "$tablename=index=[0-9]*;" "$DBSM_PATH/data/$CURRENT_DB/$metafile" | sed -E "s/(index=|;)//g");
echo $rownumber;
(( rownumber+=1 ));
insertrow="$rownumber,"
max=8
for ((i=0; i<columncount-2; i++)); do
    insertrow="$insertrow,"
done
echo $insertrow >> "$DBSM_PATH/data/$CURRENT_DB/$tablename";
sed -i -E "s/$tablename=index=[0-9]*;/$tablename=index=$rownumber;/g" "$DBSM_PATH/data/$CURRENT_DB/$metafile"
declare -i  filerow=$(cat "$DBSM_PATH/data/$CURRENT_DB/$tablename" | wc -l) ;
counter=0;
while (( $counter < ${#colarray[@]}  )); do
if [[ ${colarray[$counter]} == "id" ]]; then 
   (( counter+=1 ));
   continue;
fi
awk -v value="${valarray[$counter]}" -v  column="${colarray[$counter]}" -v row="$filerow" -f "$DBSM_PATH/scripts/awk/awk_insert" "$DBSM_PATH/data/$CURRENT_DB/$tablename" > tmp && mv tmp "$DBSM_PATH/data/$CURRENT_DB/$tablename"
(( counter+=1 ));
done    
 echo -e "\e[32mNEW ROW WAS INSERTED SUCCESSFULLY\e[0m"
}


validate_column(){
local tableline=$1
local column=$2
tablecolumn=($(echo "$tableline" | grep -E -o  "[,(]$column:(int|text)" | sed -E 's/(,|\:)/ /g'));
if (( ${#tablecolumn[@]} == 0 )); then
  return 1;
fi
}


####################################################################
######################## SELECT ####################################
##################################################################

select_from_table(){
local table_name=$1;
  if [[ ! -f "$DBSM_PATH/data/$CURRENT_DB/$tablename" ]] || [[  $file =~ -meta$ ]] ; then 
            echo -e "\e[31m$tablename DOESNT EXIST OR NON VIEWABLE\e[0m";
            return 1;
  fi
local select_columns=$2;
local condition=$3;
local col_names="";
local metafile="$CURRENT_DB-meta"
local tableline=$(grep "^$tablename=header=" "$DBSM_PATH/data/$CURRENT_DB/$metafile");
local condarray=($(echo $condition | sed -E 's/(=|<|>|<=|>=|!=)/ /g'))
if [[ ! $condition == "" ]]; then
   validate_column $tableline ${condarray[0]} ;
   if [[ $? = 1 ]]; then
        echo -e "\e[31mCOLUMN NAME ${condarray[0]} DOESNT EXISTS IN $tablename\e[0m";
        return 1;
   fi
 fi

colarray=($(echo $selectcolumns | sed -E 's/,/ /g'))
declare -i counter=0;
while (( $counter < ${#colarray[@]}  )); do
   validate_column $tableline ${colarray[$counter]} ;
   if [[ $? = 1 ]]; then
          echo -e "\e[31mCOLUMN NAME ${colarray[$counter]} DOESNT EXISTS IN $tablename\e[0m";
          return 1;
   fi
   (( counter+=1 ));
done 
declare -i hits=$(awk -v cond="$condition" -f "$DBSM_PATH/scripts/awk/awk_validate" -f "$DBSM_PATH/scripts/awk/awk_count"   "$DBSM_PATH/data/$CURRENT_DB/$tablename");
echo -e "\e[36m$hits MATCHES FOUND: \e[0m";
awk -v cols="$select_columns" -v cols_num="${#colarray[@]}" -v  cond="$condition"  -f "$DBSM_PATH/scripts/awk/awk_validate" -f "$DBSM_PATH/scripts/awk/awk_select"  "$DBSM_PATH/data/$CURRENT_DB/$tablename"  ;
} 


####################################################################
######################## DELETE ####################################
##################################################################

delete_from_table(){
local tablename="$1";
  if [[ ! -f "$DBSM_PATH/data/$CURRENT_DB/$tablename" ]] || [[  $file =~ -meta$ ]] ; then 
            echo -e "\e[31m$tablename DOESNT EXIST OR NON EDITABLE\e[0m";
            return 1;
  fi
local condition="$2";
local metafile="$CURRENT_DB-meta";
local condarray=($(echo $condition | sed -E 's/(=|<|>|<=|>=|!=)/ /g'))
local tableline=$(grep "^$tablename=header=" "$DBSM_PATH/data/$CURRENT_DB/$metafile");
 if [[ ! $condition == "" ]]; then
   validate_column $tableline ${condarray[0]} ;
   if [[ $? = 1 ]]; then
        echo -e "\e[31mCOLUMN NAME ${condarray[0]} DOESNT EXISTS IN $tablename\e[0m";
        return 1;
   fi
 fi
declare -i hits=$(awk -v cond="$condition" -f "$DBSM_PATH/scripts/awk/awk_validate" -f "$DBSM_PATH/scripts/awk/awk_count"   "$DBSM_PATH/data/$CURRENT_DB/$tablename");
if ((  $hits > 0)); then
awk -v cond="$condition" -f "$DBSM_PATH/scripts/awk/awk_validate" -f "$DBSM_PATH/scripts/awk/awk_delete"   "$DBSM_PATH/data/$CURRENT_DB/$tablename"  > tmp && mv tmp "$DBSM_PATH/data/$CURRENT_DB/$tablename";
fi
echo -e "\e[32mQUERY EXECUTED SUCCESSFULLY\e[0m";
echo -e "\e[32m$hits ROW/s DELETED\e[0m";

} 

####################################################################
######################## UPDATE ####################################
##################################################################


update_table(){
 local tablename="$1";
   if [[ ! -f "$DBSM_PATH/data/$CURRENT_DB/$tablename" ]] || [[  $file =~ -meta$ ]] ; then 
            echo -e "\e[31m$tablename DOESNT EXIST OR NON EDITABLE\e[0m";
            return 1;
  fi
 local update_values="$2";
 local condition="$3";
 local metafile="$CURRENT_DB-meta";
 local  colarray=($(echo $update_values | sed -E 's/=/ /g'));
 local condarray=($(echo $condition | sed -E 's/(=|<|>|<=|>=|!=)/ /g'));
 local tableline=$(grep "^$tablename=header=" "$DBSM_PATH/data/$CURRENT_DB/$metafile");
 validate_insert $tableline ${colarray[0]} "${colarray[1]}" ;
 declare -i result=$?;
 if (( $result == 1 )); then
        echo -e "\e[31mERROR:COLUMN NAME ${colarray[0]} DOESNT EXISTS IN $tablename\e[0m";
        return 1;
 elif (( $result == 2 )); then
          echo -e "\e[31mERROR:COLUMN ${colarray[0]} HAS DIFFERENT DATA TYPE\e[0m";
          return 1;
    elif (( $result == 3 )); then
          echo -e "\e[31mERROR: COLUMN ${colarray[0]} IS AUTO INCREMENTED AND ONLY SET BY THE SYSTEM UPDATE IS FORBIDDEN\e[0m";
          return 1;
 fi
 
 if [[ ! $condition == "" ]]; then
   validate_column $tableline ${condarray[0]} ;
   if [[ $? = 1 ]]; then
        echo -e "\e[31mCOLUMN NAME ${condarray[0]} DOESNT EXISTS IN $tablename\e[0m";
        return 1;
   fi
 fi

declare -i hits=$(awk -v cond="$condition" -f "$DBSM_PATH/scripts/awk/awk_validate" -f "$DBSM_PATH/scripts/awk/awk_count"   "$DBSM_PATH/data/$CURRENT_DB/$tablename")
if ((  $hits > 0)); then
awk -v col="${colarray[0]}" -v val="${colarray[1]}" -v  cond="$condition" -f "$DBSM_PATH/scripts/awk/awk_validate" -f "$DBSM_PATH/scripts/awk/awk_update" "$DBSM_PATH/data/$CURRENT_DB/$tablename"  > tmp && mv tmp "$DBSM_PATH/data/$CURRENT_DB/$tablename";
fi
echo -e "\e[32mQUERY EXECUTED SUCCESSFULLY\e[0m";
echo -e "\e[32m$hits ROW/s UPDATED\e[0m";
} 

