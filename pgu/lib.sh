#!/bin/sh

init() {
    # temp files
    resp=`mktemp /tmp/curl-pgu-json.XXXXX`
    cjar=`mktemp /tmp/curl-pgu-cookies.XXXXX`
    # get cookies
    curl -c $cjar -s https://login.mos.ru/eaidit/eaiditweb/openouterlogin.do > /dev/null
}
cleanup() {
    # remove temp files
    [ -e "$cjar" ] && rm $cjar
    [ -e "$resp" ] && rm "$resp"
}

loginPgu() {
    # replace @ with %40 in login
    login=`echo "$login"|sed -e 's/@/%40/'`
    # post login data and check redirect URL - doesnt' work
#    if ! curl -c $cjar -b $cjar -s -D - -o /dev/null -d "username=$login&password=$password" https://login.mos.ru/eaidit/eaiditweb/outerlogin.do | grep -qF "https://login.mos.ru/eaidit/eaiditweb/loginok.do"; then
    # post login data, follow redirects, check resulting page
    if ! curl -c $cjar -b $cjar -s -L -d "username=$login&password=$password" https://login.mos.ru/eaidit/eaiditweb/outerlogin.do | grep -q "Your login was successful"; then
        echo "Login failed!" >&2
        cleanup
        exit 1
    fi
}

getWaterCounterIds() {
    eval `cat $resp |  jq -r '.counter | sort_by(.type)[] | "type", .type, .counterId' | paste -sd '_=;' -`
}

getWaterIndications() {
    # get water counters
    curl -c $cjar -b $cjar -s -d "getCountersInfo=true&requestParams%5Bpaycode%5D=$paycode" https://pgu.mos.ru/ru/application/guis/1111/
}

removeWaterIndication() {
    curl -c $cjar -b $cjar -s -d "removeCounterIndication=true&values%5Bpaycode%5D=$paycode&values%5BcounterId%5D=$1" https://pgu.mos.ru/ru/application/guis/1111/ > /dev/null
}

setWaterIndications() {
    hot="$1"
    cold="$2"
    [ "$hot" -gt "$cold" ] && echo "Error: Hot counter value ($hot) > cold counter value ($cold)!" && exit 1
    curl -c $cjar -b $cjar -s -d "addCounterInfo=true&values%5Bpaycode%5D=$paycode&values%5Bindications%5D%5B0%5D%5BcounterNum%5D=$type_2&values%5Bindications%5D%5B0%5D%5BcounterVal%5D=$hot&values%5Bindications%5D%5B0%5D%5Bperiod%5D=$dt&values%5Bindications%5D%5B0%5D%5Bnum%5D=&values%5Bindications%5D%5B1%5D%5BcounterNum%5D=$type_1&values%5Bindications%5D%5B1%5D%5BcounterVal%5D=$cold&values%5Bindications%5D%5B1%5D%5Bperiod%5D=$dt&values%5Bindications%5D%5B1%5D%5Bnum%5D=" https://pgu.mos.ru/ru/application/guis/1111/  > /dev/null
}

printMosenergoLastValue() {
    echo "Previously sent values:"
    echo "Date		T1	T2	T3"
    curl -c $cjar -b $cjar -s -d "getAction=auth&ls=$mosenergo_accnum&pu=$mosenergo_cntnum" https://pgu.mos.ru/ru/application/mosenergo/counters/ \
        | jq -r ".fields | .count_submit_date, .count_t1, .count_t2, .count_t3"  | paste -sd '			\n' -
}

setMosenergoIndications() {
    echo "Not implemented yet"
}

getLastDayOfMonth() {
    if [ `uname` = "Linux" ]; then
        dt=`date -d "$(date +'%Y-%m-1') +1 month -1 day" +'%Y-%m-%d'`
    else
        dt=`date -v1d -v+1m -v-1d +'%Y-%m-%d'`
    fi
}

printWaterHistory() {
    echo "History of values"
    echo "Date		Hot	Cold"
    cat $resp | jq -r ".counter | sort_by(.type)[] | .indications[] | .period, .indication"  | paste -sd '	\n' - | sort | paste -sd '	\n' - | cut -f 1,2,4| sed -Ee 's/\+03:00//'
}

printWaterLastValues() {
    echo "Last set values (cold,hot): "
    getWaterIndications | jq -r ".counter | sort_by(.type)[] | .indications[] | select(.period==\"$dt+03:00\").indication" | paste -sd ',' -
}
