FROM debian:stretch

RUN apt update && \
    apt install -y libmojolicious-perl libdbd-mysql-perl libyaml-libyaml-perl libfindbin-libs-perl libdbi-perl libanyevent-perl

RUN mkdir /srapi
ADD ./start.sh /srapi/start.sh
RUN mkdir /srapi/etc && touch /srapi/etc/db.cfg && chmod +x /srapi/start.sh

WORKDIR /srapi

RUN cd /srapi

ENTRYPOINT ["/srapi/start.sh"]
