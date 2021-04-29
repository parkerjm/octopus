FROM elixir:1.11.3-alpine AS base

ENV PORT 8080
ENV MIX_ENV prod
ENV WORKDIR /app
WORKDIR ${WORKDIR}

RUN apk add -qU \
      coreutils \
      postgresql-dev \
      tzdata

FROM base AS builder

RUN apk add -qU \
      g++ \
      make \
      nodejs \
      nodejs-npm

COPY . .

RUN mix local.hex --force
RUN mix local.rebar --force
RUN mix deps.get --only prod
RUN mix compile
RUN npm install --prefix ./assets
RUN npm run deploy --prefix ./assets
RUN mix phx.digest
RUN mix release

FROM base AS final

ENV ERL_AFLAGS -kernel shell_history enabled

COPY --from=builder /app/_build/prod/rel/octopus .
COPY --from=builder /app/.iex.exs .

EXPOSE ${PORT}
CMD ["bin/octopus", "start"]
