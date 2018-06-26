#!/bin/bash
#
# promise_smart_check.sh
#
# Checks Promise Pegasus2 SMART status, checks for ATA errors, logs and mails the output if there's an issue.
#
# Author: AB @ Modest Industries
# 
# Requires Promise Utility for Pegasus2 (https://www.promise.com), tested with v3.18.0000.18 and v4.02.0000.10.
#
# Requires sendemail for email alerts (http://caspian.dotconf.net/menu/Software/SendEmail/)
#

export DATESTAMP=`date +%Y-%m-%d\ %H:%M:%S`

# Editable variables

# Path to sendemail
sendemail_path="/usr/local/bin/sendemail"

# Send email alerts?
send_email_alert=true

# Variables for sendemail
# Sender's address
alert_sender="systems@example.ca"

# Recipient's addresses, comma separated.
#alert_recipient='recipientone@whereever.com, recipienttwo@whereever.com'
alert_recipient="systems@pretendco.com"

# SMTP server to send the messages through
alert_smtp_server="smtp.example.com"

# Promise Pegasus command line utility default path
# Version 3
# promiseutil_path="/usr/bin/promiseutil"
# Version 4
promiseutil_path="/usr/local/bin/promiseutil"

# ------------ You probably shouldn't edit below this line ------------------
# Variables

# Default the error flags to false.
smart_error_flag="false"
ata_error_flag="false"

# Alert subject
alert_subject="ALERT: Promise Pegasus2 SMART problem detected on $HOSTNAME."

# Alert header
alert_header="At $DATESTAMP, a problem was detected on this device:\n"

# Pass / Fail messages
pass_msg="Promise Pegasus SMART check successful."
fail_msg=" *** Promise Pegasus SMART check FAILED!!! ***"

# Default the message body
message_body=""

# Alert footer
alert_footer="Run 'promiseutil -C smart -v' for more information."

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

unit_ID_tmp=`mktemp -q "/tmp/$$_unit_ID.XXXX"`
if [ $? -ne 0 ]; then
        echo "$0: ERROR: Can't create temp file, exiting..."
        exit 1
fi

smart_results_tmp=`mktemp -q "/tmp/$$_smart_results.XXXX"`
if [ $? -ne 0 ]; then
        echo "$0: ERROR: Can't create temp file, exiting..."
        exit 1
fi

# ----------------- Run promiseutil, evaluate the results ------------------

# Get Unit ID information for this Promise unit. Includes workaround for promiseutil tty issue.
screen -D -m sh -c "$promiseutil_path -C subsys -v >$unit_ID_tmp"

# Drop the output into a variable.
unit_ID=$(<$tmpdir$unit_ID_tmp)

# Get the SMART report, put it into a tmp file.
screen -D -m sh -c "$promiseutil_path -C smart -v >$smart_results_tmp"

# Grab the header for each PdId in the Promise
smart_status=$(cat $smart_results_tmp | grep -A4 "^PdId")

# Check the header to see if SMART Health Check reports a problem
if grep "^SMART Health Status:" <<< "$smart_status" | grep -qv "OK"
then
        smart_error_flag="true"
fi

# Check for ATA errors, which may indicate that the drive is failing even if SMART Health is OK
# Note that "ATA Error Count" only shows up if the drive is failing.
ata_errors=$(awk '/^PdId: [1-9][0-9]*/ \
                                { a=$0; n=4; next } \
                                n { --n; a=a "\n" $0; next } \
                                /^ATA Error Count*/ \
                                { ata_err=$0; print a "\n" ata_err "\n" }' \
                                "$smart_results")
# Flag if there were ATA errors
if [ "$ata_errors" != "" ]; then
        ata_error_flag="true"
fi

# ----------------- Build the message_body ------------------

# If there's a problem, build the header.
if [ "$smart_error_flag" ==  "true" ] || [ "$ata_error_flag" == "true" ]; then
        message_body="$alert_header\n\n$fail_msg\n\n$unit_ID\n\n"

        # SMART Health status.
        if [ "$smart_error_flag" == "true" ]; then
                message_body="$message_body\nSMART Health Status is reporting one or more bad drives."
        fi

        # Always include the smart_status
        message_body="$message_body\n\n$smart_status"

        # Then the ATA errors.
        if [ "$ata_error_flag" == "true" ]; then
                message_body="$message_body\n\nOne or more drives has an ATA Error Count and may be failing.\n\n$ata_errors"
        fi
fi

#  ----------------- Logging & email ------------------

# Log the results, conditionally send email on failure.
if [ "$ata_error_flag" == "true" ] || [ "$smart_error_flag" == "true" ]; then
        message_body="$message_body\n\n$alert_footer"
        echo "$DATESTAMP: \n\n$message_body" >> /var/log/system.log
        if [ "$send_email_alert" == "true" ] ; then
                "$sendemail_path" -f $alert_sender -t $alert_recipient -u $alert_subject -m "$message_body" -s $alert_smtp_server
        fi
else
        echo "$DATESTAMP: $pass_msg\n\n$unit_ID" >> /var/log/system.log
fi

# ----------------- Cleanup ------------------

rm -f rm -f $unit_ID_tmp $smart_results_tmp
