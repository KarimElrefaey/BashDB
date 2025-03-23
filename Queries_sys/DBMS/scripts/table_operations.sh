#!/bin/bash

keywords=("select" "insert" "id" "create" "update" "delete" "drop" "alter" "table" "database" "and" "or")
create_table(){
local tablename=$1
local tableformat=$2
declare -i columncount=$(echo $tableformat | grep -o :| wc -l)
columncount+=1;
if [[ -f "$DBSM_PATH/data/$CURRENT_DB/$tablename" ]]; then 
   echo -e "\e[31mERROR TABLE ALREADY EXISTS\e[0m";
else
   for keyword in "${keywords[@]}"; do
        if [[ "$tablename" == "$keyword" ]]; then
            echo -e "\e[31mERROR: Can't create table using reserved keyword '$tablename'\e[0m"
            return 1
        fi
    done
   touch "$DBSM_PATH/data/$CURRENT_DB/$tablename";
   local metafile="${CURRENT_DB}_meta"
   echo "$tablename=index=0;" >> "$DBSM_PATH/data/$CURRENT_DB/$metafile";
   echo "$tablename=$tableformat=$columncount=" >> "$DBSM_PATH/data/$CURRENT_DB/$metafile";
   local header=$(echo "$tableformat"| sed -E 's/(:text|:int|\(|\))//g' ) 
   local col_names=($(echo "$header"| sed -E 's/,//g' ))
   for col_name in "${col_names[@]}"; do
       for keyword in "${keywords[@]}"; do
        if [[ "$col_name" == "$keyword" ]]; then
            echo -e "\e[31mERROR: Can't have column using reserved keyword '$col_name'\e[0m"
            return 1
        fi
    done
    done
   header="id,$header";
   echo "$header" >> "$DBSM_PATH/data/$CURRENT_DB/$tablename";
   
fi
}


drop_table(){
local tablename=$1
if [[ -f "$DBSM_PATH/data/$CURRENT_DB/$tablename" ]]; then 
   local metafile=$(echo -e "$CURRENT_DB" "\b_meta")
   rm "$DBSM_PATH/data/$CURRENT_DB/$tablename";
   grep -v $tablename $metafile > tempfile && mv tempfile $metafile

else
   echo -e "\e[31mTABLE DOESNT EXIST>\e[0m";
fi
}


