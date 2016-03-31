FROM alpine
MAINTAINER matt@cowger.us

RUN apk --update add git python py-pip && rm -f /var/cache/apk/*
RUN pip install flask requests
COPY honeypot.py /tmp/
EXPOSE 8080
ENTRYPOINT ["python","/tmp/honeypot.py"]
