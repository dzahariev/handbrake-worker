FROM ubuntu:24.04
RUN apt-get update 
RUN apt install handbrake-cli intel-media-va-driver-non-free i965-va-driver jq procps bc -y

VOLUME [ "/tasks", "/input", "/output"]
RUN mkdir app
COPY ./presets/Custom480P.json /app/Custom480P.json
COPY ./presets/Custom265X480P.json /app/Custom265X480P.json
COPY ./presets/Custom576P.json /app/Custom576P.json
COPY ./presets/Custom265X576P.json /app/Custom265X576P.json
COPY ./presets/Custom720P.json /app/Custom720P.json
COPY ./presets/Custom265X720P.json /app/Custom265X720P.json
COPY ./process.sh /app/process.sh
RUN chmod +x /app/process.sh

ENTRYPOINT [ "/app/process.sh" ]
