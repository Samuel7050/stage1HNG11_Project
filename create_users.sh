
#!/bin/bash

# Check if the input file is provided
if [ $# -ne 1 ]; then
    echo "Usage: $0 <input_file>"
    exit 1
fi

INPUT_FILE=$1
LOG_FILE="/var/log/user_management.log"
PASSWORD_FILE="/var/secure/user_passwords.txt"

# Check if the file exists
if [ ! -f "$INPUT_FILE" ]; then
    echo "File not found: $INPUT_FILE"
    exit 1
fi

# Ensure the secure directory exists and set permissions
sudo mkdir -p /var/secure
sudo chmod 700 /var/secure

# Initialize log and password files
sudo touch $LOG_FILE $PASSWORD_FILE
sudo chmod 600 $PASSWORD_FILE
sudo chown root:root $PASSWORD_FILE

# Function to generate a random password
generate_password() {
    openssl rand -base64 12
}

# Read the input file line by line
while IFS=';' read -r user groups; do
    # Check if the user already exists
    if id "$user" &>/dev/null; then
        echo "User $user already exists." | sudo tee -a $LOG_FILE
    else
        # Generate a random password
        password=$(generate_password)
        
        # Create the user with a home directory and set the password
        sudo useradd -m -s /bin/bash "$user"
        echo "$user:$password" | sudo chpasswd
        
        # Log the creation and password
        echo "User $user created with home directory." | sudo tee -a $LOG_FILE
        echo "$user:$password" | sudo tee -a $PASSWORD_FILE
        
        # Set the permissions and ownership of the home directory
        sudo chmod 700 /home/$user
        sudo chown $user:$user /home/$user
        
        # Assign groups to the user
        IFS=',' read -r -a group_array <<< "$groups"
        for group in "${group_array[@]}"; do
            # Check if the group exists
            if ! getent group "$group" &>/dev/null; then
                # Create the group if it does not exist
                sudo groupadd "$group"
                echo "Group $group created." | sudo tee -a $LOG_FILE
            fi
            sudo usermod -aG "$group" "$user"
            echo "User $user added to group $group." | sudo tee -a $LOG_FILE
        done
    fi
done < "$INPUT_FILE"

echo "User creation, group assignment, and logging completed." | sudo tee -a $LOG_FILE

