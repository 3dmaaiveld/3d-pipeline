
# snippet batch convert

#!/bin/bash

dirgpkg='<inputdir>'


for f in $dirgpkg/*.gpkg

do
    
    ogr2ogr -update -overwrite -f "Postgresql" PG:"host=<HOSTNAME> port=5432 dbname=<DBNAME> user=<username> password=<psw> active_schema=public" $f
    
done