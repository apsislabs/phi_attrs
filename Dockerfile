FROM ruby:3.0.5-alpine3.16
MAINTAINER wyatt@apsis.io

RUN apk add --no-cache --update \
    bash \
    alpine-sdk \
    sqlite-dev \
    shared-mime-info

ENV APP_HOME /app
WORKDIR $APP_HOME

COPY . $APP_HOME/

EXPOSE 3000

CMD ["bash"]
