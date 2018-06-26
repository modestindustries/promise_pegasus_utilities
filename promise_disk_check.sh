#!/bin/bash
#
# promise_disk_check.sh
#
# Checks the phydrv status of a Promise Pegasus, logs and mails the output if there's an issue.
#
# Author: A @ Modest Industries
#
# Requires Promise Utility for Pegasus2 (https://www.promise.com), tested with v3.18.0000.18 and v4.02.0000.10.

# Requires sendemail for email alerts (http://caspian.dotconf.net/menu/Software/SendEmail/)

export DATESTAMP=`date +%Y-%m-%d\ %H:%M:%S`

# Editable variables

# Path to sendemail
sendemail_path="/usr/local/bin/sendemail"

# Email alert?
send_email_alert=true

# Variables for sendemail
# Sender's address
alert_sender="alert@example.com"

# Recipient's addresses, comma separated.
#alert_recipient='recipientone@whereever.com, recipienttwo@whereever.com'
alert_recipient="systems@example.com"

# SMTP server to send the messages through
# alert_smtp_server="smtp.example.com:port"
alert_smtp_server="smtp.example.com"

# Subject line of the alert.
alert_subject="Alert: Promise disk problem detected on $HOSTNAME."

# Header line at the top of the alert message 
alert_header="At $DATESTAMP, a problem was detected on this device:\n"

# Pass / Fail messages
pass_msg="*** Promise disk check successful ***"
fail_msg=" *** Promise disk check FAILED!!! ***"

# Promise Pegasus command line utility default path
# Version 3
# promiseutil_path="/usr/bin/promiseutil"
# Version 4
promiseutil_path="/usr/local/bin/promiseutil"

# ------------ Do not edit below this line ------------------
# Variables
pass=true
results=""

# ----------------- Check for promiseutil, sendemail & set up temp files ------------------
if [ ! -f $promiseutil_path ]; then
        echo "$0 ERROR: $promiseutil_path does not exist"
        echo  "Please download and install the Promise Pegasus Utility app from https://www.promise.com"
        exit 1
fi

if [ ! -f $sendemail_path ]; then
        echo "$0 ERROR: $sendemail_path does not exist"
        echo  "Please download from http://caspian.dotconf.net/menu/Software/SendEmail/ and then set the \$sendmemail_path variable inside this script"
        exit 1
fi

unit_ID_tmp=`mktemp -q "/tmp/$$unit_ID.XXXX"`
if [ $? -ne 0 ]; then
        echo "$0: ERROR: Can't create temp file, exiting..."
        exit 1
fi

results_tmp=`mktemp -q "/tmp/$$_results.XXXX"`
if [ $? -ne 0 ]; then
        echo "$0: ERROR: Can't create temp file, exiting..."
        exit 1
fi


# Get header information for this Promise unit. Includes workaround for promiseutil tty issue.
screen -D -m sh -c "promiseutil -C subsys -v >$tmpdir$unit_ID_tmp"
unit_ID=$(<$tmpdir$unit_ID_tmp)

# Get status of the disks.  Includes workaround for promiseutil tty issue.
screen -D -m sh -c "promiseutil -C phydrv >$tmpdir$results_tmp"

# Check each line of the output the test results.
while read -r line
do
        if grep '^[0-9]' <<< "$line" | grep -Eqv 'OK|Media'
        then
                results=$results"BAD DRIVE DETECTED: $line\n\n"
                pass=false
        fi
done < $tmpdir$results_tmp

# Log the results, conditionally send email on failure.
if [ "$pass" = false ] ; then
        results="$alert_header$unit_ID\n\n$results\n$alert_footer"
        echo "$DATESTAMP: $fail_msg\n\n$results" >> /var/log/system.log
        if [ "$send_email_alert" = true ] ; then
                "$sendemail_path" -f $alert_sender -t $alert_recipient -u $alert_subject -m "$results" -s $alert_smtp_server -xu systems@copiouscom.com -xp "a;ghslut"
        fi
else
        echo "$DATESTAMP: $pass_msg" >> /var/log/system.log
fi

# Cleanup
rm -f $tmpdir$unit_ID_tmp $tmpdir$results_tmp
