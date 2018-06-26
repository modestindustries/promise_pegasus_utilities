#!/bin/bash
#
# promise_enclosure_check.sh
#
# Checks the status of a Promise Pegasus2 RAID enclosure and mails the output if there's an issue.
#
# Author: AB @ Modest Industries
#
# Works with Promise Utility for Pegasus2 v3.18.0000.18 (http://www.promise.com)
# Requires sendemail for email alerts (http://caspian.dotconf.net/menu/Software/SendEmail/)
#
# Edit History
# 2014-04-21 - AB: Version 1.0.
# 2014-05-08 - AB: Refinements.
# 2014-05-09 - AB: Better message_body if failed.

export DATESTAMP=`date +%Y-%m-%d\ %H:%M:%S`

# Editable variables

# Path to sendemail
sendemail_path="/Library/Scripts/Monitoring/sendemail"

# If a problem is found, send email?
send_email_alert=true

# Variables for sendemail
# Sender's address
alert_sender="systems@example.com"

# Recipient's addresses, comma separated.
#alert_recipient='recipientone@whereever.com, recipienttwo@whereever.com'
alert_recipient="systems@whereever.com"

# SMTP server to send the messages through
alert_smtp_server="smtp.example.com"

# ------------ Do not edit below this line ------------------
# Variables

# Pass / fail flags
enclosure_pass=true

# The subject line of the alert.
alert_subject="Alert: Promise Pegasus2 enclosure problem detected on $HOSTNAME."

# Alert header
alert_header="At $DATESTAMP, an enclosure problem was detected on this device:\n"

# Pass / Fail messages
pass_msg="Promise Pegasus Enclosure check successful."
fail_msg=" *** Promise Pegasus Enclosure check FAILED!!! ***\n\n"

# Alert footer
alert_footer="Run 'promiseutil -C enclosure -v' for more information."

# Create temp files
unit_ID_tmp=`mktemp "/tmp/$$_unit_ID.XXXX"`
enclosure_results_tmp=`mktemp "/tmp/$$_enclosure_results.XXXX"`

message_body="$alert_header"

# Get the information for this Promise unit. Includes workaround for promiseutil tty issue.
screen -D -m sh -c "promiseutil -C subsys -v >$unit_ID_tmp"

# Drop the output into a variable.
unit_ID=$(<$unit_ID_tmp)

# Get the report, put it into a tmp file.
screen -D -m sh -c "promiseutil -C enclosure >$enclosure_results_tmp"

if ! grep -qv "Enclosure is OK" $enclosure_results_tmp
then
        enclosure_pass="false"
        # Get a more detailed report, put it into a tmp file.
        screen -D -m sh -c "promiseutil -C enclosure -v >$enclosure_results_tmp"

        # Build the message.
        message_body=$message_body$fail_header$unit_ID$(<$enclosure_results_tmp)
fi

#  ----------------- Logging & email ------------------

# Log the results, conditionally send email on failure.
if [ "$enclosure_pass" == "false" ]; then
        message_body="$message_body\n\n$alert_footer"
        echo "$DATESTAMP: \n\n$message_body" >> /var/log/system.log
        if [ "$send_email_alert" == "true" ] ; then
                "$sendemail_path" -f $alert_sender -t $alert_recipient -u $alert_subject -m "$message_body" -s $alert_smtp_server
        fi
else
        echo "$DATESTAMP: $pass_msg" >> /var/log/system.log
fi

# Cleanup
rm -f rm -f $unit_ID_tmp $enclosure_results_tmp