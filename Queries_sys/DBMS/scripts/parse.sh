#!/bin/bash



source db_operations.sh
source table_operations.sh 



parseCreate() {
            if [[ ${#} -lt 3 ]]; then
                echo -e "\e[31mTOO FEW ARGUMENTS FOR CREATE \e[0m";
                return 1;
            fi
            case ${2,,} in 
              "database")
                if [[ ${#} -gt 3 ]]; then
                   echo -e "\e[31mTOO MANY ARGUMENTS FOR CREATE DATABASE \e[0m";
                   return 1;
                else
                    create_db $3;
                 fi
                ;;
               "table")
                if ! $CONNECTED; then
                   echo -e "\e[31mYOU ARE NOT CONNECTED TO DATABASE \e[0m";
                   return 1;
                fi    
                if [[ ${#} -lt 4 ]]; then
                   echo -e "\e[31mTOO FEW ARGUMENTS FOR CREATE TABLE \e[0m";
                   return 1;
                fi
                VALID_TABLE_FORMAT='^\([[:space:]]*([a-z][a-z0-9_]*[[:space:]]*(int|text)[[:space:]]*)[[:space:]]*(,[[:space:]]*[a-z_][a-z0-9_]*[[:space:]]*(int|text)[[:space:]]*)*[[:space:]]*\)[[:space:]]*$'
                if [[ ! "${@:4}" =~ $VALID_TABLE_FORMAT ]]; then
                   echo -e "\e[31mInvalid table \e[36mformat: table_name  (column_name TYPE (int or text only),....)\e[0m";
                   return 1
                fi
                TABLE_FORMAT=$(echo "${@:4}" | sed -E 's/[[:space:]]//g; s/(text|int)/:\1/g')
                create_table $3  $TABLE_FORMAT
                ;;
                *)
                   echo -e "\e[31mWRONG CREATE STATEMENT \e[0m";
                   return 1;
                ;;
           esac

}





parseDrop() {
            if [[ ! ${#} -eq 3 ]]; then
                echo -e "\e[31mWRONG NUMBER OF ARGUMENTS FOR DROP  \e[0m";
                return 1;
            fi
            case ${2,,} in 
              "database")
                  drop_db $3;
                ;;
               "table")
                if $CONNECTED; then
                   drop_table $3;
                else 
                  echo -e "\e[31mYOU ARE NOT CONNECTED TO A DATABASE \e[0m";
                   return 1;
                fi
                ;;
                *)
                   echo -e "\e[31mWRONG DROP STATEMENT \e[0m";
                   return 1;
                ;;
           esac
}


parseList() {
            if [[ ! ${#} -eq 2 ]]; then
                echo -e "\e[31mWRONG NUMBER OF ARGUMENTS FOR LIST  \e[0m";
                return 1;
            fi
            case ${2,,} in 
              "database")
                  list_db  ;
                ;;
               "table")
                if $CONNECTED; then
                    list_table ;
                else 
                  echo -e "\e[31mYOU ARE NOT CONNECTED TO A DATABASE \e[0m";
                   return 1;
                fi
                ;;
               "meta")
                if $CONNECTED; then
                    list_db_meta ;
                else 
                  echo -e "\e[31mYOU ARE NOT CONNECTED TO A DATABASE \e[0m";
                   return 1;
                fi
                ;;
                *)
                   echo -e "\e[31mWRONG LIST STATEMENT \e[0m";
                   return 1;
                ;;
           esac
}


 parseInsert() {
    if ! $CONNECTED; then
            echo -e "\e[31mYOU ARE NOT CONNECTED TO DATABASE \e[0m";
            return 1;
    fi    
    if [[ ${#} -lt 6 ]]; then
        echo -e "\e[31mTOO FEW ARGUMENTS FOR INSERT \e[0m"
        return 1
    fi

    if [[ ! ${2,,} = "into" ]]; then
        echo -e "\e[31mMISSING INTO AFTER INSERT \e[0m"
        return 1
    fi


    VALID_INSERT_FORMAT='^\([[:space:]]*[a-z_][a-z0-9_]*([[:space:]]*,[[:space:]]*[a-z_][a-z0-9_]*)*[[:space:]]*\)[[:space:]]*values[[:space:]]*\([[:space:]]*[^()]*([[:space:]]*,[[:space:]]*[^()]*)*[[:space:]]*\)$'


    input_part="${@:4}"
    
    

    if [[ ! "$input_part" =~ $VALID_INSERT_FORMAT ]]; then
        echo -e "\e[31mInvalid format. Use: (col1,col2,...) values (val1,val2,...)\e[0m"
        return 1
    fi


    VALUES_FORMAT=$(echo "$input_part" | sed -E 's/(values)/=\1=/g; s/[[:space:]]//g')
    set +f
    insert_into_table "$3" "$VALUES_FORMAT"
}

parseSelect() {
             if ! $CONNECTED; then
                   echo -e "\e[31mYOU ARE NOT CONNECTED TO DATABASE \e[0m";
                   return 1;
             fi    

            if [[  ${#} -lt 4 ]]; then
                echo -e "\e[31mTOO FEW ARGUMENTS FOR SELECT \e[0m"
                return 1;
            fi  
            declare -i fromcount=$(echo ${@} | grep -o ' from ' | wc -l)
             if (( $fromcount != 1 )); then
                echo -e "\e[31mFROM SHOULD BE USED EXCATLY ONCE IN SELECT STATEMENT \e[0m"
                return 1;
            fi
            declare -a array=(${@});
            declare -i frompos=0;
            declare -i counter=0;
            while (( counter < ${#})); do
                 if [[ ${array[$counter]} = "from"  ]]; then             
                 frompos=$counter;
                 break;
                 fi
            counter+=1;
            done
             declare -i beforefrom=$frompos-1;
             declare -i afterfrom=$frompos+1;
             selectcolumns=$(echo ${@:2:$beforefrom} | sed -E "s/ //g");
             tablename=$(echo ${array[$afterfrom]});
             local condition="";
             if (( afterfrom + 1 < ${#array[@]} )); then  
                if [[ ${array[$afterfrom+1]} != "where" ]] || (( afterfrom + 2 >= ${#array[@]} ))
                  then
                  echo -e "\e[31mINVALID SELECT: CONDITION MUST BE AFTER WHERE IF EXISTS\e[0m"
                 return 1
                fi
                 condition="${@:afterfrom+3}"
             fi
             condition=$(echo "$condition" | sed -E "s/\<and\>/\&/g; s/\<or\>/|/g; s/ +//g")
             local header=$(sed -En  '/^id/p' "$DBSM_PATH/data/$CURRENT_DB/$tablename" 2>/dev/null );
             selectcolumns=$(echo $selectcolumns | sed -E "s/\*/$header/g");
             set +f;
             select_from_table $tablename $selectcolumns $condition ;

}



parseDelete() {
            if ! $CONNECTED; then
             echo -e "\e[31mYOU ARE NOT CONNECTED TO DATABASE \e[0m";
             return 1;
            fi    
            if [[  ${#} -lt 3 ]]; then
                echo -e "\e[31mTOO FEW ARGUMENTS FOR DELETE \e[0m"
                return 1;
            fi

             if [[ ! $2 = "from" ]]; then
                echo -e "\e[31mFROM EXPECTED AFTER DELETE KEYWORD\e[0m"
                return 1;
            fi
             tablename=$3;
             local condition="";
             if ((  ${#} > 3 )); then  
                if [[ $4 != "where" ]]  || (( 5 > ${#} ));  then
                  echo -e "\e[31mINVALID DELETE: CONDITION MUST BE AFTER WHERE IF EXISTS\e[0m";
                 return 1
                fi
                 condition="${@:5}"
             fi
             condition=$(echo "$condition" | sed -E "s/\<and\>/\&/g; s/\<or\>/|/g; s/ +//g")
             set +f;
             delete_from_table $tablename  $condition ;

}

parseUpdate() {

     if ! $CONNECTED; then
          echo -e "\e[31mYOU ARE NOT CONNECTED TO DATABASE \e[0m";
          return 1;
     fi   
     if [[ ${#} -lt 4 ]]; then
        echo -e "\e[31mTOO FEW ARGUMENTS FOR UPDATE\e[0m"
        return 1;
    fi

    local tablename=$2
    
    if [[ $3 != "set" ]]; then
        echo -e "\e[31mSET EXPECTED AFTER TABLE NAME IN UPDATE\e[0m"
        return 1;
    fi

    local update_values="";
    local i=4;
    while (( i <= ${#} )); do
        if [[ ${!i} == "where" ]] ||  (( $i == ${#} )) ; then
            break 
        fi
        update_values+="${!i} "
        ((i++));
    done
    update_values=$(echo "$update_values" | sed -E 's/ +$//')

    if ! [[ $update_values =~ ^([a-zA-Z0-9_]+\s*=\s*[a-zA-Z0-9_]+)(\s*,\s*[a-zA-Z0-9_]+\s*=\s*[a-zA-Z0-9_]+)*$ ]]; then
        echo -e "\e[31mERROR:INVALID UPDATE FORMAT: EXPECTED 'column=value'\e[0m"
        return 1
    fi
    
    local condition="";
    array=(${@})
  #  echo ${#array[@]}
  #  echo $i 
    if (( $i  <= ${#array[@]} )); then  
         if  (( $i + 1 > ${#array[@]} )); then
                echo -e "\e[31mINVALID UPDATE condition "
                return 1;
         fi
    condition=${@:i+1};
    fi
    condition=$(echo "$condition" | sed -E "s/\<and\>/\&/g; s/\<or\>/|/g; s/ +//g")
    set +f;
    update_table $tablename $update_values $condition ;    
}




parseConnect() {
            if [[ ! ${#} -eq 2 ]]; then
                echo -e "\e[31mWRONG NUMBER OF ARGUMENTS FOR CONNECT  \e[0m";
                return 1;
            fi
            connect_db $2;
}





parse() {
     case $1 in
        "create") 
           parseCreate $@
           ;;
         "drop") 
           parseDrop $@
           ;;
         "list") 
           parseList $@
           ;;
         "insert") 
           parseInsert $@
           ;;
         "select") 
           parseSelect $@
           ;;
         "delete") 
           parseDelete $@
           ;;
         "update") 
           parseUpdate  $@
           ;;
         "connect") 
           parseConnect $@
           ;;
          
    esac
}
set -f;
parse ${@,,}


