#!/bin/sh
#########################################################################################
# Crontab example:
# */5 * * * * root /usr/local/sbin/checafila.sh
#########################################################################################
export PATH="$PATH:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
#########################################################################################
# For Mysql postfixadmin database
#########################################################################################
DBHOST="localhost"
DBUSER="vmailadmin"
DBPASSWD="change mysql password"
DBNAME="vmail"
#########################################################################################
# Some configs
#########################################################################################
# Limite maximo de envios nas ultimas N linhas do mail.log por user.
NRCPTLIMIT=500
# Número de linhas para pesquisa no mail.log
NLOGLINES=50000
ARQ="/tmp/checafila.txt"
DATA=`date +%d/%m-%H:%M`
DIA=`date +%d`
HOST=`hostname -s`
HEADER_CHECKS="/etc/postfix/header_checks.pcre"
MAIL_LOG="/var/log/mail.log"
MAIL_TO="postmaster@localhost"
echo="/bin/echo"
# Users que não serão bloqueados, um email por linha.
EXCLUDE="/etc/postfix/checafila.EXCLUDE"
#########################################################################################
# Main
#########################################################################################
$echo "" > $ARQ
touch /tmp/blocked.txt

tail -n $NLOGLINES $MAIL_LOG|awk '$0~/postfix\/qmgr/&&$0~/nrcpt=/ {print $6,$7,$9}'|\
grep -v -f $EXCLUDE|sort|uniq|\
awk -F"from=<" '{print $2}'|awk -F">, nrcpt=" '{print $1,$2}'|\
awk '{a[$1]+= $2;}END{for(i in a){print a[i],i;}}'|sort -nr|head|grep -v -f /tmp/blocked.txt|\
while read TOT USER; do

 if [ $TOT -ge $NRCPTLIMIT ]; then
  # For mysql users database
        $echo -e "blocking $USER\t$TOT NRCPT IN Mysql" >>$ARQ
        mysql -B -h$DBHOST -u$DBUSER -p$DBPASSWD -D$DBNAME -e \
        "UPDATE mailbox SET active = '0' WHERE username = '$USER' LIMIT 1 ;" 2>&1 >>$ARQ


        # put $USER in header_checks too
        $echo "/^from:.*$USER/ REJECT $DATA NRCPT = $TOT" >> $HEADER_CHECKS

$echo $USER >>/tmp/blocked.txt
#########################################################################################
# For Zimbra:
#########################################################################################
#   su - zimbra -c "zmprov ma $USER  zimbraAccountStatus locked"
#   su - zimbra -c "zmprov -s SET-YOUR-DOMAIN-HERE.com flushCache account $USER"
#########################################################################################
# Reload postfix
postfix reload 2>&1 >>$ARQ

#########################################################################################
# Mailing info to admin
#########################################################################################
 $echo "Bloqueou o $USER $TOT" >> $ARQ
 $echo "------------------------------------------------------------->" >> $ARQ
 $echo "Roda a cada 10 minutos na $HOST" >> $ARQ
 $echo "a fila de email foi apagada desse usuario" >> $ARQ
 $echo "Limite para bloqueio e $NRCPTLIMIT" >> $ARQ
 $echo "Se a fila estiver maior que $QLIMIT apaga os emails do usuario" >> $ARQ
 $echo "PRG: $0" >> $ARQ


    # Remove the $USER from mailq
     /usr/local/sbin/rmqueue $USER 2>&1 >>$ARQ
     $echo "Apagou a fila do $USER $TOT" >>$ARQ
     cat $ARQ | mail $MAIL_TO -s "BLOQUEIO $HOST DIA:$DIA"
 fi
done
