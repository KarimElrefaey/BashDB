#!/bin/bash


 characters
validate_name() {
    local input=$1
    if [[ $input =~ ^[a-zA-Z0-9_]+$ ]]; then
        return 0
    else
        return 1
    fi
}


create_database() {
    clear
    echo -e "========== Create Database =========="
    read -p "Enter database name: " db_name
    
    if ! validate_name "$db_name"; then
        print_message "error" "Database name should only contain alphanumeric characters and underscore"
        read -p "Press Enter to continue..."
        return
    fi
    
    if [ -d "$db_name" ]; then
        print_message "error" "Database already exists!"
    else
        mkdir -p "$db_name"
        print_message "success" "Database created successfully!"
    fi
    read -p "Press Enter to continue..."
}

list_databases() {
    clear
    echo -e "========== Available Databases =========="
    
    
    if [ -z "$(ls -d */ 2>/dev/null)" ]; then
        print_message "info" "No databases found!"
    else
        echo "Databases:"
        ls -d */ 2>/dev/null | sed 's/\///'
    fi
    read -p "Press Enter to continue..."
}


connect_to_database() {
    clear
    echo -e "========== Connect to Database =========="
    read -p "Enter database name: " db_name
    
    if [ -d "$db_name" ]; then
        print_message "success" "Connected to $db_name database!"
        sleep 1
        database_menu "$db_name"
    else
        print_message "error" "Database does not exist!"
        read -p "Press Enter to continue..."
    fi
}

drop_database() {
    clear
    echo -e "========== Drop Database =========="
    read -p "Enter database name to drop: " db_name
    
    if [ -d "$db_name" ]; then
        read -p "Are you sure you want to drop '$db_name' database? (y/n): " confirm
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            rm -rf "$db_name"
            print_message "success" "Database dropped successfully!"
        else
            print_message "info" "Operation cancelled!"
        fi
    else
        print_message "error" "Database does not exist!"
    fi
    read -p "Press Enter to continue..."
}


create_table() {
    local db_name=$1
    clear
    echo -e "========== Create Table in $db_name =========="
    
    read -p "Enter table name: " table_name
    
    if ! validate_name "$table_name"; then
        print_message "error" "Table name should only contain alphanumeric characters and underscore"
        read -p "Press Enter to continue..."
        return
    fi
    
    if [ -f "$db_name/$table_name.metadata" ]; then
        print_message "error" "Table already exists!"
        read -p "Press Enter to continue..."
        return
    fi
    
    read -p "Enter number of columns: " col_count
    
   
    if ! [[ "$col_count" =~ ^[0-9]+$ ]]; then
        print_message "error" "Column count must be a number!"
        read -p "Press Enter to continue..."
        return
    fi
    
    if [ "$col_count" -lt 1 ]; then
        print_message "error" "Number of columns must be at least 1!"
        read -p "Press Enter to continue..."
        return
    fi
    
    declare -a col_names
    declare -a col_types
    
    echo "Note: First column will be treated as Primary Key"
    
    for ((i=0; i<col_count; i++)); do
        read -p "Enter name for column $((i+1)): " col_name
        
        if ! validate_name "$col_name"; then
            print_message "error" "Column name should only contain alphanumeric characters and underscore"
            read -p "Press Enter to continue..."
            return
        fi
        
       
        for existing in "${col_names[@]}"; do
            if [ "$existing" = "$col_name" ]; then
                print_message "error" "Column name already used!"
                read -p "Press Enter to continue..."
                return
            fi
        done
        
        col_names[$i]=$col_name
        
        select type in "string" "number"; do
            case $type in
                string)
                    col_types[$i]="string"
                    break
                    ;;
                number)
                    col_types[$i]="number"
                    break
                    ;;
                *)
                    echo "Invalid option. Please select 1 for string or 2 for number."
                    ;;
            esac
        done
    done
    
 
    echo "$table_name" > "$db_name/$table_name.metadata"
    echo "$col_count" >> "$db_name/$table_name.metadata"
    
    # Write column names and types to metadata
    for ((i=0; i<col_count; i++)); do
        echo "${col_names[$i]},${col_types[$i]}" >> "$db_name/$table_name.metadata"
    done
    
   
    touch "$db_name/$table_name.data"
    
    print_message "success" "Table created successfully!"
    read -p "Press Enter to continue..."
}


