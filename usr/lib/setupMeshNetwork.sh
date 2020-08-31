devices=`iw dev | awk '$1=="Interface"{print $2}'`

echo "Network Devices: $devices"

for device in $devices
do
    `ip link set $device down`
    `iw $device set type ibss`
    interface=$device
done

SSIDdefault=Gruhoc
error=false

function doBatman {
    (
        set -Ee
        function _finally {
            `ip addr add 192.168.1.1/16 dev bat0`
        }
        `modprobe batman-adv`
        `batctl if add $interface`
        `ip link set up dev $interface`
        `ip link set up dev bat0`
        trap _finally EXIT
        `timeout -k 50s 1s dhclient bat0`
    )
}

function doNetwork {
    (
        function setNetwork {
            `ip link set $interface down`
            `iw $interface set type ibss`
            `ip link set $interface mtu 1532`
            #`iw $interface set channel 3`
            `ip link set $interface up`
            `iw $interface ibss join $SSIDdefault 2432`
        }

        set -Ee
        function _catch {
            if [ !error ]
            then
                error=true
                `rfkill unblock wlan`
                `systemctl stop network-manager`
                setNetwork
            fi
        }
        function _finally {
            if [ error ]
            then
                `systemctl start network-manager`
            fi
            doBatman
        }
        trap _catch ERR
        trap _finally EXIT
        setNetwork
    )
}

if [ $interface ]
then
    echo "Using $interface interface"
    doNetwork
else
    echo "There's no interface avaible"
fi
