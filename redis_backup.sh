#!/bin/bash
 #
 ## redis backup script

 rdb="/var/lib/redis-stack/dump.rdb"
 redis_cli="/opt/redis-stack/bin/redis-cli"

 default_backup_dir="/var/backups/redis-stack/"

 port=${1:-6379}
 backup_dir=${2:-"$default_backup_dir"}
 wait=${3:-30} ## wait for 30 seconds

 # Directories
 temp_path='/tmp'
 temp_file_name="redis-stack-dump-$(date +%Y%m%d%H%M).tar.gz"
 temp_db_file="$temp_path/$temp_file_name"

 dst="$backup_dir/$temp_file_name"

 cli="$redis_cli -p $port"

 test -d $backup_dir || {
   echo "[$port] Create backup directory $backup_dir" && mkdir -p $backup_dir
 }

 # perform a auth and bgsave before copy
 echo auth L@b$eSSi0n#2023 | $cli
 echo bgsave | $cli
 echo "[$port] waiting for $wait seconds..."
 sleep $wait
 try=5
 while [ $try -gt 0 ] ; do
   ## redis-cli output format line feed '\r\n', remove '\r'
   bg=$(echo 'info Persistence' | $cli | awk -F: '/rdb_bgsave_in_progress/{sub(/\r/, "", $0); print $2}')
   ok=$(echo 'info Persistence' | $cli | awk -F: '/rdb_last_bgsave_status/{sub(/\r/, "", $0); print $2}')
   if [[ "$bg" = "0" ]] && [[ "$ok" = "ok" ]] ; then
     # -p: keeps mode, ownership and timestamp. The command is same as --preserve=mode,ownership,timestamps
     # -u: copy only when the SOURCE file is newer than the destination file or when the destination file is missing
     tar cvf - $rdb | gzip -9 - > $temp_db_file
     cp -pu $temp_db_file $dst
     if [ $? = 0 ] ; then
       echo "[$port] redis rdb $temp_db_file copied to $dst"
       echo "Removing file $temp_db_file..."
       rm -fv $temp_db_file
       exit 0
     else
       echo "[$port] >> Failed to copy $temp_db_file to $dst!"
       echo "Removing file $temp_db_file..."
       rm -fv $temp_db_file
     fi
   fi
   try=$((try - 1))
   echo "[$port] redis maybe busy, waiting and retry in 10s..."
   sleep 10
 done

 exit 1
