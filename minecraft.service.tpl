[Unit]
Description=Minecraft Server
After=network.target

[Install]
WantedBy=multi-user.target

[Service]
ExecStart=/usr/bin/java -jar server.jar --nogui
WorkingDirectory=/opt/minecraft
