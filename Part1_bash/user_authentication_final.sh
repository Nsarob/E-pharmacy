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

    check_existing_username "$username"
    # if it exists, safely fails
    result=$?

    if check_existing_username $username; then
        echo "Error: The username already exists"
    
    else

        if [ -z "$role" ]; then
            role="normal"
        fi

        is_logged_in="0"  # is_logged_in is "0" for new registrations
        
        
        ## check if the role is valid. Should be either normal, salesperson, or admin
        if [[ "$role" != "normal" && "$role" != "salesperson" && "$role" != "admin" ]]; then
            echo $'\n'"Invalid role. Choose either normal, salesperson, or admin."$'\n'
            return 1
        fi


        salt=`generate_salt`
        hashed_pwd=`hash_password $password $salt`
        stored_line="${username}:${hashed_pwd}:${salt}:${fullname}:${role}:${is_logged_in}"
        # append the line to the credential file
        echo "$stored_line" >> "$credentials_file"
        echo $'\n'"Registration successful!"$'\n'

    fi

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

      # Check that the .logged_in file exists and is not empty
    if [ -s "$login_file" ]; then
        # Read the content of the .logged_in file to retrieve the username
        username=$(cat "$login_file")
        # Delete the existing .logged_in file
        rm "$login_file"
        # Update the credentials file to change the last field to 0
        record=$(grep "$username" "$credentials_file")
        sed -i "s/$stored_line$/$username:$stored_hash:$salt:$fullname:$role:0/" $credentials_file 
        echo $'\n'"Logout successful. Goodbye, $username!"$'\n'
    else
        echo $'\n'"You are not currently logged in."$'\n'
        return 1
    fi
}

## Create the menu for the application
# at the start, we need an option to login, self-register (role defaults to normal)
# and exit the application.

# After the user is logged in, display a menu for logging out.
# if the user is also an admin, add an option to create an account using the 
# provided functions.

register_menu(){
    echo $'\n'"===== User Registration ====="$'\n'
               read -r -p 'Username: ' username
               read -r -s -p 'Password: ' password 
               read -r -p $'\n''Enter name: ' fullname
               read -r -p 'Enter role (admin/normal/salesperson): ' role

}

admin_login(){
    if [ "$role" == "admin" ]; then
    echo "Select an option: "
    echo "1. Log out"
    echo "2. Register a user"

    read -r -p $'\n'"Enter your choice: " choice

    case $choice in
            1) logout
                ;;

            2) register_menu
               register_credentials "$username" "$password" "$fullname" "$role"
               ;;

    esac

    else
        echo $'\n'"***Select an option: "$'\n'
        echo "1. Log out"

        read -r -p "Enter your choice: " choice

        case $choice in
                1) logout
                    ;;
        esac

    fi

}

delete_account(){
    stored_line=$(grep "$username" "$credentials_file")
    # if there is no line, then return 1 and output "Invalid username"

    if [[ -z "$stored_line" ]] ; then
        echo "Invalid username."
        return 1
    fi
    stored_hash=$(echo "$stored_line" | cut -d: -f2)  
    salt=$(echo "$stored_line" | cut -d: -f3)

    ## compute the hash based on the provided password
    generate_hash=$(hash_password "$password" "$salt")
    ## compare to the stored hash
    ### if the hashes match, delete line with the record
    
    if [ "$generate_hash" == "$stored_hash" ]; then
     #delete
     sed -i "/$username/d" "$credentials_file"
     echo $'\n'"Account successfully deleted."$'\n'

    else
        echo $'\n'"Invalid password"$'\n'
        return 1

    fi
    

}

main_menu(){
    echo "***Select an option: "
    echo "1. Login"
    echo "2. Register"
    echo "3. Delete account"
    echo "4. Logout"
    echo "5. Close the Program"

    read -r -p $'\n'"Enter your choice: " choice

     case $choice in
            1) echo $'\n'"===== Login ====="$'\n'
                get_credentials
                verify_credentials "$user" "$pass"
                ;;
            
            2) register_menu
               register_credentials "$username" "$password" "$fullname" "$role"
               ;;

            3) echo $'\n'"===== Delete Account ====="$'\n'
               get_credentials
               delete_account
               ;;

            4) logout
                ;;

            5) exit 0
                ;;

     esac
                
}

# Main script execution starts here
echo $'\n'"Welcome to the authentication system."$'\n'
while true; do
    main_menu
done