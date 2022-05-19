BEGIN {
        n=1
}
{
        gsub(/;/,"",$3);
        gsub(/;/,"",$2);
        if($0 ~ /proxy_set_header Host/){
                hosts[n]=$3;
        }
        if($0 ~ /proxy_set_header X-Api-Key/){
                keys[n]=$3;
        }
        if($0 ~ /proxy_pass/){
                urls[n]=$2;
                n=n+1;
        }
}
END {
        for(i=1;i<n;i++){
                print keys[i],hosts[i],urls[i];
        }
}
