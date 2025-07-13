# -------- 1. build stage ------------------------------------
    FROM hexpm/elixir:1.18.4-erlang-25.1.2.1-ubuntu-jammy-20250619 AS build

    RUN apt-get update && \
        DEBIAN_FRONTEND=noninteractive \
        apt-get install -y --no-install-recommends \
          build-essential git bash curl && \
        rm -rf /var/lib/apt/lists/*
    
    ENV MIX_ENV=prod LANG=C.UTF-8
    WORKDIR /app
    
    # 1-A  mix deps
    COPY mix.exs mix.lock ./
    RUN mix do local.hex --force, local.rebar --force, deps.get --only prod
    
    # 1-B  copy the rest & compile
    COPY . .
    RUN mix deps.compile
    RUN mix compile
    RUN mix release
    
    
# -------- 2. runtime stage -----------------------
  FROM ubuntu:22.04 AS app
  RUN apt-get update && \
      apt-get install -y --no-install-recommends \
        libssl3 libncurses6 libtinfo6 ca-certificates \
        postgresql-client && \
      rm -rf /var/lib/apt/lists/*
  
  WORKDIR /app
  COPY --from=build /app/_build/prod/rel/ledger_bank_api ./ledger_bank_api
  COPY docker/entrypoint.sh /app/docker/entrypoint.sh
  
  ENV LANG=C.UTF-8 \
      MIX_ENV=prod \
      PHX_SERVER=true \
      PORT=4000
  
  EXPOSE 4000
  ENTRYPOINT ["/app/docker/entrypoint.sh"]   
  