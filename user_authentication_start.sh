#!/bin/bash
## to be updated to match your settings
PROJECT_HOME="."
credentials_file="$PROJECT_HOME/data/credentials.txt"
logged_in_file="$PROJECT_HOME/.logged_in"


setup() {
    if [ -s "$PROJECT_HOME/.logged_in" ]; then
        logged_in_user=$(cat "$PROJECT_HOME/.logged_in")
        signed_in=true
    else
        signed_in=false
    fi
}

get_credentials() {
    read -p 'Username: ' user
    read -rs -p 'Password: ' pass
    echo
}

generate_salt() {
    openssl rand -hex 8
    return 0
}

hash_password() {
    password=$1
    salt=$2
    echo -n "${password}${salt}" | sha256sum | awk '{print $1}'
    return 0
}

check_existing_username(){
    username=$1
    if grep -q "^$username:" "$credentials_file"; then
        return 0
    fi
    return 1
}

register_credentials() {
    username=$1
    password=$2
    fullname=$3
    role=${4:-"normal"}

    if check_existing_username $username; then
        echo "Error: The username already exists"
        return 1
    fi
    if [ "$role" != "normal" ] && [ "$role" != "salesperson" ] && [ "$role" != "admin" ]; then
        echo
        echo "Error: Invalid role.][] Role should be normal, salesperson, or admin."
        return 1
    fi
    salt=`generate_salt`
    hashed_pwd=`hash_password $password $salt`
    echo "$username:$hashed_pwd:$salt:$fullname:$role:0" >> "$credentials_file"
    echo "Registration successful!"
}

verify_credentials() {
    username=$1
    password=$2
    stored_line=$(grep "^$username:" "$credentials_file")
    if [ -z "$stored_line" ]; then
        echo "Invalid username."
        return 1
    fi
    stored_hash=$(echo "$stored_line" | cut -d ":" -f 2)
    stored_salt=$(echo "$stored_line" | cut -d ":" -f 3)
    computed_hash=$(hash_password "$password" "$stored_salt")
    if [ "$computed_hash" == "$stored_hash" ]; then
        sed -i "/^$username:/s/.$/1/" "$credentials_file"
        signed_in=true
        filename=".logged_in"
        if [ ! -f $filename ]
        then
            touch $filename
        fi
        echo $username> $filename
        echo
        echo "Login successful. Welcome, $username!"
    else
        echo "Invalid password."
        return 1
    fi
}

logout() {
    if [ -s "$logged_in_file" ]; then
        logged_in_user=$(cat "$logged_in_file")
        > "$logged_in_file"
        sed -i "/^$logged_in_user:/s/.$/0/" "$credentials_file"
        signed_in=false
        echo "Logout successful. Goodbye, $logged_in_user!"
    else
        echo "No user is currently logged in."
    fi
}

delete_account(){
    username=$(cat "$logged_in_file")
    if [[ "$username" == "admin" ]]
    then
        echo
        echo "Can not delete superadmin"
    else
        password=$1
        stored_line=$(grep "^$username:" "$credentials_file")
        if [ -z "$stored_line" ]; then
            echo "Invalid username."
            return 1
        fi
        stored_hash=$(echo "$stored_line" | cut -d ":" -f 2)
        stored_salt=$(echo "$stored_line" | cut -d ":" -f 3)
        computed_hash=$(hash_password "$password" "$stored_salt")
        if [ "$computed_hash" == "$stored_hash" ]; then
            logged_in_user=$(cat "$logged_in_file")
            > "$logged_in_file"
            sed -i "/^$logged_in_user/d" "$credentials_file"
            signed_in=false
            echo "Account deleted"
        else
            echo "Invalid password."
            return 1
        fi
    fi
    

}

register_credentials_admin() {
    username=$1
    password=$2
    fullname=$3
    role=$4

    if check_existing_username $username; then
        echo "Error: The username already exists"
        return 1
    fi
    if [ "$role" != "normal" ] && [ "$role" != "salesperson" ] && [ "$role" != "admin" ]; then
        echo
        echo "Error: Invalid role. Role should be normal, salesperson, or admin."
        return 1
    fi
    salt=`generate_salt`
    hashed_pwd=`hash_password $password $salt`
    echo "$username:$hashed_pwd:$salt:$fullname:$role:0" >> "$credentials_file"
    echo "Registration successful!"
}

start_program(){
    setup
    while true; do
        if [ "$signed_in" = true ]
        then
            username=$(cat "$logged_in_file")
            stored_line=$(grep "^$username:" "$credentials_file")
            IFS=: 
            read -ra arr <<< "$stored_line" 
            role="${arr[4]}"
            if [ "$role" = "admin" ]
            then
                echo "Admin panel"
                echo "1. Add user"
                echo "2. Logout"
                echo "3. Exit"
                echo "4. Delete Account"
            else
                echo "User panel"
                echo "1. Switch account"
                echo "2. Register"
                echo "3. Exit"
                echo "4. Delete Account"
                echo "5. Logout"
            fi
        else
            echo "1. Login"
            echo "2. Register"
            echo "3. Exit"
        fi
        read -p "Enter your choice: " choice
        
        if [ "$role" = "admin" ]
        then
            case $choice in
                1)
                    read -p 'Username: ' user
                    read -rs -p 'Password: ' pass
                    echo
                    read -p 'Full name: ' name
                    read -p 'Role: ' role
                    echo
                    register_credentials_admin "$user" "$pass" "$name" "$role"
                    ;;
                2)
                    if [ "$signed_in" = true ]
                    then
                        logout
                    else
                        echo "Invalid choice. Please input a valid choice"
                    fi
                    ;; 
                3)
                    exit
                    ;; 
                4)
                    read -rs -p "Enter password: " password
                    delete_account $password
                    ;;
                *)
                    echo "Invalid choice. Please input a valid choice"
                    ;;
            esac

        else
            case $choice in
                1)
                    get_credentials
                    verify_credentials "$user" "$pass"
                    ;;
                2)
                    read -p "Enter username: " username
                    read -rs -p "Enter password: " password
                    echo
                    read -p "Enter your full name: " fullname
                    register_credentials $username $password $fullname
                    ;;
                3)
                    exit
                    ;; 
                4)
                    if [ "$signed_in" = true ]
                    then
                        read -rs -p "Enter password: " password
                        delete_account $password
                    else
                        echo "Invalid choice. Please input a valid choice"
                    fi
                    ;;
                5)
                    if [ "$signed_in" = true ]
                    then
                    logout
                    else
                        echo "Invalid choice. Please input a valid choice"
                    fi
                    ;; 
                *)
                    echo "Invalid choice. Please input a valid choice"
                    ;;
            esac
        fi
        
    done
}

echo "Welcome to the authentication system."
start_program
