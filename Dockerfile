FROM ubuntu:24.04
RUN apt-get update 

RUN apt install handbrake-cli jq procps bc -y

VOLUME [ "/tasks", "/input", "/output"]
RUN mkdir app
COPY ./presets/mkv0480p265.json /app/mkv0480p265.json
COPY ./presets/mkv0576p265.json /app/mkv0576p265.json
COPY ./presets/mkv0720p265.json /app/mkv0720p265.json
COPY ./presets/mkv1080p265.json /app/mkv1080p265.json
COPY ./process.sh /app/process.sh
RUN chmod +x /app/process.sh

ENTRYPOINT [ "/app/process.sh" ]
