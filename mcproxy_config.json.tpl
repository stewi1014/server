{
    "listen": {
        "address": ":25565",
        "fallback_version": "1.21.1",
        "fallback_protocol": 767
    },
    "proxies": [
        {
            "domain": "vanilla.lenqua.link",
            "destination_ip": "${vanilla_dest_ip}",
            "destination_port": 25565,
            "destination_version": "1.21.1",
            "destination_protocol": 767,
            "shutdown_timeout": 300,
            "ec2_server": {
                "region": "${vanilla_region}",
                "instance_id": "${vanilla_instance}",
                "hibernate": false
            }
        }
    ]
}