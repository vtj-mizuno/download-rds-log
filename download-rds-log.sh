#!/bin/bash

AWSCLI=${AWSCLI:-/usr/bin/aws}

DB_ERRORLOG=${DB_ERRORLOG:-log/ERROR}
REGION=${REGION:-us-west-2}
DB_INSTANCE=${DB_INSTANCE:-sqlserver}
LOG_FILE=$LOGDIR/${LOGFILE:-/var/log/sqlserver/error}

LOG_DIR=$(dirname $LOG_FILE)
PREVIOUS_LOG=${LOG_DIR}/${DB_INSTANCE}-prevlog
CURRENT_LOG=${LOG_DIR}/${DB_INSTANCE}-currentlog

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

if [ ! -d $LOG_DIR ]; then
    mkdir -p $LOG_DIR
fi

# Download SQL Server Logs.
# In order to remove unnecessary information(e.g. Marker),
# download log with json and convert only 'LogFileData' field to text.
${AWSCLI} --region $REGION \
    rds download-db-log-file-portion \
    --db-instance-identifier $DB_INSTANCE \
    --output json \
    --log-file-name $DB_ERRORLOG | jq -r '.LogFileData' > $CURRENT_LOG

# Extract only the new arrival logs.
# It is preferable to use 'aws logs' to compare with existing log.
# However, due to various problems, Taking diffs with previous files.
if [ -f $PREVIOUS_LOG ]; then
    diff --changed-group-format='%>' --unchanged-group-format='' $PREVIOUS_LOG $CURRENT_LOG >> $LOG_FILE
else
    cat $CURRENT_LOG >> $LOG_FILE
fi

mv -f $CURRENT_LOG $PREVIOUS_LOG
