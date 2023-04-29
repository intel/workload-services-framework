"sh"  "-c"  "until nc -z -w5 mysql-service 3306; do echo waiting for mysql service; sleep 1; done"
"sh"  "-c"  "until nc -z -w5 smt-redis 6380; do echo waiting for redis service; sleep 1; done"

nohup ./rtsp-simple-server &

ffmpeg -re -stream_loop -1 -i ./Smart-Science-Lab/smartlab-demo/videos/top.mp4  -re -stream_loop -1 -i ./Smart-Science-Lab/smartlab-demo/videos/side.mp4 -map 0 -c copy -f rtsp -rtsp_transport tcp rtsp://localhost:8554/top -map 1 -c copy -f rtsp -rtsp_transport tcp rtsp://localhost:8554/side
