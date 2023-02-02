ARG RUBY_VERSION=3.1.3

FROM ruby:${RUBY_VERSION}-buster

RUN apt-get update -qq && apt-get install -y --no-install-recommends \
  build-essential \
  git \
  bash \
  sqlite3

ENV APP_HOME /app
WORKDIR $APP_HOME

COPY . $APP_HOME/

RUN gem update --system
RUN bundle config set force_ruby_platform true

EXPOSE 3000

CMD ["bash"]
