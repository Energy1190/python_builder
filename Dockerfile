FROM python:3

ADD run.sh /run.sh

RUN pip3 install docker
RUN chmod +x /run.sh && mkdir -p /data

ENTRYPOINT ["/run.sh"]