#!/bin/bash

showhelp() {
    echo " -n, --name [name]      user-config name."
    echo " -i, --ip [ip]          user ip address."
    echo " -s, --show             dispaly wg."
    echo " -d, --delete [name]    delete wg."
}

checkIP() {
    ip=$1
    exist="`wg | grep "allowed ips" | awk '{print $3}' | grep $ip/32`"
    if [ ! -z "$exist" ]; then
       echo "ip already exists"
       return 1
    fi

    return 0
}

checkUser() {
    name=$1
    if [ -e "${name}.conf" ] || [ -e "${name}.key" ]; then
        echo "user ${name} already exists"
        return 1
    fi


    return 0

}

generate_key_pair() {
    name=$1
    wg genkey | tee ${name}.key | wg pubkey > ${name}.pub
    if [ ! -e ${name}.pub ]; then
        echo "generate key failed."
        return 1
    fi

    return 0
}

generate_conf_file() {
    name=$1
    ip=$2

    PRIVATE_KEY=`cat ${name}.key`

    sed "s#@PRIVATE_KEY@#${PRIVATE_KEY}#g" add.conf >> ${name}.conf
    sed -i "s#@IP_ADDRESS@#${ip}#g" ${name}.conf
    if [ $? -ne 0 ]; then
        echo "create template failed."
        return 1
    fi

    return 0
}

add_to_wire_guard() {
    name=$1
    ip=$2

    PUB_KEY=`cat ${name}.pub`
    wg set wg0 peer ${PUB_KEY} allowed-ips ${ip}/32
    return $?
}

delete_conf() {
    name=$1
    PUB_KEY=`cat ${name}.pub`
    wg set wg0 peer $PUB_KEY remove
    rm ${name}.key
    rm ${name}.pub
    rm ${name}.conf
    rm ${name}.png
}

generate_qrcode() {
    name=$1
    cat ${name}.conf | qrencode -o ${name}.png
    if [ ! -e ${name}.png ]; then
        echo "create qrcode failed"
        return 1
    fi

    return 0
}

main() {
    OPTS=`getopt -o hn:i:sd: --long help,name:,ip:,show,delete: \
                -n  "" -- "$@"`

    if [ $# -lt 1 ]; then showhelp; exit 1; fi
    if [ $? != 0 ] ; then echo "Terminating..." >&2 ; exit 1 ; fi

        # Note the quotes around `$TEMP': they are essential!
    eval set -- "$OPTS"

    while true; do
            case "$1" in
        -n | --name)
            user_name="$2"
            shift 2;;
        -i | --ip)
            user_ip="$2"
            shift 2;;
        -d | --delete)
                delete_conf "$2"
            return $?
                shift 2;;
        -s | --show)
                wg
                return 0
                shift;;
        -h | --help)
            showhelp
            shift ;;
        -- ) shift;  ;;
        * ) break ;;
            esac
    done


    if [ -z "$user_name" ] || [ -z "$user_ip" ]; then
        echo "please input name and ip address"
        return 1
    fi

    checkIP $user_ip
    if [ $? -ne 0 ]; then
        return 1
    fi

    checkUser $user_name
    if [ $? -ne 0 ]; then
        return 1
    fi

    generate_key_pair $user_name
    if [ $? -ne 0 ]; then
        echo "generate key failed"
        return 1
    fi


    generate_conf_file $user_name $user_ip
    if [ $? -ne 0 ]; then
        echo "generate conf failed"
        return 1
    fi

    add_to_wire_guard $user_name $user_ip
    if [ $? -ne 0 ]; then
        echo "add to wg failed"
        return 1
    fi

    generate_qrcode $user_name
    if [ $? -ne 0 ]; then
        echo "generate qrcode failed"
        return 1
    fi

    chmod 600 ${user_name}.*
    return $?
}

main $@
