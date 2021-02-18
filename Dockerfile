FROM elixir:1.11.3-alpine AS base

ENV PORT 8080
ENV MIX_ENV prod
ENV WORKDIR /app
WORKDIR ${WORKDIR}

RUN apk add -qU \
      coreutils \
      postgresql-dev \
      tzdata

FROM node:15.8-alpine AS asset-builder
ENV WORKDIR /app
WORKDIR ${WORKDIR}

RUN apk add -qU \
      git \
      openssh \
      autoconf \
      bison \
      bzip2 \
      bzip2-dev \
      ca-certificates \
      dpkg-dev dpkg \
      gcc \
      g++ \
      gdbm-dev \
      glib-dev \
      libc-dev \
      libffi-dev \
      libxml2-dev \
      libxslt-dev \
      linux-headers \
      make \
      ncurses-dev \
      procps \
      readline-dev \
      python \
      tar \
      xz \
      yaml-dev \
      zlib-dev

COPY . .

RUN rm -rf assets/node_modules
RUN npm install --prefix ./assets
RUN npm run deploy --prefix ./assets

FROM base AS builder

RUN apk add -qU \
      git \
      openssh \
      autoconf \
      bison \
      bzip2 \
      bzip2-dev \
      ca-certificates \
      dpkg-dev dpkg \
      gcc \
      g++ \
      gdbm-dev \
      glib-dev \
      libc-dev \
      libffi-dev \
      libxml2-dev \
      libxslt-dev \
      linux-headers \
      make \
      ncurses-dev \
      procps \
      readline-dev \
      tar \
      xz \
      yaml-dev \
      zlib-dev

COPY . .

RUN mix local.hex --force
RUN mix local.rebar --force

RUN mix deps.get --only prod
RUN mix compile

COPY --from=asset-builder /app/priv/static priv/static

RUN mix phx.digest
RUN mix release

FROM base AS final

COPY --from=builder /app/_build/prod/rel/octopus .
# COPY --from=builder /app/priv/static ./priv
# COPY --from=builder /app/lib/octopus-0.1.0/priv/static /app/lib/octopus-0.1.0/priv/static

EXPOSE ${PORT}
CMD ["bin/octopus", "start"]
