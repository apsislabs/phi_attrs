ARG RUBY_VERSION=3.1.3
ARG ALPINE_VERSION=3.17

FROM ruby:${RUBY_VERSION}-alpine${ALPINE_VERSION}

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
