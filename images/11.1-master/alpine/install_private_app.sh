#!/usr/bin/expect

set timeout -1
set git_password [lindex $argv 0];
set app_name [lindex $argv 1];
set app_repo_url [lindex $argv 2];
set app_repo_branch [lindex $argv 3];

# if got this error "bash: /home/frappe/install_custom_app.sh: /usr/bin/expect^M: bad interpreter: No such file or directory"
# make sure EOL is set to Unix (LF)

spawn bench get-app --branch $app_repo_branch $app_name $app_repo_url

expect "Password for*"

send "$git_password\n"

expect "$ "
