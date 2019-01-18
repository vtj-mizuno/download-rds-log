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
PREVIOUS_LOG=${LOG_FILE}.prevlog
CURRENT_LOG=${LOG_FILE}.currentlog

if [ ! -d $LOG_DIR ]; then
    mkdir -p $LOG_DIR
fi

# Download SQL Server Logs.
# In order to remove unnecessary information(e.g. Marker),
# download log with json and convert only 'LogFileData' field to text.
${AWSCLI} --region $REGION \
    rds download-db-log-file-portion \
    --db-instance-identifier $DB_INSTANCE \
    --output text \
    --log-file-name $DB_ERRORLOG \
    --no-paginate \
    --query 'LogFileData' > $CURRENT_LOG

if [ "$(cat $CURRENT_LOG)" == "null" -o -z "$(cat $CURRENT_LOG)" ]; then
    exit
fi

# Extract only the new arrival logs.
# It is preferable to use 'aws logs' to compare with existing log.
# However, due to various problems, Taking diffs with previous files.
if [ -f $PREVIOUS_LOG ]; then
    diff --changed-group-format='%>' --unchanged-group-format='' $PREVIOUS_LOG $CURRENT_LOG >> $LOG_FILE
else
    cat $CURRENT_LOG >> $LOG_FILE
fi

mv -f $CURRENT_LOG $PREVIOUS_LOG