list_table() {
echo -e "\e[34mTABLES IN DATABASE:\e[0m"
local database=($(ls -A "$DBSM_PATH/$CURRENT_DB/data"))  
if [[ ${#database[@]} -eq 0 ]]; then  
        echo "No Tables in database."
        return
fi
for file in "${database[@]}"; do
      if [[ -f "$DBSM_PATH/data/$CURRENT_DB/$file" ]] && [[ ! $file =~ _meta$ ]] ; then 
         echo "$file";
      fi
done
}


validate_insert(){
local tableline=$1
local column=$2
local value=$3
tablecolumn=($(echo "$tableline" | grep -E -o  "[,(]$column:(int|text)" | sed -E 's/(,|\:)/ /g'));
if (( ${#tablecolumn[@]} == 0 )); then
  return 1;
fi
if [[ ${tablecolumn[1]} = "int" ]] && [[ ! "$value" =~ ^[0-9]+$ ]]; then
  return 2;
fi
}


insert_into_table(){
local tablename=$1
local insertformat=$2
insertarray=($(echo $insertformat | sed -E 's/=values=/ /g'))
colarray=($(echo ${insertarray[0]} | sed -E 's/(\(|\)|,)/ /g'))
valarray=($(echo ${insertarray[1]} | sed -E 's/(\(|\)|,)/ /g'))
local metafile=$(echo "$CURRENT_DB" "_meta" | sed -E "s/ //g")
if [[ ! ${#colarray[@]} -eq ${#valarray[@]}  ]]; then
   echo -e "\e[31mERROR NUMBER OF VALUES AND COLUMNS DOESNT MATCH\e[0m";
   return 1;
fi
local tableline=$(grep "^$tablename=" "$DBSM_PATH/data/$CURRENT_DB/$metafile");
declare -i columncount=$(echo "$tableline" | grep -o "=[^=]*$" | sed -E 's/=//')

if [[ ${#colarray[@]} -gt $columncount  ]]; then
   echo -e "\e[31mERROR INPUT COLUMNS NUMBER IS MORE THAN TABLE COLUMN NUMBER\e[0m";
   return 1;
fi
declare -i counter=0;
while (( $counter < ${#colarray[@]}  )); do
   validate_insert $tableline ${colarray[$counter]} ${valarray[$counter]};
   if [[ $? = 1 ]]; then
          echo -e "\e[31mCOLUMN NAME ${colarray[$counter]} DOESNT EXISTS IN $tablename\e[0m";
          return 1;
   elif [[ $? = 2 ]]; then
          echo -e "\e[31mCOLUMN ${colarray[$counter]} HAS DIFFERENT DATA TYPE\e[0m";
          return 1;
   fi
   (( counter+=1 ));
done 
declare -i rownumber=$(grep "^$tablename=index=[0-9]*;" "$DBSM_PATH/data/$CURRENT_DB/$metafile" | sed -E "s/(index=|;)//g");
(( rownumber+=1 ));
insertrow="$rownumber,"
max=8
for ((i=0; i<columncount-2; i++)); do
    insertrow="$insertrow,"
done
echo $insertrow >> "$DBSM_PATH/data/$CURRENT_DB/$tablename";
sed -i -E "1s/^$tablename=index=[0-9]*;/$tablename=index=$rownumber;/g" "$DBSM_PATH/data/$CURRENT_DB/$metafile"
declare -i  filerow=$(cat "$DBSM_PATH/data/$CURRENT_DB/$tablename" | wc -l) ;
counter=0;
while (( $counter < ${#colarray[@]}  )); do
awk -v value="${valarray[$counter]}" -v  column="${colarray[$counter]}" -v row="$filerow" -f "$DBSM_PATH/scripts/awk/awk_insert" "$DBSM_PATH/data/$CURRENT_DB/$tablename" > tmp && mv tmp "$DBSM_PATH/data/$CURRENT_DB/$tablename"
(( counter+=1 ));
done    
}


validate_column(){
local tableline=$1
local column=$2
tablecolumn=($(echo "$tableline" | grep -E -o  "[,(]$column:(int|text)" | sed -E 's/(,|\:)/ /g'));
if (( ${#tablecolumn[@]} == 0 )); then
  return 1;
fi
}

select_from_table(){
local table_name=$1;
local select_columns=$2;
local condition=$3;
local col_names=""
local metafile=$(echo "$CURRENT_DB" "_meta" | sed -E "s/ //g")
local tableline=$(grep "^$tablename=" "$DBSM_PATH/data/$CURRENT_DB/$metafile");
local condarray=($(echo $condition | sed -E 's/=/ /g'))
validate_column $tableline ${condarray[0]} ;
 if [[ $? = 1 ]]; then
        echo -e "\e[31mCOLUMN NAME ${condarray[0]} DOESNT EXISTS IN $tablename\e[0m";
        return 1;
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
awk -v cols="$select_columns" -v cols_num="${#colarray[@]}" -v  cond="$condition"  -f "$DBSM_PATH/scripts/awk/awk_validate" -f "$DBSM_PATH/scripts/awk/awk_select"  "$DBSM_PATH/data/$CURRENT_DB/$tablename"  ;
} 

delete_from_table(){
local tablename="$1";
local condition="$2";
local metafile=$(echo "$CURRENT_DB" "_meta" | sed -E "s/ //g")
local condarray=($(echo $condition | sed -E 's/=/ /g'))
local tableline=$(grep "^$tablename=" "$DBSM_PATH/data/$CURRENT_DB/$metafile");
validate_column $tableline ${condarray[0]} ;
 if [[ $? = 1 ]]; then
        echo -e "\e[31mCOLUMN NAME ${condarray[0]} DOESNT EXISTS IN $tablename\e[0m";
        return 1;
 fi
awk -v cond="$condition" -f "$DBSM_PATH/scripts/awk/awk_validate" -f "$DBSM_PATH/scripts/awk/awk_delete"   "$DBSM_PATH/data/$CURRENT_DB/$tablename"  > tmp && mv tmp "$DBSM_PATH/data/$CURRENT_DB/$tablename";
} 


update_table(){
 local tablename="$1";
 local update_values="$2";
 local condition= "$3";
 local metafile=$(echo "$CURRENT_DB" "_meta" | sed -E "s/ //g")
 local  colarray=($(echo $update_values | sed -E 's/=/ /g'))
 local condarray=($(echo $condition | sed -E 's/=/ /g'))
 local tableline=$(grep "^$tablename=" "$DBSM_PATH/data/$CURRENT_DB/$metafile");
 validate_insert $tableline ${colarray[0]} "${colarray[1]}" ;
 if [[ $? = 1 ]]; then
        echo -e "\e[31mCOLUMN NAME ${colarray[0]} DOESNT EXISTS IN $tablename\e[0m";
        return 1;
 elif [[ $? = 2 ]]; then
          echo -e "\e[31mCOLUMN ${colarray[0]} HAS DIFFERENT DATA TYPE\e[0m";
          return 1;
 fi
  validate_column $tableline ${condarray[0]} ;
 if [[ $? = 1 ]]; then
        echo -e "\e[31mCOLUMN NAME ${condarray[0]} DOESNT EXISTS IN $tablename\e[0m";
        return 1;
 fi
awk -v col="${colarray[0]}" -v val="${colarray[1]}" -v  cond="$condition" -f "$DBSM_PATH/scripts/awk/awk_validate" -f "$DBSM_PATH/scripts/awk/awk_update" "$DBSM_PATH/data/$CURRENT_DB/$tablename"  > tmp && mv tmp "$DBSM_PATH/data/$CURRENT_DB/$tablename";
} 

