FROM alpine
MAINTAINER matt@cowger.us

RUN apk --update add git python py-pip && rm -f /var/cache/apk/*
RUN pip install flask requests
COPY receiver.py /tmp/
EXPOSE 61116
ENTRYPOINT ["python","/tmp/receiver.py"]
