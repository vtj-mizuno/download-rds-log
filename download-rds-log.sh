#!/bin/bash

export LANG=ja_JP.UTF-8

AWSCLI=${AWSCLI:-/usr/bin/aws}
DB_ERRORLOG=${DB_ERRORLOG:-log/ERROR}
LOG_FILE=$LOGDIR/${LOG_FILE:-/var/log/sqlserver/error}
DB_INSTANCE=${DB_INSTANCE:-sqlserver}
REGION=${REGION:-us-west-2}

function usage_exit
{
    echo "Download the log of RDS and save it to a local file."
    echo "Usage: $0 [-c path_to_awscli] [-e db_error_log_filename] [-f output_filename] [-i db_instance_name] [-r AWS Region]"
    exit 1
}

while getopts c:e:f:i:r: OPT
do
    case $OPT in
        c)
            AWSCLI=$OPTARG
            ;;
        e)
            DB_ERRORLOG=$OPTARG
            ;;
        f)
            LOG_FILE=$OPTARG
            ;;
        i)
            DB_INSTANCE=$OPTARG
            ;;
        r)
            REGION=$OPTARG
            ;;
        \?)
            usage_exit
            ;;
    esac
done

LOG_DIR=$(dirname $LOG_FILE)
PREVIOUS_LOG_FILE=${LOG_FILE}.previouslog
CURRENT_LOG_FILE=${LOG_FILE}.currentlog

if [ ! -d $LOG_DIR ]; then
    mkdir -p $LOG_DIR
fi

# Download SQL Server Logs.
${AWSCLI} --region $REGION \
    rds download-db-log-file-portion \
    --db-instance-identifier $DB_INSTANCE \
    --output text \
    --log-file-name $DB_ERRORLOG \
    --no-paginate \
    --query 'LogFileData' | sed '/^$/d' > $CURRENT_LOG_FILE

if [ "$(cat $CURRENT_LOG_FILE)" == "null" -o "$(cat $CURRENT_LOG_FILE)" == "None" -o -z "$(cat $CURRENT_LOG_FILE)" ]; then
    exit
fi

# Skip over duplicate logs.
if [ -f $PREVIOUS_LOG_FILE ]; then
    # Find the line number that matches the log written last.
    PREVIOUS_LOG=$(cat $PREVIOUS_LOG_FILE)
    LINE=$(grep -F -n "$PREVIOUS_LOG" $CURRENT_LOG_FILE | tail -n 1 | cut -d ':' -f 1)
    if [ -n "$LINE" ]; then
        # The line after the written last.
        # If there is no new arrival log, nothing is written.
        tail -n +$(expr $LINE + 1) $CURRENT_LOG_FILE >> $LOG_FILE
    else
        # When all downloaded logs are new arrival logs.
        cat $CURRENT_LOG_FILE >> $LOG_FILE
    fi
else
    # If you have never written logs in the past (At first run).
    cat $CURRENT_LOG_FILE >> $LOG_FILE
fi

# Save the last written log to another file to accommodate log rotation.
tail -n 1 $CURRENT_LOG_FILE > $PREVIOUS_LOG_FILE

rm -f $CURRENT_LOG_FILE
