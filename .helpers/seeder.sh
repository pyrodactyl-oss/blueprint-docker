#!/bin/bash
while ! [[ $(/usr/local/bin/php /app/artisan db:monitor) =~ OK ]]; do 
    /bin/sleep 5
done 
/usr/local/bin/php /app/artisan db:seed --class=BlueprintSeeder --force