list_tables() {
    local db_name=$1
    clear
    echo -e "========== Tables in $db_name =========="
    
   
    if [ -z "$(ls "$db_name"/*.metadata 2>/dev/null)" ]; then
        print_message "info" "No tables found!"
    else
        echo "Tables:"
        for table in "$db_name"/*.metadata; do
            basename "$table" .metadata
        done
    fi
    read -p "Press Enter to continue..."
}


drop_table() {
    local db_name=$1
    clear
    echo -e "${BLUE}========== Drop Table from $db_name ==========${NC}"
    
    read -p "Enter table name to drop: " table_name
    
    if [ -f "$db_name/$table_name.metadata" ]; then
        read -p "Are you sure you want to drop '$table_name' table? (y/n): " confirm
        if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
            rm -f "$db_name/$table_name.metadata" "$db_name/$table_name.data"
            print_message "success" "Table dropped successfully!"
        else
            print_message "info" "Operation cancelled!"
        fi
    else
        print_message "error" "Table does not exist!"
    fi
    read -p "Press Enter to continue..."
}


insert_into_table() {
    local db_name=$1
    clear
    echo -e "========== Insert into Table in $db_name =========="
    
    read -p "Enter table name: " table_name
    
    if [ ! -f "$db_name/$table_name.metadata" ]; then
        print_message "error" "Table does not exist!"
        read -p "Press Enter to continue..."
        return
    fi
    

    col_count=$(sed -n '2p' "$db_name/$table_name.metadata")
    

    declare -a col_names
    declare -a col_types
    

    line_num=3
    for ((i=0; i<col_count; i++)); do
        IFS=',' read -r name type <<< "$(sed -n "${line_num}p" "$db_name/$table_name.metadata")"
        col_names[$i]=$name
        col_types[$i]=$type
        ((line_num++))
    done
    

    read -p "Enter value for ${col_names[0]} (Primary Key): " pk_value
    
    # Check if primary key already exists
    if grep -q "^$pk_value," "$db_name/$table_name.data" 2>/dev/null; then
        print_message "error" "Primary Key value already exists!"
        read -p "Press Enter to continue..."
        return
    fi
    
 
    row_data="$pk_value"
    

    for ((i=1; i<col_count; i++)); do
        while true; do
            read -p "Enter value for ${col_names[$i]}: " col_value
            
       
            if [ "${col_types[$i]}" = "number" ]; then
                if ! [[ "$col_value" =~ ^[0-9]+$ ]]; then
                    print_message "error" "Value must be a number for this column!"
                    continue
                fi
            fi
            
        
            col_value=${col_value//,/\\,}
            
            break
        done
       
        row_data="$row_data,$col_value"
    done
    

    echo "$row_data" >> "$db_name/$table_name.data"
    
    print_message "success" "Data inserted successfully!"
    read -p "Press Enter to continue..."
}


select_from_table() {
    local db_name=$1
    clear
    echo -e "========== Select From Table in $db_name =========="
    
    read -p "Enter table name: " table_name
    
    if [ ! -f "$db_name/$table_name.metadata" ]; then
        print_message "error" "Table does not exist!"
        read -p "Press Enter to continue..."
        return
    fi
    

    col_count=$(sed -n '2p' "$db_name/$table_name.metadata")
    

    declare -a col_names
    
 
    line_num=3
    for ((i=0; i<col_count; i++)); do
        IFS=',' read -r name type <<< "$(sed -n "${line_num}p" "$db_name/$table_name.metadata")"
        col_names[$i]=$name
        ((line_num++))
    done
    
    echo -e "Table: $table_name"
    

    header=""
    separator=""
    for ((i=0; i<col_count; i++)); do
  
        padding=15
        col_len=${#col_names[$i]}
        if [ $col_len -gt $padding ]; then
            padding=$col_len
        fi
        
      
        header+="$(printf "%-${padding}s" "${col_names[$i]}")"
        separator+="$(printf "%-${padding}s" "$(echo "${col_names[$i]}" | sed 's/./=/g')")"
    done
    
    echo "$header"
    echo "$separator"
    
 
    if [ ! -s "$db_name/$table_name.data" ]; then
        echo "No data found in table!"
    else
      
        while IFS= read -r line; do
            row=""
            IFS=',' read -ra values <<< "$line"
            
            for ((i=0; i<col_count; i++)); do
                padding=15
                col_len=${#col_names[$i]}
                if [ $col_len -gt $padding ]; then
                    padding=$col_len
                fi
                
               
                if [ -n "${values[$i]}" ]; then
                    # Unescape commas
                    display_value=${values[$i]//\\,/,}
                    row+="$(printf "%-${padding}s" "$display_value")"
                else
                    row+="$(printf "%-${padding}s" "NULL")"
                fi
            done
            
            echo "$row"
        done < "$db_name/$table_name.data"
    fi
    
    read -p "Press Enter to continue..."
}


delete_from_table() {
    local db_name=$1
    clear
    echo -e "========== Delete From Table in $db_name =========="
    
    read -p "Enter table name: " table_name
    
    if [ ! -f "$db_name/$table_name.metadata" ]; then
        print_message "error" "Table does not exist!"
        read -p "Press Enter to continue..."
        return
    fi
    
   
    pk_name=$(sed -n '3p' "$db_name/$table_name.metadata" | cut -d',' -f1)
    
    read -p "Enter $pk_name value to delete: " pk_value
    
   
    if ! grep -q "^$pk_value," "$db_name/$table_name.data" 2>/dev/null; then
        print_message "error" "Record with $pk_name=$pk_value does not exist!"
        read -p "Press Enter to continue..."
        return
    fi
    

    grep -v "^$pk_value," "$db_name/$table_name.data" > "$db_name/$table_name.tmp"
    

    mv "$db_name/$table_name.tmp" "$db_name/$table_name.data"
    
    print_message "success" "Record deleted successfully!"
    read -p "Press Enter to continue..."
}


update_row() {
    local db_name=$1
    clear
    echo -e "========== Update Row in $db_name =========="
    
    read -p "Enter table name: " table_name
    
    if [ ! -f "$db_name/$table_name.metadata" ]; then
        print_message "error" "Table does not exist!"
        read -p "Press Enter to continue..."
        return
    fi
    
    
    col_count=$(sed -n '2p' "$db_name/$table_name.metadata")
    
    
    declare -a col_names
    declare -a col_types
    
    
    line_num=3
    for ((i=0; i<col_count; i++)); do
        IFS=',' read -r name type <<< "$(sed -n "${line_num}p" "$db_name/$table_name.metadata")"
        col_names[$i]=$name
        col_types[$i]=$type
        ((line_num++))
    done
    
   
    read -p "Enter ${col_names[0]} (Primary Key) value to update: " pk_value
    
    
    if ! grep -q "^$pk_value," "$db_name/$table_name.data" 2>/dev/null; then
        print_message "error" "Record with ${col_names[0]}=$pk_value does not exist!"
        read -p "Press Enter to continue..."
        return
    fi
    
   
    current_row=$(grep "^$pk_value," "$db_name/$table_name.data")
    IFS=',' read -ra current_values <<< "$current_row"
    
   
    new_row="$pk_value"
    

    for ((i=1; i<col_count; i++)); do

        echo "Current ${col_names[$i]}: ${current_values[$i]//\\,/,}"
        
        read -p "Enter new value for ${col_names[$i]} (leave empty to keep current): " new_value
        
        
        if [ -z "$new_value" ]; then
            new_value=${current_values[$i]}
        else
        
            if [ "${col_types[$i]}" = "number" ]; then
                if ! [[ "$new_value" =~ ^[0-9]+$ ]]; then
                    print_message "error" "Value must be a number for this column!"
                    read -p "Press Enter to continue..."
                    return
                fi
            fi
            
            new_value=${new_value//,/\\,}
        fi
        
       
        new_row="$new_row,$new_value"
    done
    
 
    {
        grep -v "^$pk_value," "$db_name/$table_name.data"
        echo "$new_row"
    } > "$db_name/$table_name.tmp"
    
    
    mv "$db_name/$table_name.tmp" "$db_name/$table_name.data"
    
    print_message "success" "Record updated successfully!"
    read -p "Press Enter to continue..."
}

database_menu() {
    local db_name=$1
    local choice
    
    while true; do
        clear
        echo -e "========== Database: $db_name =========="
        echo "1. Create Table"
        echo "2. List Tables"
        echo "3. Drop Table"
        echo "4. Insert into Table"
        echo "5. Select From Table"
        echo "6. Delete From Table"
        echo "7. Update Row"
        echo "8. Back to Main Menu"
        echo "9. Exit"
        
        read -p "Enter your choice [1-9]: " choice
        
        case $choice in
            1) create_table "$db_name" ;;
            2) list_tables "$db_name" ;;
            3) drop_table "$db_name" ;;
            4) insert_into_table "$db_name" ;;
            5) select_from_table "$db_name" ;;
            6) delete_from_table "$db_name" ;;
            7) update_row "$db_name" ;;
            8) return ;;
            9) exit 0 ;;
            *) print_message "error" "Invalid option. Please try again." 
               read -p "Press Enter to continue..." ;;
        esac
    done
}

main_menu() {
    local choice
    
    while true; do
        clear
        echo -e "========== Bash Shell Script DBMS =========="
        echo "1. Create Database"
        echo "2. List Databases"
        echo "3. Connect To Database"
        echo "4. Drop Database"
        echo "5. Exit"
        
        read -p "Enter your choice [1-5]: " choice
        
        case $choice in
            1) create_database ;;
            2) list_databases ;;
            3) connect_to_database ;;
            4) drop_database ;;
            5) exit 0 ;;
            *) print_message "error" "Invalid option. Please try again." 
               read -p "Press Enter to continue..." ;;
        esac
    done
}

main_menu
