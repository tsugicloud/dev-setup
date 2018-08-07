
x="d1,sakaiger d2,sakaiger"
for i in $x; do
  echo $i
  host=`echo $i | awk -F',' '{print $1}'`
  admin=`echo $i | awk -F',' '{print $2}'`
  dbpw=pw_$(($RANDOM+$RANDOM*$RANDOM))
  echo Host $host admin $dbpw
done

