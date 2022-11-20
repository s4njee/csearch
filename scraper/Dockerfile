FROM ubuntu:latest

RUN apt-get update && apt-get install -y \
    curl git python3-dev libxml2-dev libxslt1-dev libz-dev python3-pip wget

RUN mkdir -p /opt/theunitedstates.io/
ADD . /opt/theunitedstates.io/congress/
WORKDIR /opt/theunitedstates.io/congress/

RUN pip3 install .


RUN mkdir -p /congress
WORKDIR /congress
RUN ln -s /usr/bin/python3 /usr/bin/python
## GO Installation

RUN curl -OL https://go.dev/dl/go1.19.3.linux-arm64.tar.gz
RUN tar xvf go1.19.3.linux-arm64.tar.gz
RUN chown -R root:root ./go
RUN mv go /usr/local

ENV PATH="$PATH:/usr/local/go/bin"

COPY go.mod ./
COPY go.sum ./
RUN go mod download

COPY *.go ./

RUN go build -o /scraper
CMD ["/scraper"]
