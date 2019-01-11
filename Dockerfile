FROM ruby:2.5.3-alpine3.8
MAINTAINER wyatt@apsis.io

RUN apk add --no-cache --update \
    bash \
    alpine-sdk \
    sqlite-dev

ENV APP_HOME /app
WORKDIR $APP_HOME

COPY . $APP_HOME/

EXPOSE 3000

CMD ["bash"]
